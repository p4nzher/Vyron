import { Controller, Get, HttpCode, HttpStatus, ServiceUnavailableException } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SkipThrottle } from '@nestjs/throttler';
import { Public } from '@/common/decorators/public.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';

/**
 * Faz 7.1 — Docker/orkestrasyon sağlık kontrolleri için.
 *
 * İKİ AYRI UÇ NOKTA kasıtlıdır (Kubernetes/Docker'ın "liveness" ve
 * "readiness" ayrımıyla aynı mantık):
 * - `GET /health/live`  : sadece Node.js süreci ayakta mı? Hiçbir dış
 *   bağımlılığı kontrol ETMEZ — orkestratör bunu "container'ı yeniden
 *   başlatmalı mıyım?" sorusu için kullanır. DB/Redis'in geçici olarak
 *   erişilemez olması süreci yeniden başlatmayı GEREKTİRMEZ.
 * - `GET /health/ready` : PostgreSQL VE Redis'e gerçekten bağlanabiliyor
 *   muyum? Orkestratör bunu "bu instance'a trafik yönlendirebilir miyim?"
 *   sorusu için kullanır (bkz. `docker-compose.prod.yml` — backend
 *   servisinin `healthcheck`'i bu uca gider).
 *
 * Her ikisi de `@Public()` (JWT gerektirmez) ve `@SkipThrottle()`'dır —
 * orkestratörler bunları saniyeler içinde tekrar tekrar çağırır.
 */
@ApiTags('health')
@Controller('health')
@Public()
@SkipThrottle()
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  @Get('live')
  @HttpCode(HttpStatus.OK)
  live(): { status: 'ok'; timestamp: string } {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  @Get('ready')
  @HttpCode(HttpStatus.OK)
  async ready(): Promise<{ status: 'ok'; checks: Record<string, 'ok' | 'error'> }> {
    const checks: Record<string, 'ok' | 'error'> = { database: 'error', redis: 'error' };
    let healthy = true;

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      checks.database = 'ok';
    } catch {
      healthy = false;
    }

    try {
      const pong = await this.redis.getClient().ping();
      checks.redis = pong === 'PONG' ? 'ok' : 'error';
      if (pong !== 'PONG') healthy = false;
    } catch {
      healthy = false;
    }

    if (!healthy) {
      throw new ServiceUnavailableException({ status: 'error', checks });
    }

    return { status: 'ok', checks };
  }
}
