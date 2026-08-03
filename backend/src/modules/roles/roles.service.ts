import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { AuditLogAction } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { AuditLogService } from '@/modules/audit-log/audit-log.service';
import { getHighestPosition } from '@/common/permissions/permissions.util';
import { CreateRoleDto, UpdateRoleDto } from './dto/roles.dto';

@Injectable()
export class RolesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async list(serverId: string) {
    return this.prisma.role.findMany({ where: { serverId }, orderBy: { position: 'desc' } });
  }

  async create(serverId: string, userId: string, dto: CreateRoleDto) {
    const highestPosition = await this.prisma.role.aggregate({
      where: { serverId },
      _max: { position: true },
    });
    const role = await this.prisma.role.create({
      data: {
        serverId,
        name: dto.name,
        color: dto.color ?? '#99AAB5',
        permissions: dto.permissions ?? {},
        isHoisted: dto.isHoisted ?? false,
        isMentionable: dto.isMentionable ?? true,
        // Yeni rol her zaman @everyone'ın (position 0) üstünde, mevcut en yüksek rolün altında açılır.
        position: (highestPosition._max.position ?? 0) + 1,
      },
    });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.ROLE_CREATE,
      targetType: 'role',
      targetId: role.id,
    });
    return role;
  }

  private async findOrThrow(serverId: string, roleId: string) {
    const role = await this.prisma.role.findFirst({ where: { id: roleId, serverId } });
    if (!role) throw new NotFoundException('Rol bulunamadı.');
    return role;
  }

  /**
   * Rol hiyerarşisi kuralı: sunucu sahibi hariç kimse, kendi en yüksek
   * rolüyle aynı veya daha yüksek konumdaki bir rolü değiştiremez/silemez.
   * Bu, alt yetkili bir yöneticinin kendine daha üst bir rol vermesini engeller.
   */
  private assertHierarchy(
    isOwner: boolean,
    actorRoles: { position: number }[],
    targetRole: { position: number; name: string },
  ) {
    if (isOwner) return;
    if (targetRole.name === '@everyone') {
      throw new ForbiddenException('@everyone rolü silinemez veya yeniden adlandırılamaz.');
    }
    const actorHighest = getHighestPosition(actorRoles);
    if (targetRole.position >= actorHighest) {
      throw new ForbiddenException(
        'Kendi rol seviyenizle aynı veya daha yüksek bir rolü değiştiremezsiniz.',
      );
    }
  }

  async update(
    serverId: string,
    roleId: string,
    userId: string,
    dto: UpdateRoleDto,
    actorContext: { isOwner: boolean; roles: { position: number }[] },
  ) {
    const role = await this.findOrThrow(serverId, roleId);
    this.assertHierarchy(actorContext.isOwner, actorContext.roles, role);

    const updated = await this.prisma.role.update({ where: { id: roleId }, data: dto });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.ROLE_UPDATE,
      targetType: 'role',
      targetId: roleId,
    });
    return updated;
  }

  async remove(
    serverId: string,
    roleId: string,
    userId: string,
    actorContext: { isOwner: boolean; roles: { position: number }[] },
  ) {
    const role = await this.findOrThrow(serverId, roleId);
    this.assertHierarchy(actorContext.isOwner, actorContext.roles, role);

    await this.prisma.role.delete({ where: { id: roleId } });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.ROLE_DELETE,
      targetType: 'role',
      targetId: roleId,
    });
  }

  async assignToMember(serverId: string, memberId: string, roleId: string, userId: string) {
    const member = await this.prisma.serverMember.findFirst({ where: { id: memberId, serverId } });
    if (!member) throw new NotFoundException('Üye bulunamadı.');
    await this.findOrThrow(serverId, roleId);

    await this.prisma.memberRole.upsert({
      where: { serverMemberId_roleId: { serverMemberId: memberId, roleId } },
      create: { serverMemberId: memberId, roleId },
      update: {},
    });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.ROLE_UPDATE,
      targetType: 'member_role',
      targetId: memberId,
      metadata: { roleId, op: 'assign' },
    });
    return this.prisma.memberRole.findMany({ where: { serverMemberId: memberId }, include: { role: true } });
  }

  async removeFromMember(serverId: string, memberId: string, roleId: string, userId: string) {
    const role = await this.findOrThrow(serverId, roleId);
    if (role.name === '@everyone') {
      throw new ForbiddenException('@everyone rolü bir üyeden kaldırılamaz.');
    }
    await this.prisma.memberRole.deleteMany({ where: { serverMemberId: memberId, roleId } });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.ROLE_UPDATE,
      targetType: 'member_role',
      targetId: memberId,
      metadata: { roleId, op: 'remove' },
    });
    return this.prisma.memberRole.findMany({ where: { serverMemberId: memberId }, include: { role: true } });
  }
}
