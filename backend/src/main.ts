import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger } from 'nestjs-pino';
import helmet from 'helmet';
import * as cookieParser from 'cookie-parser';
import { AppModule } from './app.module';
import { RedisIoAdapter } from './adapters/redis-io.adapter';
import { configureApp } from './bootstrap';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, {
    // `LoggingModule` (Faz 7.3) devreye girene kadar başlangıç logları
    // bellekte tutulur, kaybolmaz — hemen aşağıda `app.useLogger` ile
    // NestJS'in varsayılan konsol logger'ı `nestjs-pino` ile DEĞİŞTİRİLİR.
    bufferLogs: true,
  });
  const logger = app.get(Logger);
  app.useLogger(logger);

  const configService = app.get(ConfigService);
  const port = configService.get<number>('port') || 3000;
  const corsOrigins = configService.get<string[]>('corsOrigins') || [];

  // ---------------------------------------------------------------------
  // GÜVENLİK KATMANLARI
  // ---------------------------------------------------------------------
  app.use(helmet()); // XSS, clickjacking, MIME-sniffing gibi saldırılara karşı HTTP header koruması
  app.use(cookieParser());

  // ---------------------------------------------------------------------
  // GERÇEK ZAMANLI (SOCKET.IO) — Redis adaptörü ile yatay ölçeklenebilir
  // ---------------------------------------------------------------------
  const redisIoAdapter = new RedisIoAdapter(app);
  await redisIoAdapter.connectToRedis();
  app.useWebSocketAdapter(redisIoAdapter);
  app.enableCors({
    origin: corsOrigins.length > 0 ? corsOrigins : true,
    credentials: true,
  });

  // Global prefix + URI versioning + ValidationPipe — bkz. `bootstrap.ts`
  // (e2e testleriyle PAYLAŞILAN tek gerçek kaynak, Faz 7.1'deki
  // prefix/versioning çakışması bir daha sessizce geri gelmesin diye).
  const { apiPrefix } = configureApp(app, configService);

  // ---------------------------------------------------------------------
  // SWAGGER API DOKÜMANTASYONU
  // ---------------------------------------------------------------------
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Vyron API')
    .setDescription('Vyron - Modern, ölçeklenebilir gerçek zamanlı iletişim platformu API dokümantasyonu')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const swaggerDocument = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('docs', app, swaggerDocument);

  await app.listen(port);
  logger.log(`🚀 API http://localhost:${port}/${apiPrefix}/v1 adresinde çalışıyor`);
  logger.log(`📚 Swagger dokümantasyonu http://localhost:${port}/docs adresinde`);
}

bootstrap();
