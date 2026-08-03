import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, Length, Matches, MaxLength, MinLength } from 'class-validator';

export class RefreshTokenDto {
  @ApiProperty()
  @IsString()
  refreshToken: string;
}

export class ForgotPasswordDto {
  @ApiProperty({ example: 'enes@example.com' })
  @IsEmail()
  email: string;
}

export class ResetPasswordDto {
  @ApiProperty({ description: 'E-postayla gönderilen sıfırlama token’ı' })
  @IsString()
  token: string;

  @ApiProperty({ example: 'YeniGucluSifre!456' })
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  @Matches(/((?=.*\d)|(?=.*\W+))(?![.\n])(?=.*[A-Z])(?=.*[a-z]).*$/, {
    message: 'Şifre en az bir büyük harf, bir küçük harf ve bir rakam/özel karakter içermelidir.',
  })
  newPassword: string;
}

export class VerifyEmailDto {
  @ApiProperty()
  @IsString()
  token: string;
}

export class Enable2faDto {
  @ApiProperty({ description: 'Authenticator uygulamasından alınan 6 haneli kod (etkinleştirmeyi onaylamak için)' })
  @IsString()
  @Length(6, 6)
  code: string;
}

export class Verify2faDto {
  @ApiProperty()
  @IsString()
  @Length(6, 6)
  code: string;
}
