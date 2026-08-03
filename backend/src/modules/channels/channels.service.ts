import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditLogAction } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { AuditLogService } from '@/modules/audit-log/audit-log.service';
import { CreateChannelDto, ReorderChannelsDto, UpdateChannelDto } from './dto/channels.dto';

@Injectable()
export class ChannelsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async list(serverId: string) {
    return this.prisma.channel.findMany({
      where: { serverId },
      orderBy: [{ position: 'asc' }],
    });
  }

  async create(serverId: string, userId: string, dto: CreateChannelDto) {
    const lastPosition = await this.prisma.channel.count({ where: { serverId } });
    const channel = await this.prisma.channel.create({
      data: {
        serverId,
        name: dto.name,
        type: dto.type,
        parentId: dto.parentId,
        topic: dto.topic,
        position: lastPosition,
      },
    });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.CHANNEL_CREATE,
      targetType: 'channel',
      targetId: channel.id,
    });
    return channel;
  }

  private async findOrThrow(serverId: string, channelId: string) {
    const channel = await this.prisma.channel.findFirst({ where: { id: channelId, serverId } });
    if (!channel) throw new NotFoundException('Kanal bulunamadı.');
    return channel;
  }

  async update(serverId: string, channelId: string, userId: string, dto: UpdateChannelDto) {
    await this.findOrThrow(serverId, channelId);
    const updated = await this.prisma.channel.update({ where: { id: channelId }, data: dto });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.CHANNEL_UPDATE,
      targetType: 'channel',
      targetId: channelId,
    });
    return updated;
  }

  async remove(serverId: string, channelId: string, userId: string) {
    await this.findOrThrow(serverId, channelId);
    await this.prisma.channel.delete({ where: { id: channelId } });
    await this.auditLog.record({
      serverId,
      userId,
      action: AuditLogAction.CHANNEL_DELETE,
      targetType: 'channel',
      targetId: channelId,
    });
  }

  /** Sürükle-bırak ile kanal/kategori sıralamasını topluca günceller. */
  async reorder(serverId: string, dto: ReorderChannelsDto) {
    await this.prisma.$transaction(
      dto.channels.map((c) =>
        this.prisma.channel.updateMany({
          where: { id: c.id, serverId },
          data: { position: c.position, parentId: c.parentId ?? null },
        }),
      ),
    );
    return this.list(serverId);
  }
}
