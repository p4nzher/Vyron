import { Module } from '@nestjs/common';
import { StatsController } from './stats.controller';
import { StatsService } from './stats.service';
import { SystemAdminGuard } from '@/common/guards/system-admin.guard';

@Module({
  controllers: [StatsController],
  providers: [StatsService, SystemAdminGuard],
})
export class StatsModule {}
