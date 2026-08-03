import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

/**
 * İstemcinin, `storage` modülünden aldığı presigned upload yanıtına göre
 * mesaja eklemek istediği dosyayı tarif eder. `type` alanı GÜVENLİK
 * NEDENİYLE burada YOKTUR: gerçek tip her zaman `mimeType`'tan sunucu
 * tarafında yeniden hesaplanır (bkz. `messages.service.ts`).
 */
export class AttachmentInputDto {
  @ApiProperty()
  @IsString()
  @MaxLength(1024)
  url: string;

  @ApiProperty()
  @IsString()
  @MaxLength(255)
  fileName: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  fileSizeBytes: number;

  @ApiProperty()
  @IsString()
  @MaxLength(128)
  mimeType: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  width?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  height?: number;

  @ApiProperty({ required: false })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  durationMs?: number;

  /** true ise ve mime `image/*` ise Attachment.type=STICKER olarak kaydedilir. */
  @ApiProperty({ required: false })
  @IsOptional()
  isSticker?: boolean;

  /** true ise ve mime `audio/*` ise Attachment.type=VOICE_NOTE olarak kaydedilir. */
  @ApiProperty({ required: false })
  @IsOptional()
  isVoiceNote?: boolean;
}

export class CreateMessageDto {
  @ApiProperty({ required: false, maxLength: 4000 })
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  content?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  replyToId?: string;

  @ApiProperty({ required: false, type: [AttachmentInputDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => AttachmentInputDto)
  attachments?: AttachmentInputDto[];
}

export class UpdateMessageDto {
  @ApiProperty({ maxLength: 4000 })
  @IsString()
  @MaxLength(4000)
  content: string;
}

export class AddReactionDto {
  @ApiProperty({ example: '👍' })
  @IsString()
  @MaxLength(64)
  emoji: string;
}

export class ListMessagesQueryDto {
  /** Bu mesaj ID'sinden ÖNCEKİ (daha eski) mesajları getirir — geriye doğru sayfalama. */
  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  before?: string;

  /** Bu mesaj ID'sinden SONRAKİ (daha yeni) mesajları getirir. */
  @ApiProperty({ required: false })
  @IsOptional()
  @IsUUID()
  after?: string;

  @ApiProperty({ required: false, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limit?: number;
}
