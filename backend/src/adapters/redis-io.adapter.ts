import { IoAdapter } from '@nestjs/platform-socket.io';
import { INestApplicationContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ServerOptions } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import Redis from 'ioredis';

/**
 * Varsayılan Socket.IO adaptörü, bağlantıları sadece TEK BİR Node.js
 * process'inin belleğinde tutar: process A'daki bir kullanıcı, process B'ye
 * bağlı bir kullanıcıya mesaj gönderemez. Bu adaptör, Redis pub/sub
 * kullanarak tüm process'ler arasında oda (room) yayınlarını senkronize
 * eder — böylece backend yatay olarak (birden fazla instance/container)
 * ölçeklenebilir hale gelir (bkz. proje gereksinimleri: "Ölçeklenebilir
 * mimari" / "Mikro servis desteği").
 */
export class RedisIoAdapter extends IoAdapter {
  private adapterConstructor: ReturnType<typeof createAdapter>;

  constructor(private readonly app: INestApplicationContext) {
    super(app);
  }

  async connectToRedis(): Promise<void> {
    const configService = this.app.get(ConfigService);
    const options = {
      host: configService.get<string>('redis.host'),
      port: configService.get<number>('redis.port'),
      password: configService.get<string>('redis.password'),
    };

    const pubClient = new Redis(options);
    const subClient = pubClient.duplicate();

    this.adapterConstructor = createAdapter(pubClient, subClient);
  }

  createIOServer(port: number, options?: ServerOptions): unknown {
    const server = super.createIOServer(port, options);
    server.adapter(this.adapterConstructor);
    return server;
  }
}
