import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

/**
 * PrismaService, PrismaClient'ı NestJS yaşam döngüsüne bağlar.
 * Uygulama başladığında veritabanına bağlanır, kapandığında bağlantıyı temiz şekilde keser.
 * Tüm modüller bu servisi enjekte ederek veritabanına erişir (repository pattern yerine
 * Prisma'nın kendi query builder'ı kullanılır, ancak servis katmanı iş mantığını izole eder).
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      log: [
        { emit: 'event', level: 'query' },
        { emit: 'stdout', level: 'error' },
        { emit: 'stdout', level: 'warn' },
      ],
    });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
    this.logger.log('PostgreSQL veritabanına başarıyla bağlanıldı.');
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
    this.logger.log('Veritabanı bağlantısı kapatıldı.');
  }

  /**
   * Test ortamlarında veritabanını temizlemek için yardımcı metot.
   * SADECE test ortamında çağrılmalıdır — production'da asla kullanılmamalıdır.
   */
  async cleanDatabase(): Promise<void> {
    if (process.env.NODE_ENV !== 'test') {
      throw new Error('cleanDatabase() sadece test ortamında çalıştırılabilir.');
    }
    const tableNames = await this.$queryRaw<Array<{ tablename: string }>>`
      SELECT tablename FROM pg_tables WHERE schemaname='public'
    `;
    for (const { tablename } of tableNames) {
      if (tablename !== '_prisma_migrations') {
        await this.$executeRawUnsafe(`TRUNCATE TABLE "public"."${tablename}" CASCADE;`);
      }
    }
  }
}
