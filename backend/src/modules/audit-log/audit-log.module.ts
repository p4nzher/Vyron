import { Module } from '@nestjs/common';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { AuditLogService } from './audit-log.service';
import { AuditLogController } from './audit-log.controller';

@Module({
  controllers: [AuditLogController],
  providers: [AuditLogService, ServerPermissionGuard],
  exports: [AuditLogService],
})
export class AuditLogModule {}
