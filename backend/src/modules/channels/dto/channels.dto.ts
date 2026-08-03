import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { ChannelType } from '@prisma/client';

export class CreateChannelDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsEnum(ChannelType)
  type: ChannelType;

  @IsOptional()
  @IsString()
  parentId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1024)
  topic?: string;
}

export class UpdateChannelDto {
  @IsOptional() @IsString() @MinLength(1) @MaxLength(100) name?: string;
  @IsOptional() @IsString() @MaxLength(1024) topic?: string;
  @IsOptional() @IsBoolean() isNsfw?: boolean;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(21600) rateLimitPerUser?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(8000) @Max(384000) bitrate?: number;
  @IsOptional() @Type(() => Number) @IsInt() @Min(0) @Max(99) userLimit?: number;
}

export class ReorderChannelsDto {
  channels: { id: string; position: number; parentId?: string | null }[];
}
