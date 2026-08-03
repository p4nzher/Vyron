import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class RegisterDto {
  @ApiProperty({ example: 'enes_dev', description: 'Benzersiz kullanıcı adı (3-32 karakter)' })
  @IsString()
  @MinLength(3, { message: 'Kullanıcı adı en az 3 karakter olmalıdır.' })
  @MaxLength(32, { message: 'Kullanıcı adı en fazla 32 karakter olabilir.' })
  @Matches(/^[a-zA-Z0-9_.]+$/, {
    message: 'Kullanıcı adı yalnızca harf, rakam, alt çizgi ve nokta içerebilir.',
  })
  username: string;

  @ApiProperty({ example: 'enes@example.com' })
  @IsEmail({}, { message: 'Geçerli bir e-posta adresi giriniz.' })
  email: string;

  @ApiProperty({ example: 'GucluBirSifre!123' })
  @IsString()
  @MinLength(8, { message: 'Şifre en az 8 karakter olmalıdır.' })
  @MaxLength(128)
  @Matches(/((?=.*\d)|(?=.*\W+))(?![.\n])(?=.*[A-Z])(?=.*[a-z]).*$/, {
    message: 'Şifre en az bir büyük harf, bir küçük harf ve bir rakam/özel karakter içermelidir.',
  })
  password: string;
}
