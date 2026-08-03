import { Body, Controller, Delete, Get, Param, Patch, Post, Put, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { RequirePermission } from '@/common/decorators/require-permission.decorator';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { ServersService } from '@/modules/servers/servers.service';
import { ChannelsService } from './channels.service';
import { CreateChannelDto, ReorderChannelsDto, UpdateChannelDto } from './dto/channels.dto';

@ApiBearerAuth()
@ApiTags('channels')
@Controller('servers/:serverId/channels')
export class ChannelsController {
  constructor(
    private readonly channelsService: ChannelsService,
    private readonly serversService: ServersService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Sunucudaki tüm kanalları (kategori sıralı) listeler.' })
  async list(@Param('serverId') serverId: string, @CurrentUser('userId') userId: string) {
    await this.serversService.assertMember(serverId, userId);
    return this.channelsService.list(serverId);
  }

  @Post()
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.MANAGE_CHANNELS)
  @ApiOperation({ summary: 'Yeni bir metin/sesli/kategori kanalı oluşturur.' })
  create(
    @Param('serverId') serverId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateChannelDto,
  ) {
    return this.channelsService.create(serverId, userId, dto);
  }

  @Put('reorder')
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.MANAGE_CHANNELS)
  @ApiOperation({ summary: 'Kanalların sırasını ve kategori altındaki konumunu topluca günceller.' })
  reorder(@Param('serverId') serverId: string, @Body() dto: ReorderChannelsDto) {
    return this.channelsService.reorder(serverId, dto);
  }

  @Patch(':channelId')
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.MANAGE_CHANNELS)
  @ApiOperation({ summary: 'Kanal ayarlarını günceller (isim, konu, slow-mode, bitrate...).' })
  update(
    @Param('serverId') serverId: string,
    @Param('channelId') channelId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateChannelDto,
  ) {
    return this.channelsService.update(serverId, channelId, userId, dto);
  }

  @Delete(':channelId')
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.MANAGE_CHANNELS)
  @ApiOperation({ summary: 'Kanalı siler.' })
  remove(
    @Param('serverId') serverId: string,
    @Param('channelId') channelId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.channelsService.remove(serverId, channelId, userId);
  }
}
