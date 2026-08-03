import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditLogAction, ChannelType } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { AuditLogService } from '@/modules/audit-log/audit-log.service';
import { DEFAULT_EVERYONE_PERMISSIONS } from '@/common/permissions/permissions.enum';
import { CreateServerDto, UpdateMemberDto, UpdateServerDto } from './dto/servers.dto';

const MEMBER_PUBLIC_SELECT = {
  id: true,
  nickname: true,
  joinedAt: true,
  isMuted: true,
  isDeafened: true,
  timeoutUntil: true,
  user: {
    select: {
      id: true,
      username: true,
      discriminator: true,
      displayName: true,
      avatarUrl: true,
      status: true,
    },
  },
  roles: { include: { role: true } },
} as const;

@Injectable()
export class ServersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  /**
   * Yeni bir sunucu oluşturur ve Discord'un "yeni sunucu" akışındaki gibi
   * hazır bir başlangıç ortamı kurar: @everyone rolü, sahibi bu role bağlar,
   * varsayılan bir metin ve bir sesli kanal açar. Tüm adımlar tek bir
   * transaction içinde yürütülür; herhangi biri başarısız olursa hiçbiri
   * kalıcı olmaz (ör. yarım kalmış sunucu oluşmaz).
   */
  async create(ownerId: string, dto: CreateServerDto) {
    return this.prisma.$transaction(async (tx) => {
      const server = await tx.server.create({
        data: {
          name: dto.name,
          description: dto.description,
          iconUrl: dto.iconUrl,
          ownerId,
        },
      });

      const everyoneRole = await tx.role.create({
        data: {
          serverId: server.id,
          name: '@everyone',
          color: '#99AAB5',
          position: 0,
          isHoisted: false,
          isMentionable: false,
          permissions: DEFAULT_EVERYONE_PERMISSIONS,
        },
      });

      const member = await tx.serverMember.create({
        data: { serverId: server.id, userId: ownerId },
      });
      await tx.memberRole.create({
        data: { serverMemberId: member.id, roleId: everyoneRole.id },
      });

      await tx.channel.create({
        data: { serverId: server.id, name: 'genel', type: ChannelType.TEXT, position: 0 },
      });
      await tx.channel.create({
        data: { serverId: server.id, name: 'Genel', type: ChannelType.VOICE, position: 1 },
      });

      await this.auditLog.record({
        serverId: server.id,
        userId: ownerId,
        action: AuditLogAction.SERVER_CREATE,
        targetType: 'server',
        targetId: server.id,
      });

      return server;
    });
  }

  /** Kullanıcının üyesi olduğu tüm sunucuları döner (client açılışında sol menü için). */
  async findMyServers(userId: string) {
    const memberships = await this.prisma.serverMember.findMany({
      where: { userId },
      include: { server: true },
      orderBy: { joinedAt: 'asc' },
    });
    return memberships.map((m) => m.server);
  }

  async findOneOrThrow(serverId: string) {
    const server = await this.prisma.server.findUnique({ where: { id: serverId } });
    if (!server) throw new NotFoundException('Sunucu bulunamadı.');
    return server;
  }

  async assertMember(serverId: string, userId: string) {
    const member = await this.prisma.serverMember.findUnique({
      where: { serverId_userId: { serverId, userId } },
    });
    if (!member) throw new ForbiddenException('Bu sunucunun üyesi değilsiniz.');
    return member;
  }

  async getDetail(serverId: string, userId: string) {
    await this.assertMember(serverId, userId);
    const server = await this.prisma.server.findUnique({
      where: { id: serverId },
      include: {
        channels: { orderBy: { position: 'asc' } },
        roles: { orderBy: { position: 'desc' } },
      },
    });
    if (!server) throw new NotFoundException('Sunucu bulunamadı.');
    return server;
  }

  async update(serverId: string, userId: string, dto: UpdateServerDto) {
    const server = await this.findOneOrThrow(serverId);
    const updated = await this.prisma.server.update({ where: { id: serverId }, data: dto });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.SERVER_UPDATE,
      targetType: 'server',
      targetId: serverId,
      metadata: { before: { name: server.name }, after: { name: updated.name } },
    });
    return updated;
  }

  async delete(serverId: string, userId: string) {
    const server = await this.findOneOrThrow(serverId);
    if (server.ownerId !== userId) {
      throw new ForbiddenException('Sadece sunucu sahibi sunucuyu silebilir.');
    }
    await this.prisma.server.delete({ where: { id: serverId } });
    await this.auditLog.record({
      userId,
      action: AuditLogAction.SERVER_DELETE,
      targetType: 'server',
      targetId: serverId,
    });
  }

  async listMembers(serverId: string, userId: string) {
    await this.assertMember(serverId, userId);
    return this.prisma.serverMember.findMany({
      where: { serverId },
      select: MEMBER_PUBLIC_SELECT,
      orderBy: { joinedAt: 'asc' },
    });
  }

  async updateMember(serverId: string, memberId: string, dto: UpdateMemberDto) {
    const member = await this.prisma.serverMember.findFirst({ where: { id: memberId, serverId } });
    if (!member) throw new NotFoundException('Üye bulunamadı.');
    return this.prisma.serverMember.update({
      where: { id: memberId },
      data: { nickname: dto.nickname },
      select: MEMBER_PUBLIC_SELECT,
    });
  }

  /** Sunucudan kendi isteğiyle ayrılma. Sahip, sunucudan bu yolla ayrılamaz (önce devretmeli/silmeli). */
  async leave(serverId: string, userId: string) {
    const server = await this.findOneOrThrow(serverId);
    if (server.ownerId === userId) {
      throw new ForbiddenException(
        'Sunucu sahibi sunucudan ayrılamaz; sahipliği devretmeli veya sunucuyu silmelisiniz.',
      );
    }
    const member = await this.assertMember(serverId, userId);
    await this.prisma.serverMember.delete({ where: { id: member.id } });
  }

  /**
   * Bir kullanıcıyı sunucuya, @everyone rolüne otomatik bağlayarak ekler.
   * `invites.service.ts` (davetle katılma) tarafından çağrılır.
   */
  async addMemberWithDefaultRole(serverId: string, userId: string) {
    const existing = await this.prisma.serverMember.findUnique({
      where: { serverId_userId: { serverId, userId } },
    });
    if (existing) return existing;

    const everyoneRole = await this.prisma.role.findFirst({
      where: { serverId, name: '@everyone' },
    });

    return this.prisma.$transaction(async (tx) => {
      const member = await tx.serverMember.create({ data: { serverId, userId } });
      if (everyoneRole) {
        await tx.memberRole.create({
          data: { serverMemberId: member.id, roleId: everyoneRole.id },
        });
      }
      return member;
    });
  }
}
