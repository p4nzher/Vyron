import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as argon2 from 'argon2';
import * as crypto from 'crypto';
import { authenticator } from 'otplib';
import { nanoid } from 'nanoid';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { MailService } from '@/modules/mail/mail.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface PublicUser {
  id: string;
  username: string;
  discriminator: string;
  email: string;
  displayName: string | null;
  avatarUrl: string | null;
  status: string;
  twoFactorEnabled: boolean;
}

/**
 * AuthService, kimlik doğrulama alanındaki tüm iş kurallarını barındırır.
 * Controller katmanı yalnızca HTTP isteklerini bu servise yönlendirir;
 * böylece iş mantığı transport katmanından (HTTP/WS) bağımsız ve test edilebilir kalır.
 */
@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly mailService: MailService,
  ) {}

  // ---------------------------------------------------------------------
  // KAYIT
  // ---------------------------------------------------------------------
  async register(dto: RegisterDto): Promise<{ user: PublicUser; tokens: AuthTokens }> {
    const existingEmail = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existingEmail) {
      throw new ConflictException('Bu e-posta adresi zaten kullanımda.');
    }

    // Discord tarzı: aynı username farklı discriminator ile birden çok kez var olabilir.
    const discriminator = await this.generateUniqueDiscriminator(dto.username);
    const passwordHash = await argon2.hash(dto.password);
    const emailVerifyToken = crypto.randomBytes(32).toString('hex');

    const user = await this.prisma.user.create({
      data: {
        username: dto.username,
        discriminator,
        email: dto.email,
        passwordHash,
        emailVerifyToken,
        emailVerifyExpires: new Date(Date.now() + 24 * 60 * 60 * 1000),
      },
    });

    await this.mailService.sendVerificationEmail(user.email, user.username, emailVerifyToken);

    const tokens = await this.issueTokenPair(user.id, user.email, user.username);
    this.logger.log(`Yeni kullanıcı kaydedildi: ${user.username}#${user.discriminator}`);

    return { user: this.toPublicUser(user), tokens };
  }

  /**
   * "kullanici_adi" zaten varsa, Discord'daki gibi rastgele 4 haneli bir
   * discriminator (#0001-#9999) üretip benzersizliği garanti eder.
   */
  private async generateUniqueDiscriminator(username: string): Promise<string> {
    for (let attempt = 0; attempt < 20; attempt++) {
      const candidate = String(Math.floor(1 + Math.random() * 9998)).padStart(4, '0');
      const exists = await this.prisma.user.findUnique({
        where: { username_discriminator: { username, discriminator: candidate } },
      });
      if (!exists) return candidate;
    }
    throw new BadRequestException(
      'Bu kullanıcı adı için uygun bir discriminator üretilemedi, lütfen farklı bir kullanıcı adı deneyin.',
    );
  }

  // ---------------------------------------------------------------------
  // GİRİŞ
  // ---------------------------------------------------------------------
  async login(dto: LoginDto, ipAddress?: string): Promise<{ user: PublicUser; tokens: AuthTokens }> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) {
      throw new UnauthorizedException('E-posta veya şifre hatalı.');
    }

    const passwordValid = await argon2.verify(user.passwordHash, dto.password);
    if (!passwordValid) {
      throw new UnauthorizedException('E-posta veya şifre hatalı.');
    }

    if (user.isBanned) {
      throw new UnauthorizedException('Bu hesap askıya alınmıştır.');
    }

    if (user.twoFactorEnabled) {
      if (!dto.twoFactorCode) {
        // Frontend'e "2FA gerekli" sinyalini özel bir hata koduyla iletiyoruz.
        throw new UnauthorizedException({
          message: 'İki faktörlü doğrulama kodu gereklidir.',
          code: 'TWO_FACTOR_REQUIRED',
        });
      }
      const isValidCode = authenticator.check(dto.twoFactorCode, user.twoFactorSecret || '');
      if (!isValidCode) {
        throw new UnauthorizedException('Geçersiz iki faktörlü doğrulama kodu.');
      }
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastSeenAt: new Date(), status: 'ONLINE' },
    });

    const tokens = await this.issueTokenPair(user.id, user.email, user.username, ipAddress);
    return { user: this.toPublicUser(user), tokens };
  }

  // ---------------------------------------------------------------------
  // TOKEN YÖNETİMİ (issue / refresh / revoke)
  // ---------------------------------------------------------------------
  private async issueTokenPair(
    userId: string,
    email: string,
    username: string,
    ipAddress?: string,
    deviceInfo?: string,
  ): Promise<AuthTokens> {
    const accessToken = await this.jwtService.signAsync(
      { sub: userId, email, username },
      {
        secret: this.configService.get<string>('jwt.accessSecret'),
        expiresIn: this.configService.get<string>('jwt.accessExpiresIn'),
      },
    );

    // Refresh token, veritabanında hash'lenmiş olarak tutulur. Böylece DB sızıntısında
    // dahi ham refresh token'lar ele geçirilemez (tıpkı şifreler gibi ele alınır).
    const rawRefreshToken = crypto.randomBytes(48).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(rawRefreshToken).digest('hex');

    const refreshTokenRecord = await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash,
        deviceInfo,
        ipAddress,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
    });

    const refreshToken = await this.jwtService.signAsync(
      { sub: userId, tokenId: refreshTokenRecord.id, raw: rawRefreshToken },
      {
        secret: this.configService.get<string>('jwt.refreshSecret'),
        expiresIn: this.configService.get<string>('jwt.refreshExpiresIn'),
      },
    );

    return { accessToken, refreshToken };
  }

  /**
   * Refresh token rotasyonu: her yenileme isteğinde eski token iptal edilir,
   * yenisi verilir. Bu sayede çalınmış bir refresh token yeniden kullanılırsa
   * (eski hash artık DB'de "revoked" olduğu için) tespit edilebilir.
   */
  async refreshTokens(userId: string, tokenId: string, rawToken: string): Promise<AuthTokens> {
    const tokenRecord = await this.prisma.refreshToken.findUnique({ where: { id: tokenId } });
    const tokenHash = crypto.createHash('sha256').update(rawToken).digest('hex');

    if (
      !tokenRecord ||
      tokenRecord.isRevoked ||
      tokenRecord.tokenHash !== tokenHash ||
      tokenRecord.expiresAt < new Date() ||
      tokenRecord.userId !== userId
    ) {
      // Olası token çalınma senaryosuna karşı, kullanıcının TÜM oturumlarını iptal ediyoruz.
      if (tokenRecord) {
        await this.prisma.refreshToken.updateMany({
          where: { userId: tokenRecord.userId },
          data: { isRevoked: true },
        });
      }
      throw new UnauthorizedException('Oturum geçersiz, lütfen tekrar giriş yapın.');
    }

    await this.prisma.refreshToken.update({
      where: { id: tokenId },
      data: { isRevoked: true },
    });

    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    return this.issueTokenPair(user.id, user.email, user.username, tokenRecord.ipAddress || undefined);
  }

  async logout(userId: string, tokenId?: string): Promise<void> {
    if (tokenId) {
      await this.prisma.refreshToken.updateMany({
        where: { id: tokenId, userId },
        data: { isRevoked: true },
      });
    }
    await this.prisma.user.update({ where: { id: userId }, data: { status: 'OFFLINE' } });
  }

  async logoutAllDevices(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({ where: { userId }, data: { isRevoked: true } });
  }

  // ---------------------------------------------------------------------
  // E-POSTA DOĞRULAMA
  // ---------------------------------------------------------------------
  async verifyEmail(token: string): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: { emailVerifyToken: token, emailVerifyExpires: { gt: new Date() } },
    });
    if (!user) {
      throw new BadRequestException('Doğrulama bağlantısının süresi dolmuş veya geçersiz.');
    }
    await this.prisma.user.update({
      where: { id: user.id },
      data: { isEmailVerified: true, emailVerifyToken: null, emailVerifyExpires: null },
    });
  }

  // ---------------------------------------------------------------------
  // ŞİFRE SIFIRLAMA
  // ---------------------------------------------------------------------
  async forgotPassword(email: string): Promise<void> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    // Kullanıcı var/yok bilgisini sızdırmamak için her durumda aynı yanıtı döneriz (enumeration önleme).
    if (!user) return;

    const resetToken = crypto.randomBytes(32).toString('hex');
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        passwordResetToken: resetToken,
        passwordResetExpires: new Date(Date.now() + 60 * 60 * 1000),
      },
    });
    await this.mailService.sendPasswordResetEmail(user.email, user.username, resetToken);
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    const user = await this.prisma.user.findFirst({
      where: { passwordResetToken: token, passwordResetExpires: { gt: new Date() } },
    });
    if (!user) {
      throw new BadRequestException('Sıfırlama bağlantısının süresi dolmuş veya geçersiz.');
    }
    const passwordHash = await argon2.hash(newPassword);
    await this.prisma.user.update({
      where: { id: user.id },
      data: { passwordHash, passwordResetToken: null, passwordResetExpires: null },
    });
    // Şifre değiştiğinde tüm eski oturumlar (refresh token'lar) iptal edilir — güvenlik best-practice.
    await this.logoutAllDevices(user.id);
  }

  // ---------------------------------------------------------------------
  // İKİ FAKTÖRLÜ DOĞRULAMA (2FA - TOTP)
  // ---------------------------------------------------------------------
  async generate2faSecret(userId: string): Promise<{ secret: string; otpAuthUrl: string }> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const secret = authenticator.generateSecret();
    const otpAuthUrl = authenticator.keyuri(user.email, 'Vyron', secret);

    // Secret, kullanıcı 6 haneli kodla doğrulayana kadar geçici olarak saklanır.
    await this.prisma.user.update({ where: { id: userId }, data: { twoFactorSecret: secret } });
    return { secret, otpAuthUrl };
  }

  async enable2fa(userId: string, code: string): Promise<{ backupCodes: string[] }> {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    if (!user.twoFactorSecret) {
      throw new BadRequestException('Önce 2FA secret üretilmelidir.');
    }
    const isValid = authenticator.check(code, user.twoFactorSecret);
    if (!isValid) {
      throw new BadRequestException('Doğrulama kodu hatalı.');
    }

    const backupCodes = Array.from({ length: 8 }, () => nanoid(10));
    const hashedBackupCodes = await Promise.all(backupCodes.map((c) => argon2.hash(c)));

    await this.prisma.user.update({
      where: { id: userId },
      data: { twoFactorEnabled: true, twoFactorBackupCodes: hashedBackupCodes },
    });

    await this.mailService.sendTwoFactorBackupCodesEmail(user.email, user.username);
    return { backupCodes }; // Kullanıcıya tek seferlik gösterilir, tekrar gösterilmez.
  }

  async disable2fa(userId: string): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { twoFactorEnabled: false, twoFactorSecret: null, twoFactorBackupCodes: [] },
    });
  }

  // ---------------------------------------------------------------------
  // YARDIMCILAR
  // ---------------------------------------------------------------------
  private toPublicUser(user: {
    id: string;
    username: string;
    discriminator: string;
    email: string;
    displayName: string | null;
    avatarUrl: string | null;
    status: string;
    twoFactorEnabled: boolean;
  }): PublicUser {
    // Hassas alanlar (passwordHash, twoFactorSecret vb.) asla client'a gönderilmez.
    return {
      id: user.id,
      username: user.username,
      discriminator: user.discriminator,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      status: user.status,
      twoFactorEnabled: user.twoFactorEnabled,
    };
  }
}
