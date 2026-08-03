import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { SystemAdminGuard } from '@/common/guards/system-admin.guard';
import { StatsService, StatsOverview, DailyCount } from './stats.service';
import { StatsTimeseriesQueryDto } from './dto/stats-timeseries-query.dto';

/**
 * Faz 7.4 — `/admin/stats/**`. `JwtAuthGuard` (global) zaten kimlik
 * doğrulaması ister; `SystemAdminGuard` bunun üstüne `User.isSystemAdmin`
 * kontrolü ekler. Faz 7.5'teki yönetim panelinin veri kaynağıdır.
 */
@ApiTags('admin/stats')
@ApiBearerAuth()
@UseGuards(SystemAdminGuard)
@Controller('admin/stats')
export class StatsController {
  constructor(private readonly statsService: StatsService) {}

  @Get('overview')
  getOverview(): Promise<StatsOverview> {
    return this.statsService.getOverview();
  }

  @Get('signups')
  getDailySignups(@Query() query: StatsTimeseriesQueryDto): Promise<DailyCount[]> {
    return this.statsService.getDailySignups(query.days ?? 30);
  }

  @Get('messages')
  getDailyMessages(@Query() query: StatsTimeseriesQueryDto): Promise<DailyCount[]> {
    return this.statsService.getDailyMessages(query.days ?? 30);
  }
}
