import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { ChannelType } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { MessagesGateway } from '@/modules/messages/messages.gateway';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { getHighestPosition, hasPermission } from '@/common/permissions/permissions.util';
import { LiveKitService } from './livekit.service';
import { UpdateVoiceStateDto } from './dto/voice.dto';

const PARTICIPANT_PUBLIC_SELECT = {
  id: true,
  username: true,
  discriminator: true,
  displayName: true,
  avatarUrl: true,
} as const;

const VOICE_STATE_INCLUDE = { user: { select: PARTICIPANT_PUBLIC_SELECT } } as const;

@Injectable()
export class VoiceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly liveKitService: LiveKitService,
    private readonly gateway: MessagesGateway,
  ) {}

  // ---------------------------------------------------------------------
  // ORTAK YARDIMCILAR
  // ---------------------------------------------------------------------

  private async loadVoiceChannel(channelId: string) {
    const channel = await this.prisma.channel.findUnique({ where: { id: channelId } });
    if (!channel) throw new NotFoundException('Kanal bulunamadı.');
    if (channel.type !== ChannelType.VOICE && channel.type !== ChannelType.STAGE) {
      throw new BadRequestException('Bu kanal sesli/görüntülü bir kanal değil.');
    }
    return channel;
  }

  private async loadMemberWithRoles(serverId: string, userId: string) {
    const member = await this.prisma.serverMember.findUnique({
      where: { serverId_userId: { serverId, userId } },
      include: { roles: { include: { role: true } } },
    });
    if (!member) throw new ForbiddenException('Bu sunucunun üyesi değilsiniz.');
    return member;
  }

  private async checkPermission(serverId: string, userId: string, permission: ServerPermission) {
    const server = await this.prisma.server.findUniqueOrThrow({ where: { id: serverId } });
    const member = await this.loadMemberWithRoles(serverId, userId);
    const roles = member.roles.map((r) => r.role);
    const allowed = hasPermission({ isOwner: server.ownerId === userId, roles }, permission);
    if (!allowed) throw new ForbiddenException(`Bu işlem için '${permission}' yetkisi gereklidir.`);
    return { server, member };
  }

  private notifyChannel(channelId: string, event: string, payload: unknown) {
    // MessagesGateway aynı "channel:<id>" oda adlandırmasını kullanır; sesli
    // kanal olayları için de aynı köprü yeniden kullanılır.
    this.gateway.broadcast({ channelId }, event, payload);
  }

  // ---------------------------------------------------------------------
  // KATILMA / AYRILMA
  // ---------------------------------------------------------------------

  async join(channelId: string, userId: string, username: string) {
    const channel = await this.loadVoiceChannel(channelId);
    const { member } = await this.checkPermission(channel.serverId, userId, ServerPermission.CONNECT_VOICE);

    if (member.timeoutUntil && member.timeoutUntil > new Date()) {
      throw new ForbiddenException('Geçici olarak susturulduğunuz (timeout) için sesli kanallara bağlanamazsınız.');
    }

    const currentCount = await this.prisma.voiceState.count({ where: { channelId } });
    const alreadyHere = await this.prisma.voiceState.findUnique({
      where: { userId_channelId: { userId, channelId } },
    });
    if (!alreadyHere && channel.userLimit && channel.userLimit > 0 && currentCount >= channel.userLimit) {
      throw new ForbiddenException('Bu sesli kanal dolu.');
    }

    // Bir kullanıcı aynı anda yalnızca bir sesli kanalda bulunabilir:
    // başka bir kanaldaki önceki VoiceState'i temizle ve o kanala haber ver.
    const previousStates = await this.prisma.voiceState.findMany({
      where: { userId, channelId: { not: channelId } },
    });
    for (const prev of previousStates) {
      await this.prisma.voiceState.delete({ where: { id: prev.id } });
      await this.liveKitService.removeParticipant(this.liveKitService.roomNameForChannel(prev.channelId), userId);
      this.notifyChannel(prev.channelId, 'voice:user-left', { userId, channelId: prev.channelId });
    }

    const server = await this.prisma.server.findUniqueOrThrow({ where: { id: channel.serverId } });
    const isOwner = server.ownerId === userId;
    const roles = member.roles.map((r) => r.role);
    const permCtx = { isOwner, roles };
    const canPublishAudio = hasPermission(permCtx, ServerPermission.SPEAK_VOICE);
    const canPublishVideo = hasPermission(permCtx, ServerPermission.VIDEO_VOICE);
    const canPublishScreenShare = hasPermission(permCtx, ServerPermission.SCREEN_SHARE);

    const roomName = this.liveKitService.roomNameForChannel(channelId);
    await this.liveKitService.ensureRoom(roomName, channel.userLimit ?? undefined);
    const token = await this.liveKitService.createAccessToken({
      roomName,
      userId,
      username,
      canPublishAudio,
      canPublishVideo,
      canPublishScreenShare,
    });

    const voiceState = await this.prisma.voiceState.upsert({
      where: { userId_channelId: { userId, channelId } },
      create: { userId, channelId, livekitRoomSid: roomName },
      update: { livekitRoomSid: roomName },
      include: VOICE_STATE_INCLUDE,
    });

    this.notifyChannel(channelId, 'voice:user-joined', voiceState);

    return {
      token,
      mediaUrl: this.liveKitService.mediaUrl,
      roomName,
      voiceState,
    };
  }

  async leave(channelId: string, userId: string) {
    const voiceState = await this.prisma.voiceState.findUnique({ where: { userId_channelId: { userId, channelId } } });
    if (!voiceState) return { ok: true };

    await this.prisma.voiceState.delete({ where: { id: voiceState.id } });
    await this.liveKitService.removeParticipant(this.liveKitService.roomNameForChannel(channelId), userId);
    this.notifyChannel(channelId, 'voice:user-left', { userId, channelId });
    return { ok: true };
  }

  // ---------------------------------------------------------------------
  // KENDİ DURUMUNU GÜNCELLEME (mikrofon/kamera/ekran paylaşımı aç-kapa)
  // ---------------------------------------------------------------------

  async updateOwnState(channelId: string, userId: string, dto: UpdateVoiceStateDto) {
    const channel = await this.loadVoiceChannel(channelId);
    const voiceState = await this.prisma.voiceState.findUnique({ where: { userId_channelId: { userId, channelId } } });
    if (!voiceState) throw new BadRequestException('Bu sesli kanala bağlı değilsiniz.');

    if (dto.isCameraOn) {
      await this.checkPermission(channel.serverId, userId, ServerPermission.VIDEO_VOICE);
    }
    if (dto.isScreenSharing) {
      await this.checkPermission(channel.serverId, userId, ServerPermission.SCREEN_SHARE);
    }

    const updated = await this.prisma.voiceState.update({
      where: { id: voiceState.id },
      data: {
        isMuted: dto.isMuted,
        isDeafened: dto.isDeafened,
        isCameraOn: dto.isCameraOn,
        isScreenSharing: dto.isScreenSharing,
      },
      include: VOICE_STATE_INCLUDE,
    });

    this.notifyChannel(channelId, 'voice:state-updated', updated);
    return updated;
  }

  async listParticipants(channelId: string, userId: string) {
    const channel = await this.loadVoiceChannel(channelId);
    await this.loadMemberWithRoles(channel.serverId, userId); // Sadece üyelik zorunlu, ekstra yetki değil
    return this.prisma.voiceState.findMany({ where: { channelId }, include: VOICE_STATE_INCLUDE });
  }

  // ---------------------------------------------------------------------
  // MODERASYON: ZORLA SUSTURMA / SAĞIRLAŞTIRMA / TAŞIMA / ATMA
  // ---------------------------------------------------------------------

  private async assertHierarchy(serverId: string, actorId: string, targetUserId: string) {
    const server = await this.prisma.server.findUniqueOrThrow({ where: { id: serverId } });
    if (server.ownerId === actorId) return; // Sahip her zaman işlem yapabilir
    if (server.ownerId === targetUserId) {
      throw new ForbiddenException('Sunucu sahibine sesli kanal işlemi uygulanamaz.');
    }
    const actorMember = await this.loadMemberWithRoles(serverId, actorId);
    const targetMember = await this.loadMemberWithRoles(serverId, targetUserId);
    const actorHighest = getHighestPosition(actorMember.roles.map((r) => r.role));
    const targetHighest = getHighestPosition(targetMember.roles.map((r) => r.role));
    if (targetHighest >= actorHighest) {
      throw new ForbiddenException('Kendi rol seviyenizle aynı veya daha yüksek rütbeli bir üyeye işlem uygulayamazsınız.');
    }
  }

  async forceMute(channelId: string, actorId: string, targetUserId: string, muted: boolean) {
    const channel = await this.loadVoiceChannel(channelId);
    await this.checkPermission(channel.serverId, actorId, ServerPermission.MUTE_MEMBERS_VOICE);
    await this.assertHierarchy(channel.serverId, actorId, targetUserId);

    const voiceState = await this.prisma.voiceState.findUnique({
      where: { userId_channelId: { userId: targetUserId, channelId } },
    });
    if (!voiceState) throw new NotFoundException('Kullanıcı bu sesli kanalda değil.');

    const updated = await this.prisma.voiceState.update({
      where: { id: voiceState.id },
      data: { isMuted: muted },
      include: VOICE_STATE_INCLUDE,
    });
    if (muted) {
      await this.liveKitService.muteParticipantTracks(this.liveKitService.roomNameForChannel(channelId), targetUserId);
    }
    this.notifyChannel(channelId, 'voice:force-muted', { userId: targetUserId, isMuted: muted });
    return updated;
  }

  async forceDeafen(channelId: string, actorId: string, targetUserId: string, deafened: boolean) {
    const channel = await this.loadVoiceChannel(channelId);
    await this.checkPermission(channel.serverId, actorId, ServerPermission.DEAFEN_MEMBERS_VOICE);
    await this.assertHierarchy(channel.serverId, actorId, targetUserId);

    const voiceState = await this.prisma.voiceState.findUnique({
      where: { userId_channelId: { userId: targetUserId, channelId } },
    });
    if (!voiceState) throw new NotFoundException('Kullanıcı bu sesli kanalda değil.');

    const updated = await this.prisma.voiceState.update({
      where: { id: voiceState.id },
      // Sağırlaştırılan bir kullanıcı zaten dinleyemediği için konuşması da anlamsızdır.
      data: { isDeafened: deafened, isMuted: deafened ? true : voiceState.isMuted },
      include: VOICE_STATE_INCLUDE,
    });
    this.notifyChannel(channelId, 'voice:force-deafened', { userId: targetUserId, isDeafened: deafened });
    return updated;
  }

  async moveMember(channelId: string, actorId: string, targetUserId: string, targetChannelId: string) {
    const channel = await this.loadVoiceChannel(channelId);
    await this.checkPermission(channel.serverId, actorId, ServerPermission.MOVE_MEMBERS_VOICE);
    await this.assertHierarchy(channel.serverId, actorId, targetUserId);

    const targetChannel = await this.loadVoiceChannel(targetChannelId);
    if (targetChannel.serverId !== channel.serverId) {
      throw new BadRequestException('Hedef kanal aynı sunucuda olmalıdır.');
    }

    const voiceState = await this.prisma.voiceState.findUnique({
      where: { userId_channelId: { userId: targetUserId, channelId } },
    });
    if (!voiceState) throw new NotFoundException('Kullanıcı bu sesli kanalda değil.');

    await this.prisma.voiceState.delete({ where: { id: voiceState.id } });
    await this.liveKitService.removeParticipant(this.liveKitService.roomNameForChannel(channelId), targetUserId);
    this.notifyChannel(channelId, 'voice:user-left', { userId: targetUserId, channelId });

    // Hedef kullanıcının istemcisi bu olayı kendi kişisel odasından (`user:<id>`)
    // dinleyerek yeni kanal için otomatik olarak `POST .../voice/join` çağırır
    // ve taze bir LiveKit token'ı alır.
    this.gateway.broadcast({ channelId: targetChannelId }, 'voice:moved-in', { userId: targetUserId });
    this.gateway.server?.to(`user:${targetUserId}`).emit('voice:you-were-moved', {
      fromChannelId: channelId,
      toChannelId: targetChannelId,
    });

    return { ok: true };
  }

  async disconnectMember(channelId: string, actorId: string, targetUserId: string) {
    const channel = await this.loadVoiceChannel(channelId);
    await this.checkPermission(channel.serverId, actorId, ServerPermission.MOVE_MEMBERS_VOICE);
    await this.assertHierarchy(channel.serverId, actorId, targetUserId);
    return this.leave(channelId, targetUserId);
  }
}
