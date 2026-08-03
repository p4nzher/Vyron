import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccessToken, RoomServiceClient, TrackSource } from 'livekit-server-sdk';

/**
 * LiveKitService, gerçek medya akışını (ses/görüntü/ekran paylaşımı) YÖNETMEZ
 * — bu iş tamamen LiveKit medya sunucusuna (SFU) bırakılır. Bu servis sadece:
 *   1) İstemcinin LiveKit odasına bağlanabilmesi için imzalı bir JWT üretir,
 *   2) Yönetimsel eylemler için (zorla susturma/atma) LiveKit REST API'sini çağırır.
 * Böylece backend'imiz gerçek zamanlı medya trafiğini asla üstlenmez —
 * bu, "ölçeklenebilir mimari" gereksiniminin doğrudan bir sonucudur.
 */
@Injectable()
export class LiveKitService {
  private readonly roomService: RoomServiceClient;
  private readonly apiKey: string;
  private readonly apiSecret: string;
  private readonly wsUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.apiKey = this.configService.get<string>('liveKit.apiKey') as string;
    this.apiSecret = this.configService.get<string>('liveKit.apiSecret') as string;
    this.wsUrl = this.configService.get<string>('liveKit.url') as string;

    // RoomServiceClient (yönetim REST API'si) http(s) bekler; kullanıcı istemcileri
    // ise medya bağlantısı için wss:// (websocket) adresini kullanır.
    const httpUrl = this.wsUrl.replace(/^wss:\/\//, 'https://').replace(/^ws:\/\//, 'http://');
    this.roomService = new RoomServiceClient(httpUrl, this.apiKey, this.apiSecret);
  }

  /** Bir sesli/görüntülü kanal için LiveKit oda adı (kanal ID'si ile birebir eşlenir). */
  roomNameForChannel(channelId: string): string {
    return `channel-${channelId}`;
  }

  /** İstemcilerin medya bağlantısı için kullanacağı LiveKit WebSocket adresi. */
  get mediaUrl(): string {
    return this.wsUrl;
  }

  /**
   * Kullanıcının belirtilen odaya katılabilmesi için imzalı, kısa ömürlü bir
   * erişim token'ı üretir. Yetkiler (`canPublish`/`canPublishData` vb.)
   * `voice.service.ts` tarafından hesaplanan sunucu izinlerine göre belirlenir.
   */
  async createAccessToken(params: {
    roomName: string;
    userId: string;
    username: string;
    canPublishAudio: boolean;
    canPublishVideo: boolean;
    canPublishScreenShare: boolean;
  }): Promise<string> {
    const at = new AccessToken(this.apiKey, this.apiSecret, {
      identity: params.userId,
      name: params.username,
      ttl: '6h',
    });

    const sources: TrackSource[] = [];
    if (params.canPublishAudio) sources.push(TrackSource.MICROPHONE);
    if (params.canPublishVideo) sources.push(TrackSource.CAMERA);
    if (params.canPublishScreenShare) sources.push(TrackSource.SCREEN_SHARE, TrackSource.SCREEN_SHARE_AUDIO);

    at.addGrant({
      room: params.roomName,
      roomJoin: true,
      canSubscribe: true,
      canPublish: sources.length > 0,
      canPublishData: true,
      canPublishSources: sources.length > 0 ? sources : undefined,
    });

    return at.toJwt();
  }

  /** Oda yoksa oluşturur; katılımcı limitini (Channel.userLimit) LiveKit seviyesinde de zorunlu kılar. */
  async ensureRoom(roomName: string, maxParticipants?: number): Promise<void> {
    await this.roomService.createRoom({
      name: roomName,
      emptyTimeout: 5 * 60, // Oda boş kalırsa 5 dakika sonra LiveKit tarafında otomatik kapanır
      maxParticipants: maxParticipants && maxParticipants > 0 ? maxParticipants : undefined,
    });
  }

  /** Bir kullanıcıyı LiveKit odasından anında atar (kick/ban ile senkronize kullanılır). */
  async removeParticipant(roomName: string, userId: string): Promise<void> {
    await this.roomService.removeParticipant(roomName, userId).catch(() => undefined);
  }

  /** Bir kullanıcının belirli bir track kaynağını (mikrofon/kamera) sunucu tarafından zorla susturur. */
  async muteParticipantTracks(roomName: string, userId: string): Promise<void> {
    const participant = await this.roomService.getParticipant(roomName, userId).catch(() => null);
    if (!participant) return;
    for (const track of participant.tracks) {
      await this.roomService.mutePublishedTrack(roomName, userId, track.sid, true).catch(() => undefined);
    }
  }

  async listParticipants(roomName: string) {
    return this.roomService.listParticipants(roomName).catch(() => []);
  }
}
