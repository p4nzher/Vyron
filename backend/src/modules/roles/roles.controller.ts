import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentUser } from '@/common/decorators/current-user.decorator';
import { CurrentServerMember } from '@/common/decorators/current-server-member.decorator';
import { RequirePermission } from '@/common/decorators/require-permission.decorator';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { ServersService } from '@/modules/servers/servers.service';
import { RolesService } from './roles.service';
import { CreateRoleDto, UpdateRoleDto } from './dto/roles.dto';

@ApiBearerAuth()
@ApiTags('roles')
@UseGuards(ServerPermissionGuard)
@RequirePermission(ServerPermission.MANAGE_ROLES)
@Controller('servers/:serverId/roles')
export class RolesController {
  constructor(
    private readonly rolesService: RolesService,
    private readonly serversService: ServersService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Sunucudaki tüm rolleri (hiyerarşi sırasıyla) listeler.' })
  list(@Param('serverId') serverId: string) {
    return this.rolesService.list(serverId);
  }

  @Post()
  @ApiOperation({ summary: 'Yeni bir rol oluşturur.' })
  create(
    @Param('serverId') serverId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: CreateRoleDto,
  ) {
    return this.rolesService.create(serverId, userId, dto);
  }

  @Patch(':roleId')
  @ApiOperation({ summary: 'Bir rolün adını, rengini veya yetkilerini günceller.' })
  update(
    @Param('serverId') serverId: string,
    @Param('roleId') roleId: string,
    @CurrentUser('userId') userId: string,
    @Body() dto: UpdateRoleDto,
    @CurrentServerMember() ctx: { server: { ownerId: string }; serverMember: { roles: { role: { position: number } }[] } },
  ) {
    return this.rolesService.update(serverId, roleId, userId, dto, {
      isOwner: ctx.server.ownerId === userId,
      roles: ctx.serverMember.roles.map((r) => r.role),
    });
  }

  @Delete(':roleId')
  @ApiOperation({ summary: 'Bir rolü siler.' })
  remove(
    @Param('serverId') serverId: string,
    @Param('roleId') roleId: string,
    @CurrentUser('userId') userId: string,
    @CurrentServerMember() ctx: { server: { ownerId: string }; serverMember: { roles: { role: { position: number } }[] } },
  ) {
    return this.rolesService.remove(serverId, roleId, userId, {
      isOwner: ctx.server.ownerId === userId,
      roles: ctx.serverMember.roles.map((r) => r.role),
    });
  }

  @Post('members/:memberId/:roleId')
  @ApiOperation({ summary: 'Bir üyeye rol atar.' })
  assign(
    @Param('serverId') serverId: string,
    @Param('memberId') memberId: string,
    @Param('roleId') roleId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.rolesService.assignToMember(serverId, memberId, roleId, userId);
  }

  @Delete('members/:memberId/:roleId')
  @ApiOperation({ summary: 'Bir üyeden rolü kaldırır.' })
  unassign(
    @Param('serverId') serverId: string,
    @Param('memberId') memberId: string,
    @Param('roleId') roleId: string,
    @CurrentUser('userId') userId: string,
  ) {
    return this.rolesService.removeFromMember(serverId, memberId, roleId, userId);
  }
}
