import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class ReasonDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class TimeoutDto {
  @IsOptional() @IsString() @MaxLength(500) reason?: string;

  /** Susturma süresi (saniye). Örn. 600 = 10 dakika. */
  @Type(() => Number)
  @IsInt()
  @Min(30)
  @Max(60 * 60 * 24 * 28) // Discord'daki gibi maksimum 28 gün
  durationSeconds: number;
}
