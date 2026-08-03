import { Module } from '@nestjs/common';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { AuditLogModule } from '@/modules/audit-log/audit-log.module';
import { ModerationService } from './moderation.service';
import { ModerationController } from './moderation.controller';

@Module({
  imports: [AuditLogModule],
  controllers: [ModerationController],
  providers: [ModerationService, ServerPermissionGuard],
  exports: [ModerationService],
})
export class ModerationModule {}
