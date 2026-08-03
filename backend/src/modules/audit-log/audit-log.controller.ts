import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { RequirePermission } from '@/common/decorators/require-permission.decorator';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { AuditLogService } from './audit-log.service';

@ApiBearerAuth()
@ApiTags('audit-log')
@UseGuards(ServerPermissionGuard)
@RequirePermission(ServerPermission.VIEW_AUDIT_LOG)
@Controller('servers/:serverId/audit-log')
export class AuditLogController {
  constructor(private readonly auditLogService: AuditLogService) {}

  @Get()
  @ApiOperation({ summary: 'Sunucudaki son yönetimsel işlemleri (kim, ne zaman, ne yaptı) listeler.' })
  list(@Param('serverId') serverId: string) {
    return this.auditLogService.listForServer(serverId);
  }
}
