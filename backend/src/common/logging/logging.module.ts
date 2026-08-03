import { randomUUID } from 'crypto';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { LoggerModule } from 'nestjs-pino';
import type { IncomingMessage, ServerResponse } from 'http';

/**
 * Faz 7.3 — Yapılandırılmış (structured) loglama.
 *
 * `nestjs-pino` NestJS'in dahili `Logger`'ının (bkz. `@nestjs/common`) YERİNE
 * geçer — `app.useLogger(app.get(Logger))` çağrıldıktan sonra (bkz.
 * `main.ts`), uygulama genelindeki TÜM `new Logger('Bağlam')` çağrıları
 * (ör. `PrismaService`, `AuthService`, `HttpExceptionFilter` — Faz 1-5'ten
 * kalan 6 kullanım) OTOMATİK olarak bu yapılandırılmış çıktıya yönlenir;
 * hiçbir servis dosyasının değiştirilmesi GEREKMEDİ. `nestjs-pino`'nun temel
 * özelliği tam olarak budur: mevcut isteğin request-id'si, çağrı o isteğin
 * işlenmesi sırasında yapıldığı sürece OTOMATİK olarak her log satırına
 * eklenir (async context propagation).
 *
 * ÜRETİMDE: her log satırı tek satırlık JSON'dır (log toplayıcılar —
 * CloudWatch/Datadog/ELK/Loki — için ideal format).
 * GELİŞTİRMEDE: `pino-pretty` ile renkli, okunabilir tek-satır çıktı.
 */
@Module({
  imports: [
    LoggerModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (configService: ConfigService) => {
        const env = configService.get<string>('env') || 'development';
        const isProduction = env === 'production';
        const logLevel = configService.get<string>('logLevel') || (isProduction ? 'info' : 'debug');

        return {
          pinoHttp: {
            level: logLevel,

            // Her isteğe bir korelasyon kimliği atar; istemci zaten bir
            // `x-request-id` göndermişse (ör. mobil uygulama hata raporlama)
            // ONU yeniden kullanır — böylece istemci logları ile sunucu
            // logları TEK bir kimlikle eşleştirilebilir. Yanıt header'ına da
            // geri yazılır ki istemci hangi isteğin hangi log satırlarına
            // karşılık geldiğini bilebilsin.
            genReqId: (req: IncomingMessage, res: ServerResponse) => {
              const existing = req.headers['x-request-id'];
              const id = (Array.isArray(existing) ? existing[0] : existing) || randomUUID();
              res.setHeader('x-request-id', id);
              return id;
            },

            // Gizli/hassas alanlar log çıktısında ASLA açık metin olarak
            // görünmez — bir log toplayıcı/aggregator ele geçirilse bile
            // şifre/token sızıntısı olmaz (bkz. Faz 7 "sertleştirme" amacı).
            redact: {
              paths: [
                'req.headers.authorization',
                'req.headers.cookie',
                'res.headers["set-cookie"]',
                'req.body.password',
                'req.body.currentPassword',
                'req.body.newPassword',
                'req.body.token',
                'req.body.refreshToken',
                'req.body.accessToken',
              ],
              censor: '**REDACTED**',
            },

            customSuccessMessage: (req: IncomingMessage & { method?: string; url?: string }, res: ServerResponse) =>
              `${req.method} ${req.url} → ${res.statusCode}`,
            customErrorMessage: (
              req: IncomingMessage & { method?: string; url?: string },
              res: ServerResponse,
              error: Error,
            ) => `${req.method} ${req.url} → ${res.statusCode} (${error.message})`,

            // Orkestratörler `/health/*`'i saniyeler içinde tekrar tekrar
            // çağırır (bkz. Faz 7.1) — bunları loglamak sadece gürültü
            // üretir ve gerçek trafiği loglar arasında boğar.
            autoLogging: {
              ignore: (req: IncomingMessage) => (req.url || '').includes('/health/'),
            },

            // Üretimde ham JSON (log toplayıcı için); geliştirmede
            // insan-okunabilir renkli tek satır.
            transport: isProduction
              ? undefined
              : {
                  target: 'pino-pretty',
                  options: { colorize: true, singleLine: true, translateTime: 'HH:MM:ss' },
                },
          },
        };
      },
    }),
  ],
  exports: [LoggerModule],
})
export class LoggingModule {}
