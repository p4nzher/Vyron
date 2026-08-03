import { ApiProperty } from '@nestjs/swagger';
import { IsBoolean, IsOptional, IsUUID } from 'class-validator';

export class UpdateVoiceStateDto {
  @ApiProperty({ required: false, description: 'Kendi mikrofonunu kapat/aç.' })
  @IsOptional()
  @IsBoolean()
  isMuted?: boolean;

  @ApiProperty({ required: false, description: 'Kendi hoparlörünü kapat/aç (sağırlaştırma).' })
  @IsOptional()
  @IsBoolean()
  isDeafened?: boolean;

  @ApiProperty({ required: false, description: 'Kamerayı aç/kapat.' })
  @IsOptional()
  @IsBoolean()
  isCameraOn?: boolean;

  @ApiProperty({ required: false, description: 'Ekran paylaşımını başlat/durdur.' })
  @IsOptional()
  @IsBoolean()
  isScreenSharing?: boolean;
}

export class MoveMemberDto {
  @ApiProperty({ description: 'Üyenin taşınacağı hedef sesli kanalın ID’si.' })
  @IsUUID()
  targetChannelId: string;
}
