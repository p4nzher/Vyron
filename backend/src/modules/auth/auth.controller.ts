import { Body, Controller, HttpCode, HttpStatus, Post, Req, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';
import { Public } from '@/common/decorators/public.decorator';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import {
  Enable2faDto,
  ForgotPasswordDto,
  RefreshTokenDto,
  ResetPasswordDto,
  VerifyEmailDto,
} from './dto/auth-extra.dto';
import { JwtRefreshGuard } from './guards/jwt-refresh.guard';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('register')
  @ApiOperation({ summary: 'Yeni kullanıcı kaydı oluşturur ve token çifti döner.' })
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60000 } }) // Brute-force'a karşı: dakikada 5 giriş denemesi
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'E-posta/şifre (ve varsa 2FA kodu) ile giriş yapar.' })
  async login(@Body() dto: LoginDto, @Req() req: Request) {
    return this.authService.login(dto, req.ip);
  }

  @Public()
  @UseGuards(JwtRefreshGuard)
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Access token süresi dolduğunda yeni token çifti üretir (rotasyonlu).' })
  async refresh(@Req() req: Request, @Body() _dto: RefreshTokenDto) {
    const { userId, tokenId, refreshToken } = req.user as {
      userId: string;
      tokenId: string;
      refreshToken: string;
    };
    return this.authService.refreshTokens(userId, tokenId, refreshToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Mevcut oturumu (cihazı) sonlandırır.' })
  async logout(@CurrentUser('userId') userId: string) {
    await this.authService.logout(userId);
  }

  @Post('logout-all')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Kullanıcının tüm cihazlardaki oturumlarını sonlandırır.' })
  async logoutAll(@CurrentUser('userId') userId: string) {
    await this.authService.logoutAllDevices(userId);
  }

  @Public()
  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'E-posta doğrulama token’ını doğrular.' })
  async verifyEmail(@Body() dto: VerifyEmailDto) {
    await this.authService.verifyEmail(dto.token);
    return { message: 'E-posta adresi başarıyla doğrulandı.' };
  }

  @Public()
  @Throttle({ default: { limit: 3, ttl: 300000 } }) // 5 dakikada 3 istek - spam önleme
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Şifre sıfırlama e-postası gönderir.' })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    await this.authService.forgotPassword(dto.email);
    return { message: 'Eğer bu e-posta kayıtlıysa, sıfırlama bağlantısı gönderildi.' };
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Token ile yeni şifre belirler.' })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    await this.authService.resetPassword(dto.token, dto.newPassword);
    return { message: 'Şifreniz başarıyla güncellendi.' };
  }

  @Post('2fa/generate')
  @ApiOperation({ summary: 'Authenticator uygulaması için QR/secret üretir.' })
  async generate2fa(@CurrentUser('userId') userId: string) {
    return this.authService.generate2faSecret(userId);
  }

  @Post('2fa/enable')
  @ApiOperation({ summary: '6 haneli kodu doğrulayıp 2FA’yı etkinleştirir, yedek kodları döner.' })
  async enable2fa(@CurrentUser('userId') userId: string, @Body() dto: Enable2faDto) {
    return this.authService.enable2fa(userId, dto.code);
  }

  @Post('2fa/disable')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'İki faktörlü doğrulamayı devre dışı bırakır.' })
  async disable2fa(@CurrentUser('userId') userId: string) {
    await this.authService.disable2fa(userId);
  }
}
