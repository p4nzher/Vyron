import { Module } from '@nestjs/common';
import { ServerPermissionGuard } from '@/common/guards/server-permission.guard';
import { AuditLogModule } from '@/modules/audit-log/audit-log.module';
import { ServersModule } from '@/modules/servers/servers.module';
import { InvitesService } from './invites.service';
import { ServerInvitesController, InvitesController } from './invites.controller';

@Module({
  imports: [AuditLogModule, ServersModule],
  controllers: [ServerInvitesController, InvitesController],
  providers: [InvitesService, ServerPermissionGuard],
  exports: [InvitesService],
})
export class InvitesModule {}
