import { ApiProperty } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Bir dosyanın hangi amaçla yükleneceğini belirtir. Her bağlam için ayrı
 * boyut/mime-type kısıtlaması ve depolama klasörü (`storage.service.ts`
 * içindeki `UPLOAD_CONTEXT_RULES`) uygulanır. Böylece örn. bir kullanıcı
 * "avatar" bağlamını kullanarak 500MB'lık bir video yükleyemez.
 */
export enum UploadContext {
  AVATAR = 'AVATAR',
  BANNER = 'BANNER',
  SERVER_ICON = 'SERVER_ICON',
  SERVER_BANNER = 'SERVER_BANNER',
  MESSAGE_ATTACHMENT = 'MESSAGE_ATTACHMENT',
  VOICE_NOTE = 'VOICE_NOTE',
  CUSTOM_EMOJI = 'CUSTOM_EMOJI',
  STICKER = 'STICKER',
}

export class RequestUploadDto {
  @ApiProperty({ example: 'tatil-fotografi.png' })
  @IsString()
  @MaxLength(255)
  fileName: string;

  @ApiProperty({ example: 'image/png' })
  @IsString()
  @MaxLength(128)
  mimeType: string;

  @ApiProperty({ example: 2_500_000, description: 'Bayt cinsinden dosya boyutu' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1024 * 1024 * 1024) // Servis katmanında bağlama özel gerçek limit tekrar kontrol edilir
  fileSizeBytes: number;

  @ApiProperty({ enum: UploadContext, example: UploadContext.MESSAGE_ATTACHMENT })
  @IsEnum(UploadContext)
  context: UploadContext;

  @ApiProperty({ required: false, description: 'Ait olduğu sunucu ID’si (SERVER_ICON/BANNER/EMOJI için)' })
  @IsOptional()
  @IsString()
  serverId?: string;
}
