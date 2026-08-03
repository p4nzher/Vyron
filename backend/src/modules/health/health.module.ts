import { Module } from '@nestjs/common';
import { HealthController } from './health.controller';

/**
 * `PrismaModule`/`RedisModule` `@Global()` olduğu için burada ayrıca import
 * edilmesine gerek yok — `HealthController` ikisini de doğrudan enjekte eder.
 */
@Module({
  controllers: [HealthController],
})
export class HealthModule {}
