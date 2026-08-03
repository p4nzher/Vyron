import { Body, Controller, Get, Param, Patch, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { UsersService } from './users.service';

class UpdateProfileDto {
  @IsOptional() @IsString() @MaxLength(32) displayName?: string;
  @IsOptional() @IsString() @MaxLength(190) bio?: string;
  @IsOptional() @IsString() avatarUrl?: string;
  @IsOptional() @IsString() bannerUrl?: string;
}

class UpdateStatusDto {
  @IsIn(['ONLINE', 'IDLE', 'DND', 'INVISIBLE'])
  status: 'ONLINE' | 'IDLE' | 'DND' | 'INVISIBLE';
}

@ApiTags('users')
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  @ApiOperation({ summary: 'Giriş yapmış kullanıcının kendi profilini döner.' })
  async getMe(@CurrentUser('userId') userId: string) {
    return this.usersService.findById(userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Belirli bir kullanıcının herkese açık profilini döner.' })
  async getById(@Param('id') id: string) {
    return this.usersService.findById(id);
  }

  @Patch('me')
  @ApiOperation({ summary: 'Kendi profilini günceller (görünen ad, bio, avatar, banner).' })
  async updateMe(@CurrentUser('userId') userId: string, @Body() dto: UpdateProfileDto) {
    return this.usersService.updateProfile(userId, dto);
  }

  @Patch('me/status')
  @ApiOperation({ summary: 'Çevrimiçi durumunu günceller (Çevrimiçi/Meşgul/Görünmez).' })
  async updateStatus(@CurrentUser('userId') userId: string, @Body() dto: UpdateStatusDto) {
    return this.usersService.updateStatus(userId, dto.status);
  }

  @Get()
  @ApiOperation({ summary: 'Kullanıcı adına göre kullanıcı arar (arkadaş eklemek için).' })
  async search(@Query('q') query: string, @CurrentUser('userId') userId: string) {
    return this.usersService.search(query || '', userId);
  }
}
