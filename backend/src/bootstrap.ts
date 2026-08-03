import { INestApplication, ValidationPipe, VersioningType } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * `main.ts`'teki `bootstrap()` VE `test/*.e2e-spec.ts` dosyaları tarafından
 * ORTAK kullanılır. Amaç: e2e testlerinin, gerçek üretimde kullanılan global
 * prefix + URI versioning + ValidationPipe ayarlarıyla TAM olarak aynı
 * rotalara karşı çalışmasını garanti etmek — bu fonksiyon olmadan, main.ts'te
 * yapılacak bir değişiklik (ör. prefix'in tekrar yanlışlıkla 'api/v1' olması,
 * bkz. Faz 7.1'deki düzeltme) e2e testlerinde fark edilmeden production'a
 * sızabilirdi çünkü testler kendi (muhtemelen eskimiş) bir kopyasını
 * kullanıyor olurdu.
 *
 * Dönen `apiPrefix`, main.ts'in başlangıç logunda kullanılır.
 */
export function configureApp(app: INestApplication, configService: ConfigService): { apiPrefix: string } {
  // NOT: SADECE 'api' olmalı — 'v1' segmenti `enableVersioning` tarafından
  // ayrıca eklenir (bkz. bu dosyanın başındaki doc yorumu).
  const apiPrefix = configService.get<string>('apiPrefix') || 'api';

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  app.setGlobalPrefix(apiPrefix);
  app.enableVersioning({ type: VersioningType.URI, defaultVersion: '1' });

  return { apiPrefix };
}
