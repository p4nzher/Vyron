import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { RequirePermission } from '@/common/decorators/require-permission.decorator';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { InvitesService } from './invites.service';
import { CreateInviteDto } from './dto/invites.dto';

@ApiBearerAuth()
@ApiTags('invites')
@Controller('servers/:serverId/invites')
export class ServerInvitesController {
  constructor(private readonly invitesService: InvitesService) {}

  @Post()
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.CREATE_INVITE)
  @ApiOperation({ summary: 'Sunucu için yeni bir davet linki/kodu oluşturur.' })
  create(
    @Param('serverId') serverId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateInviteDto,
  ) {
    return this.invitesService.create(serverId, userId, dto);
  }

  @Get()
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.MANAGE_INVITES)
  @ApiOperation({ summary: 'Sunucunun tüm aktif davetlerini listeler.' })
  list(@Param('serverId') serverId: string) {
    return this.invitesService.listForServer(serverId);
  }

  @Delete(':inviteId')
  @UseGuards(ServerPermissionGuard)
  @RequirePermission(ServerPermission.MANAGE_INVITES)
  @ApiOperation({ summary: 'Bir daveti iptal eder.' })
  revoke(
    @Param('serverId') serverId: string,
    @Param('inviteId') inviteId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.invitesService.revoke(serverId, inviteId, userId);
  }
}

@ApiBearerAuth()
@ApiTags('invites')
@Controller('invites')
export class InvitesController {
  constructor(private readonly invitesService: InvitesService) {}

  @Get(':code')
  @ApiOperation({ summary: 'Davet kodunu, katılmadan önce (sunucu adı, üye sayısı) önizler.' })
  preview(@Param('code') code: string) {
    return this.invitesService.preview(code);
  }

  @Post(':code/join')
  @ApiOperation({ summary: 'Davet koduyla sunucuya katılır.' })
  join(@Param('code') code: string, @CurrentUser('userId') userId: string) {
    return this.invitesService.join(code, userId);
  }
}
