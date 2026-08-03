import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

/**
 * RedisService, Discord-benzeri platformda şu amaçlarla kullanılır:
 * - Kullanıcı online/offline durumu (presence) tutma
 * - Refresh token blacklist / oturum yönetimi
 * - Rate limiting sayaçları
 * - Sık okunan verilerin (sunucu üyeleri, roller) cache'lenmesi
 * - WebSocket gateway'leri arası pub/sub (yatay ölçekleme için, çoklu Node.js instance senaryosu)
 */
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis;
  private publisher: Redis;
  private subscriber: Redis;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit(): void {
    const options = {
      host: this.configService.get<string>('redis.host'),
      port: this.configService.get<number>('redis.port'),
      password: this.configService.get<string>('redis.password'),
      ...(this.configService.get<boolean>('redis.tls') ? { tls: {} } : {}),
      retryStrategy: (times: number) => Math.min(times * 100, 3000),
    };

    this.client = new Redis(options);
    this.publisher = new Redis(options);
    this.subscriber = new Redis(options);

    this.client.on('connect', () => this.logger.log('Redis bağlantısı kuruldu.'));
    this.client.on('error', (err) => this.logger.error(`Redis hatası: ${err.message}`));
  }

  onModuleDestroy(): void {
    this.client?.disconnect();
    this.publisher?.disconnect();
    this.subscriber?.disconnect();
  }

  getClient(): Redis {
    return this.client;
  }

  async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (ttlSeconds) {
      await this.client.set(key, value, 'EX', ttlSeconds);
    } else {
      await this.client.set(key, value);
    }
  }

  async get(key: string): Promise<string | null> {
    return this.client.get(key);
  }

  async del(key: string): Promise<void> {
    await this.client.del(key);
  }

  /** Kullanıcının presence (çevrimiçi durumu) bilgisini TTL ile saklar. */
  async setUserPresence(userId: string, status: string, ttlSeconds = 60): Promise<void> {
    await this.set(`presence:${userId}`, status, ttlSeconds);
  }

  async getUserPresence(userId: string): Promise<string | null> {
    return this.get(`presence:${userId}`);
  }

  async publish(channel: string, message: string): Promise<void> {
    await this.publisher.publish(channel, message);
  }

  subscribe(channel: string, callback: (message: string) => void): void {
    this.subscriber.subscribe(channel);
    this.subscriber.on('message', (ch, message) => {
      if (ch === channel) callback(message);
    });
  }
}
