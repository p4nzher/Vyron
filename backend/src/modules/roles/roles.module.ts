import { Module } from '@nestjs/common';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { AuditLogModule } from '@/modules/audit-log/audit-log.module';
import { ServersModule } from '@/modules/servers/servers.module';
import { RolesService } from './roles.service';
import { RolesController } from './roles.controller';

@Module({
  imports: [AuditLogModule, ServersModule],
  controllers: [RolesController],
  providers: [RolesService, ServerPermissionGuard],
  exports: [RolesService],
})
export class RolesModule {}
