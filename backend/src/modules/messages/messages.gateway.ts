import { Inject, Logger, forwardRef } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UserStatus } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { RedisService } from '@/modules/redis/redis.service';
import { MessageScope, MessagesService, scopeToRoom } from './messages.service';

interface AuthenticatedSocket extends Socket {
  data: {
    userId: string;
    username: string;
  };
}

/**
 * Vyron Realtime Gateway
 * ---------------------------------------------------------------------------
 * Mimari kararı: mesaj OLUŞTURMA/DÜZENLEME/SİLME işlemleri REST API
 * üzerinden yapılır (bkz. `messages.controller.ts`), bu gateway ise SADECE:
 *   1) Bu değişiklikleri ilgili odalara (room) gerçek zamanlı yayınlar,
 *   2) Yazıyor... (typing) göstergesi ve çevrimiçi durumu (presence) gibi
 *      veritabanına yazılması gerekmeyen, anlık/geçici sinyalleri taşır.
 * Bu ayrım (REST=komut, WS=olay) Discord'un kendi mimarisiyle aynıdır ve
 * REST ile WS arasında iş mantığının tekrarlanmasını önler.
 *
 * Yatay ölçekleme: `src/adapters/redis-io.adapter.ts` ile Socket.IO,
 * Redis pub/sub adaptörü kullanacak şekilde yapılandırılır; böylece birden
 * fazla Node.js instance'ı arkasında bile tüm odalara doğru yayın yapılır.
 */
@WebSocketGateway({
  cors: { origin: true, credentials: true },
  namespace: '/realtime',
})
export class MessagesGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly logger = new Logger(MessagesGateway.name);

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly prisma: PrismaService,
    private readonly redisService: RedisService,
    @Inject(forwardRef(() => MessagesService))
    private readonly messagesService: MessagesService,
  ) {}

  // ---------------------------------------------------------------------
  // BAĞLANTI YAŞAM DÖNGÜSÜ
  // ---------------------------------------------------------------------

  /**
   * Handshake sırasında JWT doğrulanır (`socket.handshake.auth.token` veya
   * `Authorization` header'ı üzerinden). Geçersizse bağlantı reddedilir.
   */
  async handleConnection(client: AuthenticatedSocket): Promise<void> {
    try {
      const token = this.extractToken(client);
      const payload = await this.jwtService.verifyAsync<{ sub: string; username: string }>(token, {
        secret: this.configService.get<string>('jwt.accessSecret'),
      });
      client.data.userId = payload.sub;
      client.data.username = payload.username;

      // Kullanıcıyı, mesaj gönderilirken hedeflenebilen kişisel odasına al
      // (bildirimler, arkadaşlık istekleri, çoklu cihaz senkronizasyonu için).
      await client.join(`user:${payload.sub}`);

      // Kullanıcının üye olduğu tüm sunucuların "presence" odalarına katılır
      // ve durumunu ÇEVRİMİÇİ olarak işaretler.
      const memberships = await this.prisma.serverMember.findMany({
        where: { userId: payload.sub },
        select: { serverId: true },
      });
      for (const m of memberships) {
        await client.join(`server-presence:${m.serverId}`);
      }

      await this.redisService.setUserPresence(payload.sub, UserStatus.ONLINE, 3600);
      await this.prisma.user.update({
        where: { id: payload.sub },
        data: { status: UserStatus.ONLINE, lastSeenAt: new Date() },
      });

      for (const m of memberships) {
        this.server.to(`server-presence:${m.serverId}`).emit('presence:update', {
          userId: payload.sub,
          status: UserStatus.ONLINE,
        });
      }
    } catch (err) {
      this.logger.warn(`Kimlik doğrulanamayan WebSocket bağlantısı reddedildi: ${(err as Error).message}`);
      client.disconnect(true);
    }
  }

  async handleDisconnect(client: AuthenticatedSocket): Promise<void> {
    const userId = client.data?.userId;
    if (!userId) return;

    // Aynı kullanıcının başka bir sekme/cihazdan hâlâ bağlı olup olmadığını kontrol et.
    const otherSockets = await this.server.in(`user:${userId}`).fetchSockets();
    if (otherSockets.length > 0) return; // Hâlâ başka bir bağlantı var, çevrimdışı yapma.

    await this.redisService.setUserPresence(userId, UserStatus.OFFLINE, 3600);
    const updated = await this.prisma.user.update({
      where: { id: userId },
      data: { status: UserStatus.OFFLINE, lastSeenAt: new Date() },
    });

    const memberships = await this.prisma.serverMember.findMany({ where: { userId }, select: { serverId: true } });
    for (const m of memberships) {
      this.server.to(`server-presence:${m.serverId}`).emit('presence:update', {
        userId,
        status: updated.status,
      });
    }
  }

  private extractToken(client: Socket): string {
    const authToken = client.handshake.auth?.token as string | undefined;
    const headerToken = client.handshake.headers.authorization?.replace('Bearer ', '');
    const token = authToken || headerToken;
    if (!token) throw new Error('Token sağlanmadı.');
    return token;
  }

  // ---------------------------------------------------------------------
  // ODA (ROOM) YÖNETİMİ — İstemci hangi kanal/DM'i dinlemek istediğini bildirir
  // ---------------------------------------------------------------------

  @SubscribeMessage('channel:join')
  async onChannelJoin(@ConnectedSocket() client: AuthenticatedSocket, @MessageBody() data: { channelId: string }) {
    // Yetki kontrolü: kullanıcı gerçekten bu kanala erişebiliyor mu?
    await this.messagesService.list({ channelId: data.channelId }, client.data.userId, { limit: 1 });
    await client.join(`channel:${data.channelId}`);
    return { ok: true };
  }

  @SubscribeMessage('channel:leave')
  async onChannelLeave(@ConnectedSocket() client: AuthenticatedSocket, @MessageBody() data: { channelId: string }) {
    await client.leave(`channel:${data.channelId}`);
    return { ok: true };
  }

  @SubscribeMessage('dm:join')
  async onDmJoin(@ConnectedSocket() client: AuthenticatedSocket, @MessageBody() data: { dmChannelId: string }) {
    await this.messagesService.list({ dmChannelId: data.dmChannelId }, client.data.userId, { limit: 1 });
    await client.join(`dm:${data.dmChannelId}`);
    return { ok: true };
  }

  @SubscribeMessage('dm:leave')
  async onDmLeave(@ConnectedSocket() client: AuthenticatedSocket, @MessageBody() data: { dmChannelId: string }) {
    await client.leave(`dm:${data.dmChannelId}`);
    return { ok: true };
  }

  // ---------------------------------------------------------------------
  // YAZIYOR... (TYPING) GÖSTERGESİ — veritabanına yazılmaz, sadece anlık yayın
  // ---------------------------------------------------------------------

  @SubscribeMessage('typing:start')
  onTypingStart(@ConnectedSocket() client: AuthenticatedSocket, @MessageBody() data: { channelId?: string; dmChannelId?: string }) {
    const room = data.channelId ? `channel:${data.channelId}` : `dm:${data.dmChannelId}`;
    client.to(room).emit('typing:start', { userId: client.data.userId, username: client.data.username });
  }

  @SubscribeMessage('typing:stop')
  onTypingStop(@ConnectedSocket() client: AuthenticatedSocket, @MessageBody() data: { channelId?: string; dmChannelId?: string }) {
    const room = data.channelId ? `channel:${data.channelId}` : `dm:${data.dmChannelId}`;
    client.to(room).emit('typing:stop', { userId: client.data.userId, username: client.data.username });
  }

  // ---------------------------------------------------------------------
  // MessagesService TARAFINDAN ÇAĞRILAN YAYIN KÖPRÜSÜ
  // ---------------------------------------------------------------------

  /** Bir mesaj kapsamındaki (kanal/DM) odaya event yayınlar. */
  broadcast(scope: MessageScope, event: string, payload: unknown): void {
    this.server?.to(scopeToRoom(scope)).emit(event, payload);
  }
}
