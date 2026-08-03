import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

/**
 * MailService, kullanıcıya giden tüm transactional e-postaları (hesap doğrulama,
 * şifre sıfırlama, güvenlik uyarıları) yönetir. SMTP üzerinden nodemailer kullanır;
 * production'da SendGrid/SES gibi bir sağlayıcıya kolayca geçiş yapılabilir
 * çünkü tüm gönderim mantığı bu tek serviste izole edilmiştir.
 */
@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter;

  constructor(private readonly configService: ConfigService) {
    this.transporter = nodemailer.createTransport({
      host: this.configService.get<string>('mail.host'),
      port: this.configService.get<number>('mail.port'),
      secure: false,
      auth: {
        user: this.configService.get<string>('mail.user'),
        pass: this.configService.get<string>('mail.password'),
      },
    });
  }

  async sendVerificationEmail(to: string, username: string, token: string): Promise<void> {
    const verifyUrl = `${this.configService.get<string>('corsOrigins')?.[0] || ''}/verify-email?token=${token}`;
    await this.sendMail(
      to,
      'E-posta Adresini Doğrula',
      `Merhaba ${username},\n\nHesabını doğrulamak için: ${verifyUrl}\n\nBu bağlantı 24 saat geçerlidir.`,
    );
  }

  async sendPasswordResetEmail(to: string, username: string, token: string): Promise<void> {
    const resetUrl = `${this.configService.get<string>('corsOrigins')?.[0] || ''}/reset-password?token=${token}`;
    await this.sendMail(
      to,
      'Şifre Sıfırlama Talebi',
      `Merhaba ${username},\n\nŞifreni sıfırlamak için: ${resetUrl}\n\nBu bağlantı 1 saat geçerlidir. Bu talebi sen yapmadıysan bu e-postayı yok sayabilirsin.`,
    );
  }

  async sendTwoFactorBackupCodesEmail(to: string, username: string): Promise<void> {
    await this.sendMail(
      to,
      'İki Faktörlü Doğrulama Etkinleştirildi',
      `Merhaba ${username},\n\nHesabında iki faktörlü doğrulama etkinleştirildi. Bu işlemi sen yapmadıysan hemen destek ile iletişime geç.`,
    );
  }

  private async sendMail(to: string, subject: string, text: string): Promise<void> {
    try {
      await this.transporter.sendMail({
        from: this.configService.get<string>('mail.from'),
        to,
        subject,
        text,
      });
    } catch (error) {
      // E-posta gönderimi başarısız olsa bile ana akış (örn. kayıt) kesilmemeli;
      // hata loglanır ve kullanıcıya "tekrar gönder" seçeneği sunulur.
      this.logger.error(`E-posta gönderilemedi (${to}): ${(error as Error).message}`);
    }
  }
}
