import { Module } from '@nestjs/common';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { AuditLogModule } from '@/modules/audit-log/audit-log.module';
import { ServersService } from './servers.service';
import { ServersController } from './servers.controller';

@Module({
  imports: [AuditLogModule],
  controllers: [ServersController],
  providers: [ServersService, ServerPermissionGuard],
  exports: [ServersService],
})
export class ServersModule {}
