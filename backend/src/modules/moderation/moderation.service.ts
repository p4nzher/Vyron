import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditLogAction, ModerationActionType } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { AuditLogService } from '@/modules/audit-log/audit-log.service';
import { getHighestPosition } from '@/common/permissions/permissions.util';

type ActorContext = { isOwner: boolean; roles: { position: number }[] };

@Injectable()
export class ModerationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  /**
   * Hedef kullanıcının bir moderasyon işlemine karşı "dokunulmaz" olup
   * olmadığını kontrol eder: sunucu sahibine hiçbir işlem uygulanamaz;
   * eşit ya da daha üst rütbeli bir üyeye de (sahip olmayan aktörler için)
   * işlem uygulanamaz.
   */
  private async assertCanModerate(serverId: string, actor: ActorContext, targetUserId: string) {
    const server = await this.prisma.server.findUnique({ where: { id: serverId } });
    if (!server) throw new NotFoundException('Sunucu bulunamadı.');
    if (server.ownerId === targetUserId) {
      throw new ForbiddenException('Sunucu sahibine moderasyon işlemi uygulanamaz.');
    }

    const targetMember = await this.prisma.serverMember.findUnique({
      where: { serverId_userId: { serverId, userId: targetUserId } },
      include: { roles: { include: { role: true } } },
    });
    if (!targetMember) throw new NotFoundException('Kullanıcı bu sunucunun üyesi değil.');

    if (!actor.isOwner) {
      const actorHighest = getHighestPosition(actor.roles);
      const targetHighest = getHighestPosition(targetMember.roles.map((r) => r.role));
      if (targetHighest >= actorHighest) {
        throw new ForbiddenException(
          'Kendi rol seviyenizle aynı veya daha yüksek rütbeli bir üyeye işlem uygulayamazsınız.',
        );
      }
    }
    return targetMember;
  }

  async kick(serverId: string, actorId: string, actor: ActorContext, targetUserId: string, reason?: string) {
    const targetMember = await this.assertCanModerate(serverId, actor, targetUserId);
    await this.prisma.serverMember.delete({ where: { id: targetMember.id } });
    await this.logAction(serverId, actorId, targetUserId, ModerationActionType.KICK, reason);
    await this.auditLog.record({
      serverId,
      userId: actorId,
      action: AuditLogAction.MEMBER_KICK,
      targetType: 'user',
      targetId: targetUserId,
      metadata: reason ? { reason } : undefined,
    });
  }

  async ban(serverId: string, actorId: string, actor: ActorContext, targetUserId: string, reason?: string) {
    // Üye olmayan (örn. daha önce ayrılmış) bir kullanıcı da yasaklanabilir; bu yüzden
    // üyelik zorunlu değildir, ancak üyeyse hiyerarşi kontrolü uygulanır.
    const server = await this.prisma.server.findUnique({ where: { id: serverId } });
    if (!server) throw new NotFoundException('Sunucu bulunamadı.');
    if (server.ownerId === targetUserId) {
      throw new ForbiddenException('Sunucu sahibi yasaklanamaz.');
    }

    const targetMember = await this.prisma.serverMember.findUnique({
      where: { serverId_userId: { serverId, userId: targetUserId } },
      include: { roles: { include: { role: true } } },
    });
    if (targetMember && !actor.isOwner) {
      const actorHighest = getHighestPosition(actor.roles);
      const targetHighest = getHighestPosition(targetMember.roles.map((r) => r.role));
      if (targetHighest >= actorHighest) {
        throw new ForbiddenException(
          'Kendi rol seviyenizle aynı veya daha yüksek rütbeli bir üyeyi yasaklayamazsınız.',
        );
      }
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.serverBan.upsert({
        where: { serverId_userId: { serverId, userId: targetUserId } },
        create: { serverId, userId: targetUserId, bannedById: actorId, reason },
        update: { reason, bannedById: actorId },
      });
      if (targetMember) {
        await tx.serverMember.delete({ where: { id: targetMember.id } });
      }
    });

    await this.logAction(serverId, actorId, targetUserId, ModerationActionType.BAN, reason);
    await this.auditLog.record({
      serverId,
      userId: actorId,
      action: AuditLogAction.MEMBER_BAN,
      targetType: 'user',
      targetId: targetUserId,
      metadata: reason ? { reason } : undefined,
    });
  }

  async unban(serverId: string, actorId: string, targetUserId: string) {
    const ban = await this.prisma.serverBan.findUnique({
      where: { serverId_userId: { serverId, userId: targetUserId } },
    });
    if (!ban) throw new NotFoundException('Bu kullanıcı için aktif bir yasak bulunamadı.');
    await this.prisma.serverBan.delete({ where: { id: ban.id } });
    await this.logAction(serverId, actorId, targetUserId, ModerationActionType.UNBAN);
  }

  async listBans(serverId: string) {
    return this.prisma.serverBan.findMany({ where: { serverId }, orderBy: { createdAt: 'desc' } });
  }

  async timeout(
    serverId: string,
    actorId: string,
    actor: ActorContext,
    targetUserId: string,
    durationSeconds: number,
    reason?: string,
  ) {
    const targetMember = await this.assertCanModerate(serverId, actor, targetUserId);
    const timeoutUntil = new Date(Date.now() + durationSeconds * 1000);
    await this.prisma.serverMember.update({
      where: { id: targetMember.id },
      data: { timeoutUntil },
    });
    await this.logAction(serverId, actorId, targetUserId, ModerationActionType.TIMEOUT, reason, durationSeconds);
    await this.auditLog.record({
      serverId,
      userId: actorId,
      action: AuditLogAction.MEMBER_TIMEOUT,
      targetType: 'user',
      targetId: targetUserId,
      metadata: { durationSeconds, reason },
    });
    return { timeoutUntil };
  }

  async removeTimeout(serverId: string, actorId: string, actor: ActorContext, targetUserId: string) {
    const targetMember = await this.assertCanModerate(serverId, actor, targetUserId);
    await this.prisma.serverMember.update({ where: { id: targetMember.id }, data: { timeoutUntil: null } });
    await this.logAction(serverId, actorId, targetUserId, ModerationActionType.UNBAN); // "susturma kaldırıldı" izi
  }

  async warn(serverId: string, actorId: string, actor: ActorContext, targetUserId: string, reason?: string) {
    await this.assertCanModerate(serverId, actor, targetUserId);
    return this.logAction(serverId, actorId, targetUserId, ModerationActionType.WARN, reason);
  }

  async listActionsForMember(serverId: string, targetUserId: string) {
    return this.prisma.moderationAction.findMany({
      where: { serverId, targetId: targetUserId },
      orderBy: { createdAt: 'desc' },
      include: { actor: { select: { id: true, username: true, discriminator: true } } },
    });
  }

  private logAction(
    serverId: string,
    actorId: string,
    targetId: string,
    actionType: ModerationActionType,
    reason?: string,
    durationSeconds?: number,
  ) {
    return this.prisma.moderationAction.create({
      data: { serverId, actorId, targetId, actionType, reason, durationSeconds },
    });
  }
}
