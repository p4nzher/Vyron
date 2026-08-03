import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { customAlphabet } from 'nanoid';
import { AuditLogAction } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { AuditLogService } from '@/modules/audit-log/audit-log.service';
import { ServersService } from '@/modules/servers/servers.service';
import { CreateInviteDto } from './dto/invites.dto';

// Karışabilecek karakterler (0/O, 1/I/l) elenmiş okunaklı alfabe.
const generateCode = customAlphabet('23456789ABCDEFGHJKLMNPQRSTUVWXYZ', 8);

@Injectable()
export class InvitesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
    private readonly serversService: ServersService,
  ) {}

  async create(serverId: string, userId: string, dto: CreateInviteDto) {
    const code = generateCode();
    const invite = await this.prisma.invite.create({
      data: {
        code,
        serverId,
        createdById: userId,
        maxUses: dto.maxUses,
        expiresAt: dto.expiresInSeconds ? new Date(Date.now() + dto.expiresInSeconds * 1000) : null,
      },
    });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.INVITE_CREATE,
      targetType: 'invite',
      targetId: invite.id,
    });
    return invite;
  }

  async listForServer(serverId: string) {
    return this.prisma.invite.findMany({
      where: { serverId },
      orderBy: { createdAt: 'desc' },
      include: { createdBy: { select: { id: true, username: true, discriminator: true } } },
    });
  }

  async revoke(serverId: string, inviteId: string, userId: string) {
    const invite = await this.prisma.invite.findFirst({ where: { id: inviteId, serverId } });
    if (!invite) throw new NotFoundException('Davet bulunamadı.');
    await this.prisma.invite.delete({ where: { id: inviteId } });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.INVITE_DELETE,
      targetType: 'invite',
      targetId: inviteId,
    });
  }

  /** Davet kodunu, üye ekleme mantığı çalıştırmadan önizler (katılma ekranı için). */
  async preview(code: string) {
    const invite = await this.findValidOrThrow(code);
    const server = await this.prisma.server.findUnique({
      where: { id: invite.serverId },
      include: { _count: { select: { members: true } } },
    });
    return { server, invite };
  }

  /** Bir kullanıcı davet koduyla sunucuya katılır. */
  async join(code: string, userId: string) {
    const invite = await this.findValidOrThrow(code);

    const banned = await this.prisma.serverBan.findUnique({
      where: { serverId_userId: { serverId: invite.serverId, userId } },
    });
    if (banned) {
      throw new ForbiddenException('Bu sunucudan yasaklandığınız için katılamazsınız.');
    }

    const member = await this.serversService.addMemberWithDefaultRole(invite.serverId, userId);
    await this.prisma.invite.update({ where: { id: invite.id }, data: { useCount: { increment: 1 } } });
    return { server: invite.server, member };
  }

  private async findValidOrThrow(code: string) {
    const invite = await this.prisma.invite.findUnique({
      where: { code },
      include: { server: true },
    });
    if (!invite) throw new NotFoundException('Geçersiz davet kodu.');
    if (invite.expiresAt && invite.expiresAt < new Date()) {
      throw new BadRequestException('Bu davetin süresi dolmuş.');
    }
    if (invite.maxUses && invite.useCount >= invite.maxUses) {
      throw new BadRequestException('Bu davetin kullanım limiti dolmuş.');
    }
    return invite;
  }
}
