import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { configureApp } from '../src/bootstrap';

// Faz 7.2 — Faz 7.1'de eklenen `/health` uçlarını GERÇEK bir Postgres +
// Redis bağlantısıyla uçtan uca doğrular. `npm test` (birim testleri)
// aksine bu test GERÇEK ALTYAPI GEREKTİRİR — CI'da `.github/workflows/
// backend-ci.yml` bunun için `services:` altında geçici Postgres/Redis
// container'ları ayağa kaldırır; yerel çalıştırmak için önce
// `docker compose up -d postgres redis` gerekir.
//
// `configureApp()` (bkz. `src/bootstrap.ts`) main.ts ile PAYLAŞILIR — bu
// test gerçek prefix/versioning ayarlarına karşı çalışır, kendi (eskiyebilecek)
// bir kopyasına karşı değil.
describe('Health (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    configureApp(app, app.get(ConfigService));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('/api/v1/health/live (GET) - süreç ayaktaysa dış bağımlılık kontrolü yapmadan 200 döner', () => {
    return request(app.getHttpServer())
      .get('/api/v1/health/live')
      .expect(200)
      .expect((res) => {
        expect(res.body.status).toBe('ok');
      });
  });

  it('/api/v1/health/ready (GET) - Postgres ve Redis erişilebilirse 200 döner', () => {
    return request(app.getHttpServer())
      .get('/api/v1/health/ready')
      .expect(200)
      .expect((res) => {
        expect(res.body.status).toBe('ok');
        expect(res.body.checks.database).toBe('ok');
        expect(res.body.checks.redis).toBe('ok');
      });
  });

  it('/api/v1/health/live (GET) - kimlik doğrulama token gerektirmez (@Public)', () => {
    return request(app.getHttpServer()).get('/api/v1/health/live').expect(200);
  });
});
