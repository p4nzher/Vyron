import { Module } from '@nestjs/common';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { AuditLogModule } from '@/modules/audit-log/audit-log.module';
import { ServersModule } from '@/modules/servers/servers.module';
import { ChannelsService } from './channels.service';
import { ChannelsController } from './channels.controller';

@Module({
  imports: [AuditLogModule, ServersModule],
  controllers: [ChannelsController],
  providers: [ChannelsService, ServerPermissionGuard],
  exports: [ChannelsService],
})
export class ChannelsModule {}
