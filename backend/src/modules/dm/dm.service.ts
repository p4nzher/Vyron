import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { CreateDmChannelDto } from './dto/dm.dto';

const PARTICIPANT_PUBLIC_SELECT = {
  id: true,
  username: true,
  discriminator: true,
  displayName: true,
  avatarUrl: true,
  status: true,
} as const;

const DM_CHANNEL_INCLUDE = {
  participants: { include: { user: { select: PARTICIPANT_PUBLIC_SELECT } } },
  messages: {
    where: { isDeleted: false },
    orderBy: { createdAt: 'desc' as const },
    take: 1,
    include: { author: { select: PARTICIPANT_PUBLIC_SELECT } },
  },
} as const;

@Injectable()
export class DmService {
  constructor(private readonly prisma: PrismaService) {}

  async assertParticipant(dmChannelId: string, userId: string) {
    const participant = await this.prisma.dMParticipant.findUnique({
      where: { dmChannelId_userId: { dmChannelId, userId } },
    });
    if (!participant) throw new ForbiddenException('Bu özel mesaj kanalına erişiminiz yok.');
    return participant;
  }

  async listMine(userId: string) {
    const channels = await this.prisma.dMChannel.findMany({
      where: { participants: { some: { userId } } },
      include: DM_CHANNEL_INCLUDE,
    });
    // En son mesajı olana göre azalan sırada (aktif konuşmalar üstte).
    return channels.sort((a, b) => {
      const aTime = a.messages[0]?.createdAt ?? a.createdAt;
      const bTime = b.messages[0]?.createdAt ?? b.createdAt;
      return bTime.getTime() - aTime.getTime();
    });
  }

  async getOne(dmChannelId: string, userId: string) {
    await this.assertParticipant(dmChannelId, userId);
    const channel = await this.prisma.dMChannel.findUnique({
      where: { id: dmChannelId },
      include: DM_CHANNEL_INCLUDE,
    });
    if (!channel) throw new NotFoundException('Kanal bulunamadı.');
    return channel;
  }

  async createOrGet(userId: string, dto: CreateDmChannelDto) {
    const otherIds = dto.participantIds.filter((id) => id !== userId);
    if (otherIds.length === 0) {
      throw new BadRequestException('En az bir farklı kullanıcı belirtmelisiniz.');
    }

    const isGroup = Boolean(dto.isGroup) || otherIds.length > 1;

    // Engelleme kontrolü: taraflardan biri diğerini engellemişse DM açılamaz.
    const blocks = await this.prisma.block.findMany({
      where: {
        OR: otherIds.flatMap((otherId) => [
          { blockerId: userId, blockedId: otherId },
          { blockerId: otherId, blockedId: userId },
        ]),
      },
    });
    if (blocks.length > 0) {
      throw new ForbiddenException('Engellenen bir kullanıcıyla özel mesaj başlatılamaz.');
    }

    if (!isGroup) {
      // Birebir DM: aynı iki kişi arasında zaten bir kanal varsa onu döndür (tekilleştirme).
      const existing = await this.prisma.dMChannel.findFirst({
        where: {
          isGroup: false,
          AND: [
            { participants: { some: { userId } } },
            { participants: { some: { userId: otherIds[0] } } },
          ],
        },
        include: DM_CHANNEL_INCLUDE,
      });
      if (existing) return existing;
    }

    const channel = await this.prisma.dMChannel.create({
      data: {
        isGroup,
        name: isGroup ? dto.name : undefined,
        participants: {
          createMany: {
            data: [userId, ...otherIds].map((id) => ({ userId: id })),
          },
        },
      },
      include: DM_CHANNEL_INCLUDE,
    });
    return channel;
  }

  async markRead(dmChannelId: string, userId: string) {
    await this.assertParticipant(dmChannelId, userId);
    await this.prisma.dMParticipant.update({
      where: { dmChannelId_userId: { dmChannelId, userId } },
      data: { lastReadAt: new Date() },
    });
    return { ok: true };
  }
}
