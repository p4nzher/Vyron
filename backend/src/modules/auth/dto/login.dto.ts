import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, Length } from 'class-validator';

export class LoginDto {
  @ApiProperty({ example: 'enes@example.com' })
  @IsEmail({}, { message: 'Geçerli bir e-posta adresi giriniz.' })
  email: string;

  @ApiProperty({ example: 'GucluBirSifre!123' })
  @IsString()
  password: string;

  @ApiPropertyOptional({
    example: '123456',
    description: '2FA etkinse gereklidir (TOTP kodu)',
  })
  @IsOptional()
  @IsString()
  @Length(6, 6, { message: '2FA kodu 6 haneli olmalıdır.' })
  twoFactorCode?: string;
}
