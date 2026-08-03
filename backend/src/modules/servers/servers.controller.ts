import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { RequirePermission } from '@/common/decorators/require-permission.decorator';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { ServersService } from './servers.service';
import { CreateServerDto, UpdateMemberDto, UpdateServerDto } from './dto/servers.dto';

@ApiBearerAuth()
@ApiTags('servers')
@Controller('servers')
export class ServersController {
  constructor(private readonly serversService: ServersService) {}

  @Post()
  @ApiOperation({ summary: 'Yeni bir sunucu oluşturur (varsayılan kanal ve @everyone rolüyle).' })
  create(@CurrentUser('userId') userId: string, @Body() dto: CreateServerDto) {
    return this.serversService.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Kullanıcının üyesi olduğu tüm sunucuları listeler.' })
  findMine(@CurrentUser('userId') userId: string) {
    return this.serversService.findMyServers(userId);
  }

  @Get(':serverId')
  @ApiOperation({ summary: 'Sunucu detayını (kanallar, roller) döner.' })
  findOne(@Param('serverId') serverId: string, @CurrentUser('userId') userId: string) {
    return this.serversService.getDetail(serverId, userId);
  }

  @Patch(':serverId')
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.MANAGE_SERVER)
  @ApiOperation({ summary: 'Sunucu ayarlarını günceller (isim, açıklama, ikon, banner).' })
  update(
    @Param('serverId') serverId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateServerDto,
  ) {
    return this.serversService.update(serverId, userId, dto);
  }

  @Delete(':serverId')
  @ApiOperation({ summary: 'Sunucuyu kalıcı olarak siler (sadece sahip).' })
  remove(@Param('serverId') serverId: string, @CurrentUser('userId') userId: string) {
    return this.serversService.delete(serverId, userId);
  }

  @Get(':serverId/members')
  @ApiOperation({ summary: 'Sunucu üyelerini (rolleriyle birlikte) listeler.' })
  listMembers(@Param('serverId') serverId: string, @CurrentUser('userId') userId: string) {
    return this.serversService.listMembers(serverId, userId);
  }

  @Patch(':serverId/members/:memberId')
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.MANAGE_NICKNAMES)
  @ApiOperation({ summary: 'Bir üyenin sunucu takma adını günceller.' })
  updateMember(
    @Param('serverId') serverId: string,
    @Param('memberId') memberId: string,
    @Body() dto: UpdateMemberDto,
  ) {
    return this.serversService.updateMember(serverId, memberId, dto);
  }

  @Post(':serverId/leave')
  @ApiOperation({ summary: 'Sunucudan kendi isteğinle ayrılırsın (sahip hariç).' })
  leave(@Param('serverId') serverId: string, @CurrentUser('userId') userId: string) {
    return this.serversService.leave(serverId, userId);
  }
}
