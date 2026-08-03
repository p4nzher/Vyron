import { ApiProperty } from '@nestjs/swagger';
import { ArrayMaxSize, ArrayMinSize, ArrayUnique, IsArray, IsBoolean, IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class CreateDmChannelDto {
  @ApiProperty({
    description: 'Konuşmaya dahil edilecek diğer kullanıcıların ID’leri (kendiniz otomatik eklenir).',
    type: [String],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(9) // 1 sahip + en fazla 9 katılımcı = 10 kişilik grup DM sınırı
  @ArrayUnique()
  @IsUUID('4', { each: true })
  participantIds: string[];

  @ApiProperty({ required: false, description: 'Birden fazla katılımcı varsa grup DM oluşturulur.' })
  @IsOptional()
  @IsBoolean()
  isGroup?: boolean;

  @ApiProperty({ required: false, maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  name?: string;
}
