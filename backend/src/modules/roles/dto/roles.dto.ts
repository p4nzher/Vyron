import { Type } from 'class-transformer';
import { IsBoolean, IsInt, IsObject, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class CreateRoleDto {
  @IsString()
  @MinLength(1)
  @MaxLength(50)
  name: string;

  @IsOptional()
  @IsString()
  @Matches(/^#([0-9A-Fa-f]{6})$/, { message: 'Renk #RRGGBB formatında olmalıdır.' })
  color?: string;

  @IsOptional()
  @IsObject()
  permissions?: Record<string, boolean>;

  @IsOptional()
  @IsBoolean()
  isHoisted?: boolean;

  @IsOptional()
  @IsBoolean()
  isMentionable?: boolean;
}

export class UpdateRoleDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(50) name?: string;
  @IsOptional() @IsString() @Matches(/^#([0-9A-Fa-f]{6})$/) color?: string;
  @IsOptional() @IsObject() permissions?: Record<string, boolean>;
  @IsOptional() @IsBoolean() isHoisted?: boolean;
  @IsOptional() @IsBoolean() isMentionable?: boolean;
  @IsOptional() @Type(() => Number) @IsInt() position?: number;
}
