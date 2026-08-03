import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

export class CreateInviteDto {
  /** Kullanım limiti. Belirtilmezse sınırsız. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(1000)
  maxUses?: number;

  /** Saniye cinsinden geçerlilik süresi (ör. 3600 = 1 saat). Belirtilmezse süresiz. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(60)
  @Max(60 * 60 * 24 * 30)
  expiresInSeconds?: number;
}
