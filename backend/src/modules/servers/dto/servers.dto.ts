import { IsBoolean, IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateServerDto {
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  description?: string;

  @IsOptional()
  @IsString()
  iconUrl?: string;
}

export class UpdateServerDto {
  @IsOptional() @IsString() @MinLength(2) @MaxLength(100) name?: string;
  @IsOptional() @IsString() @MaxLength(300) description?: string;
  @IsOptional() @IsString() iconUrl?: string;
  @IsOptional() @IsString() bannerUrl?: string;
  @IsOptional() @IsBoolean() isPublic?: boolean;
}

export class UpdateMemberDto {
  @IsOptional()
  @IsString()
  @MaxLength(32)
  nickname?: string;
}
