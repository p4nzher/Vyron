import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import configuration from './config/configuration';
import { envValidationSchema } from './config/env.validation';
import { LoggingModule } from './common/logging/logging.module';
import { PrismaModule } from './modules/prisma/prisma.module';
import { RedisModule } from './modules/redis/redis.module';
import { HealthModule } from './modules/health/health.module';
import { StatsModule } from './modules/stats/stats.module';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { FriendsModule } from './modules/friends/friends.module';
import { AuditLogModule } from './modules/audit-log/audit-log.module';
import { ServersModule } from './modules/servers/servers.module';
import { ChannelsModule } from './modules/channels/channels.module';
import { RolesModule } from './modules/roles/roles.module';
import { InvitesModule } from './modules/invites/invites.module';
import { ModerationModule } from './modules/moderation/moderation.module';
import { StorageModule } from './modules/storage/storage.module';
import { MessagesModule } from './modules/messages/messages.module';
import { DmModule } from './modules/dm/dm.module';
import { VoiceModule } from './modules/voice/voice.module';
import { JwtAuthGuard } from './modules/auth/guards/jwt-auth.guard';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

@Module({
  imports: [
    // Global konfigürasyon: .env dosyasını okur ve validate eder
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
      validationSchema: envValidationSchema,
      envFilePath: ['.env'],
    }),

    // Global rate limiting: DDoS/brute-force koruması (endpoint bazlı @Throttle ile override edilebilir)
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),

    // Faz 7.3 — yapılandırılmış (JSON) loglama + istek/korelasyon kimliği.
    // Diğer tüm modüllerden ÖNCE gelmeli ki onların `new Logger(...)`
    // çağrıları uygulama ayağa kalkarken bile doğru şekilde yönlensin.
    LoggingModule,

    // Altyapı modülleri
    PrismaModule,
    RedisModule,
    // Faz 7.1 — Docker/orkestrasyon sağlık kontrolleri (/health/live, /health/ready)
    HealthModule,
    // Faz 7.4 — platform-genel istatistikler (/admin/stats/**, sadece isSystemAdmin)
    StatsModule,

    // Özellik modülleri
    AuthModule,
    UsersModule,
    FriendsModule,

    // Faz 3 — Sunucular, kanallar, roller, davetler, moderasyon
    AuditLogModule,
    ServersModule,
    ChannelsModule,
    RolesModule,
    InvitesModule,
    ModerationModule,

    // Faz 4 — Mesajlaşma, dosya depolama, Socket.IO gerçek zamanlı katmanı
    StorageModule,
    MessagesModule,
    DmModule,

    // Faz 5 — Sesli/Görüntülü/Ekran Paylaşımı (LiveKit)
    VoiceModule,
  ],
  providers: [
    // 1) Rate limiting tüm endpoint'lerde varsayılan olarak aktif
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    // 2) Kimlik doğrulama tüm endpoint'lerde varsayılan olarak zorunlu (@Public() hariç)
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    // 3) Tüm hatalar tutarlı formatta döner
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    // 4) Tüm başarılı yanıtlar standart zarfa sarılır
    { provide: APP_INTERCEPTOR, useClass: TransformInterceptor },
  ],
})
export class AppModule {}
