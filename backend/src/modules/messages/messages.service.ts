import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import { AttachmentType, MessageType } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { StorageService } from '@/modules/storage/storage.service';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { hasPermission } from '@/common/permissions/permissions.util';
import { MessagesGateway } from './messages.gateway';
import { AddReactionDto, CreateMessageDto, ListMessagesQueryDto, UpdateMessageDto } from './dto/messages.dto';

/** Bir mesajın bir SUNUCU KANALI'na mı yoksa bir ÖZEL MESAJ (DM) kanalına mı ait olduğunu belirtir. */
export type MessageScope = { channelId: string } | { dmChannelId: string };

const AUTHOR_PUBLIC_SELECT = {
  id: true,
  username: true,
  discriminator: true,
  displayName: true,
  avatarUrl: true,
  status: true,
} as const;

const MESSAGE_INCLUDE = {
  author: { select: AUTHOR_PUBLIC_SELECT },
  attachments: true,
  reactions: true,
  replyTo: {
    include: { author: { select: AUTHOR_PUBLIC_SELECT } },
  },
} as const;

function isChannelScope(scope: MessageScope): scope is { channelId: string } {
  return 'channelId' in scope;
}

/** Socket.IO oda adını mesaj kapsamından türetir (bkz. `messages.gateway.ts`). */
export function scopeToRoom(scope: MessageScope): string {
  return isChannelScope(scope) ? `channel:${scope.channelId}` : `dm:${scope.dmChannelId}`;
}

@Injectable()
export class MessagesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
    @Inject(forwardRef(() => MessagesGateway))
    private readonly gateway: MessagesGateway,
  ) {}

  // ---------------------------------------------------------------------
  // ERİŞİM / YETKİ KONTROLLERİ
  // ---------------------------------------------------------------------

  /**
   * Kullanıcının bu kapsamda (kanal ya da DM) mesajlaşabilir/okuyabilir
   * olduğunu doğrular. Sunucu kanalları için ayrıca `ServerMember` ve rol
   * yetkilerini döner; DM'ler için katılımcı kaydını döner.
   */
  private async assertAccess(scope: MessageScope, userId: string, requiredPermission?: ServerPermission) {
    if (isChannelScope(scope)) {
      const channel = await this.prisma.channel.findUnique({ where: { id: scope.channelId } });
      if (!channel) throw new NotFoundException('Kanal bulunamadı.');

      const member = await this.prisma.serverMember.findUnique({
        where: { serverId_userId: { serverId: channel.serverId, userId } },
        include: { roles: { include: { role: true } } },
      });
      if (!member) throw new ForbiddenException('Bu kanala erişiminiz yok.');

      if (requiredPermission) {
        const server = await this.prisma.server.findUniqueOrThrow({ where: { id: channel.serverId } });
        const roles = member.roles.map((r) => r.role);
        const allowed = hasPermission({ isOwner: server.ownerId === userId, roles }, requiredPermission);
        if (!allowed) {
          throw new ForbiddenException(`Bu işlem için '${requiredPermission}' yetkisi gereklidir.`);
        }
      }
      return { channel, member };
    }

    const participant = await this.prisma.dMParticipant.findUnique({
      where: { dmChannelId_userId: { dmChannelId: scope.dmChannelId, userId } },
    });
    if (!participant) throw new ForbiddenException('Bu özel mesaj kanalına erişiminiz yok.');
    return { participant };
  }

  private whereForScope(scope: MessageScope) {
    return isChannelScope(scope)
      ? { channelId: scope.channelId, dmChannelId: null }
      : { dmChannelId: scope.dmChannelId, channelId: null };
  }

  // ---------------------------------------------------------------------
  // LİSTELEME (İMLEÇ TABANLI SAYFALAMA)
  // ---------------------------------------------------------------------

  async list(scope: MessageScope, userId: string, query: ListMessagesQueryDto) {
    await this.assertAccess(scope, userId);
    const limit = query.limit ?? 50;

    const cursorOptions = query.before
      ? { cursor: { id: query.before }, skip: 1, orderBy: { createdAt: 'desc' as const } }
      : query.after
        ? { cursor: { id: query.after }, skip: 1, orderBy: { createdAt: 'asc' as const } }
        : { orderBy: { createdAt: 'desc' as const } };

    const rows = await this.prisma.message.findMany({
      where: { ...this.whereForScope(scope), isDeleted: false },
      take: limit + 1,
      include: MESSAGE_INCLUDE,
      ...cursorOptions,
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;
    // İstemciye her zaman kronolojik (eskiden yeniye) sırayla döneriz.
    const chronological = query.after ? page : [...page].reverse();

    return { messages: chronological, hasMore };
  }

  async getOne(scope: MessageScope, userId: string, messageId: string) {
    await this.assertAccess(scope, userId);
    const message = await this.prisma.message.findFirst({
      where: { id: messageId, ...this.whereForScope(scope), isDeleted: false },
      include: MESSAGE_INCLUDE,
    });
    if (!message) throw new NotFoundException('Mesaj bulunamadı.');
    return message;
  }

  // ---------------------------------------------------------------------
  // OLUŞTURMA
  // ---------------------------------------------------------------------

  async create(scope: MessageScope, userId: string, dto: CreateMessageDto) {
    await this.assertAccess(scope, userId, isChannelScope(scope) ? ServerPermission.SEND_MESSAGES : undefined);

    const hasContent = Boolean(dto.content && dto.content.trim().length > 0);
    const hasAttachments = Boolean(dto.attachments && dto.attachments.length > 0);
    if (!hasContent && !hasAttachments) {
      throw new BadRequestException('Bir mesaj içerik veya en az bir dosya eki içermelidir.');
    }

    if (dto.replyToId) {
      const original = await this.prisma.message.findFirst({
        where: { id: dto.replyToId, ...this.whereForScope(scope) },
      });
      if (!original) throw new BadRequestException('Yanıtlanan mesaj bu kanalda bulunamadı.');
    }

    const message = await this.prisma.message.create({
      data: {
        ...(isChannelScope(scope) ? { channelId: scope.channelId } : { dmChannelId: scope.dmChannelId }),
        authorId: userId,
        content: dto.content?.trim() || null,
        type: dto.replyToId ? MessageType.REPLY : MessageType.DEFAULT,
        replyToId: dto.replyToId,
        attachments: hasAttachments
          ? {
              create: (dto.attachments ?? []).map((a) => ({
                url: a.url,
                fileName: a.fileName,
                fileSizeBytes: a.fileSizeBytes,
                mimeType: a.mimeType,
                width: a.width,
                height: a.height,
                durationMs: a.durationMs,
                type: this.resolveAttachmentType(a),
              })),
            }
          : undefined,
      },
      include: MESSAGE_INCLUDE,
    });

    this.gateway.broadcast(scope, 'message:created', message);
    return message;
  }

  private resolveAttachmentType(a: { mimeType: string; isSticker?: boolean; isVoiceNote?: boolean }): AttachmentType {
    if (a.isSticker) return AttachmentType.STICKER;
    if (a.isVoiceNote) return AttachmentType.VOICE_NOTE;
    return this.storageService.inferAttachmentType(a.mimeType);
  }

  // ---------------------------------------------------------------------
  // GÜNCELLEME / SİLME
  // ---------------------------------------------------------------------

  async update(scope: MessageScope, userId: string, messageId: string, dto: UpdateMessageDto) {
    await this.assertAccess(scope, userId);
    const existing = await this.getExistingOrThrow(scope, messageId);
    if (existing.authorId !== userId) {
      throw new ForbiddenException('Sadece kendi mesajınızı düzenleyebilirsiniz.');
    }

    const updated = await this.prisma.message.update({
      where: { id: messageId },
      data: { content: dto.content.trim(), isEdited: true },
      include: MESSAGE_INCLUDE,
    });

    this.gateway.broadcast(scope, 'message:updated', updated);
    return updated;
  }

  async remove(scope: MessageScope, userId: string, messageId: string) {
    // Önce üyelik/erişim doğrulanır (mesajın var olup olmadığını yetkisiz
    // kullanıcıya ifşa etmemek için varlık kontrolünden ÖNCE yapılır).
    await this.assertAccess(scope, userId);
    const existing = await this.getExistingOrThrow(scope, messageId);

    if (existing.authorId !== userId) {
      if (!isChannelScope(scope)) {
        throw new ForbiddenException('Özel mesajlarda sadece kendi mesajınızı silebilirsiniz.');
      }
      // Kendi mesajı değilse, sunucu kanalında MANAGE_MESSAGES yetkisi aranır.
      await this.assertAccess(scope, userId, ServerPermission.MANAGE_MESSAGES);
    }

    // Soft-delete: moderasyon/denetim amaçlı içerik veritabanında iz olarak kalır.
    await this.prisma.message.update({
      where: { id: messageId },
      data: { isDeleted: true, content: null },
    });

    this.gateway.broadcast(scope, 'message:deleted', { id: messageId });
  }

  async togglePin(scope: MessageScope, userId: string, messageId: string, pinned: boolean) {
    await this.assertAccess(scope, userId, isChannelScope(scope) ? ServerPermission.MANAGE_MESSAGES : undefined);
    const existing = await this.getExistingOrThrow(scope, messageId);
    const updated = await this.prisma.message.update({
      where: { id: existing.id },
      data: { isPinned: pinned },
      include: MESSAGE_INCLUDE,
    });
    this.gateway.broadcast(scope, 'message:updated', updated);
    return updated;
  }

  private async getExistingOrThrow(scope: MessageScope, messageId: string) {
    const existing = await this.prisma.message.findFirst({
      where: { id: messageId, ...this.whereForScope(scope), isDeleted: false },
    });
    if (!existing) throw new NotFoundException('Mesaj bulunamadı.');
    return existing;
  }

  // ---------------------------------------------------------------------
  // TEPKİLER (EMOJI REACTIONS)
  // ---------------------------------------------------------------------

  async addReaction(scope: MessageScope, userId: string, messageId: string, dto: AddReactionDto) {
    await this.assertAccess(scope, userId, isChannelScope(scope) ? ServerPermission.ADD_REACTIONS : undefined);
    await this.getExistingOrThrow(scope, messageId);

    const reaction = await this.prisma.messageReaction.upsert({
      where: { messageId_userId_emoji: { messageId, userId, emoji: dto.emoji } },
      create: { messageId, userId, emoji: dto.emoji },
      update: {},
    });

    this.gateway.broadcast(scope, 'reaction:added', reaction);
    return reaction;
  }

  async removeReaction(scope: MessageScope, userId: string, messageId: string, emoji: string) {
    await this.assertAccess(scope, userId);
    await this.prisma.messageReaction
      .delete({ where: { messageId_userId_emoji: { messageId, userId, emoji } } })
      .catch(() => undefined); // Zaten yoksa sessizce yok say (idempotent davranış)

    this.gateway.broadcast(scope, 'reaction:removed', { messageId, userId, emoji });
  }
}
