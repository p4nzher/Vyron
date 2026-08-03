import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { CurrentServerMember } from '@/common/decorators/current-server-member.decorator';
import { RequirePermission } from '@/common/decorators/require-permission.decorator';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { ModerationService } from './moderation.service';
import { ReasonDto, TimeoutDto } from './dto/moderation.dto';

type ServerCtx = {
  server: { ownerId: string };
  serverMember: { roles: { role: { position: number } }[] };
};

const toActorContext = (ctx: ServerCtx, userId: string) => ({
  isOwner: ctx.server.ownerId === userId,
  roles: ctx.serverMember.roles.map((r) => r.role),
});

@ApiBearerAuth()
@ApiTags('moderation')
@UseGuards(ServerPermissionGuard)
@Controller('servers/:serverId/moderation')
export class ModerationController {
  constructor(private readonly moderationService: ModerationService) {}

  @Post('members/:userId/kick')
  @RequirePermission(ServerPermission.KICK_MEMBERS)
  @ApiOperation({ summary: 'Üyeyi sunucudan atar (tekrar davetle girebilir).' })
  kick(
    @Param('serverId') serverId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
    @CurrentServerMember() ctx: ServerCtx,
    @Body() dto: ReasonDto,
  ) {
    return this.moderationService.kick(serverId, actorId, toActorContext(ctx, actorId), targetUserId, dto.reason);
  }

  @Post('members/:userId/ban')
  @RequirePermission(ServerPermission.BAN_MEMBERS)
  @ApiOperation({ summary: 'Kullanıcıyı sunucudan yasaklar (tekrar giremez).' })
  ban(
    @Param('serverId') serverId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
    @CurrentServerMember() ctx: ServerCtx,
    @Body() dto: ReasonDto,
  ) {
    return this.moderationService.ban(serverId, actorId, toActorContext(ctx, actorId), targetUserId, dto.reason);
  }

  @Delete('bans/:userId')
  @RequirePermission(ServerPermission.BAN_MEMBERS)
  @ApiOperation({ summary: 'Bir kullanıcının yasağını kaldırır.' })
  unban(
    @Param('serverId') serverId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
  ) {
    return this.moderationService.unban(serverId, actorId, targetUserId);
  }

  @Get('bans')
  @RequirePermission(ServerPermission.BAN_MEMBERS)
  @ApiOperation({ summary: 'Sunucudaki tüm yasaklı kullanıcıları listeler.' })
  listBans(@Param('serverId') serverId: string) {
    return this.moderationService.listBans(serverId);
  }

  @Post('members/:userId/timeout')
  @RequirePermission(ServerPermission.TIMEOUT_MEMBERS)
  @ApiOperation({ summary: 'Üyeyi belirli bir süre susturur (mesaj/sesli katılım kısıtlanır).' })
  timeout(
    @Param('serverId') serverId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
    @CurrentServerMember() ctx: ServerCtx,
    @Body() dto: TimeoutDto,
  ) {
    return this.moderationService.timeout(
      serverId,
      actorId,
      toActorContext(ctx, actorId),
      targetUserId,
      dto.durationSeconds,
      dto.reason,
    );
  }

  @Delete('members/:userId/timeout')
  @RequirePermission(ServerPermission.TIMEOUT_MEMBERS)
  @ApiOperation({ summary: 'Üyenin susturmasını erken kaldırır.' })
  removeTimeout(
    @Param('serverId') serverId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
    @CurrentServerMember() ctx: ServerCtx,
  ) {
    return this.moderationService.removeTimeout(serverId, actorId, toActorContext(ctx, actorId), targetUserId);
  }

  @Post('members/:userId/warn')
  @RequirePermission(ServerPermission.TIMEOUT_MEMBERS)
  @ApiOperation({ summary: 'Üyeye kayıt altına alınan bir uyarı verir.' })
  warn(
    @Param('serverId') serverId: string,
    @Param('userId') targetUserId: string,
    @CurrentUser('userId') actorId: string,
    @CurrentServerMember() ctx: ServerCtx,
    @Body() dto: ReasonDto,
  ) {
    return this.moderationService.warn(serverId, actorId, toActorContext(ctx, actorId), targetUserId, dto.reason);
  }

  @Get('members/:userId/history')
  @RequirePermission(ServerPermission.VIEW_AUDIT_LOG)
  @ApiOperation({ summary: 'Bir üyenin moderasyon geçmişini (uyarı/timeout/kick/ban) listeler.' })
  history(@Param('serverId') serverId: string, @Param('userId') targetUserId: string) {
    return this.moderationService.listActionsForMember(serverId, targetUserId);
  }
}
