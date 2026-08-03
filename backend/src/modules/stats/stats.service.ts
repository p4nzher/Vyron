import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface StatsOverview {
  totalUsers: number;
  totalServers: number;
  totalChannels: number;
  totalMessages: number;
  activeVoiceParticipants: number;
  bannedUsers: number;
  newUsersLast7Days: number;
  newServersLast7Days: number;
  messagesLast24h: number;
  generatedAt: string;
}

export interface DailyCount {
  date: string; // YYYY-MM-DD
  count: number;
}

/**
 * Faz 7.4 — platform-genel istatistikler. Sadece `/admin/**` (bkz.
 * `SystemAdminGuard`) altında sunulur; sıradan bir sunucu/kanal sahibinin
 * kendi sunucusuna özel istatistikleriyle KARIŞTIRILMAMALIDIR (o farklı bir
 * kapsam olurdu ve backend'de henüz yok).
 *
 * Tüm sorgular salt-okunur `count()`/`groupBy` işlemleridir — hiçbir yazma
 * işlemi yapılmaz, bu yüzden platform büyüklüğü ne olursa olsun güvenlidir
 * (ama çok büyük tablolarda `COUNT(*)` maliyetli olabilir — bkz. aşağıdaki
 * not, gelecekte materialized view/periyodik snapshot'a geçiş gerekebilir).
 */
@Injectable()
export class StatsService {
  constructor(private readonly prisma: PrismaService) {}

  async getOverview(): Promise<StatsOverview> {
    const now = new Date();
    const since24h = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const since7d = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const [
      totalUsers,
      totalServers,
      totalChannels,
      totalMessages,
      activeVoiceParticipants,
      bannedUsers,
      newUsersLast7Days,
      newServersLast7Days,
      messagesLast24h,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.server.count(),
      this.prisma.channel.count(),
      this.prisma.message.count({ where: { isDeleted: false } }),
      this.prisma.voiceState.count(),
      this.prisma.user.count({ where: { isBanned: true } }),
      this.prisma.user.count({ where: { createdAt: { gte: since7d } } }),
      this.prisma.server.count({ where: { createdAt: { gte: since7d } } }),
      this.prisma.message.count({ where: { isDeleted: false, createdAt: { gte: since24h } } }),
    ]);

    return {
      totalUsers,
      totalServers,
      totalChannels,
      totalMessages,
      activeVoiceParticipants,
      bannedUsers,
      newUsersLast7Days,
      newServersLast7Days,
      messagesLast24h,
      generatedAt: now.toISOString(),
    };
  }

  /**
   * Son `days` gün için günlük yeni kullanıcı kayıt sayısı — Faz 7.5'teki
   * yönetim paneli için basit bir büyüme grafiği besler.
   *
   * `make_interval(days => ...)` kullanımı BİLİNÇLİDİR: ham string
   * birleştirme yerine (`INTERVAL '${days} days'`) parametreli, SQL
   * enjeksiyonuna kapalı bir biçimdir — `days` zaten controller'da
   * doğrulanıp sınırlandırılır ama savunmada katman ilkesi (defense in
   * depth) gereği burada da güvenli yazılır.
   */
  async getDailySignups(days: number): Promise<DailyCount[]> {
    const rows = await this.prisma.$queryRaw<Array<{ day: Date; count: bigint }>>`
      SELECT date_trunc('day', "createdAt") AS day, COUNT(*)::bigint AS count
      FROM "users"
      WHERE "createdAt" >= NOW() - make_interval(days => ${days})
      GROUP BY day
      ORDER BY day ASC
    `;
    return rows.map((row) => ({
      date: row.day.toISOString().slice(0, 10),
      count: Number(row.count),
    }));
  }

  async getDailyMessages(days: number): Promise<DailyCount[]> {
    const rows = await this.prisma.$queryRaw<Array<{ day: Date; count: bigint }>>`
      SELECT date_trunc('day', "createdAt") AS day, COUNT(*)::bigint AS count
      FROM "messages"
      WHERE "isDeleted" = false AND "createdAt" >= NOW() - make_interval(days => ${days})
      GROUP BY day
      ORDER BY day ASC
    `;
    return rows.map((row) => ({
      date: row.day.toISOString().slice(0, 10),
      count: Number(row.count),
    }));
  }
}
