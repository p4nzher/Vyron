import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '@/modules/prisma/prisma.service';

@Injectable()
export class FriendsService {
  constructor(private readonly prisma: PrismaService) {}

  // ---------------------------------------------------------------------
  // ARKADAŞLIK İSTEĞİ GÖNDERME
  // ---------------------------------------------------------------------
  async sendRequest(requesterId: string, usernameTag: string) {
    const [username, discriminator] = usernameTag.split('#');
    const addressee = await this.prisma.user.findUnique({
      where: { username_discriminator: { username, discriminator } },
    });

    if (!addressee) {
      throw new NotFoundException('Bu kullanıcı etiketiyle eşleşen bir hesap bulunamadı.');
    }
    if (addressee.id === requesterId) {
      throw new BadRequestException('Kendine arkadaşlık isteği gönderemezsin.');
    }

    // İki yönlü engel kontrolü: taraflardan biri diğerini engellemişse istek gönderilemez.
    const blocked = await this.prisma.block.findFirst({
      where: {
        OR: [
          { blockerId: requesterId, blockedId: addressee.id },
          { blockerId: addressee.id, blockedId: requesterId },
        ],
      },
    });
    if (blocked) {
      throw new ForbiddenException('Bu kullanıcıyla arkadaşlık isteği gönderilemiyor.');
    }

    // Zaten var olan bir ilişki var mı (herhangi bir yönde)?
    const existing = await this.prisma.friendship.findFirst({
      where: {
        OR: [
          { requesterId, addresseeId: addressee.id },
          { requesterId: addressee.id, addresseeId: requesterId },
        ],
      },
    });

    if (existing) {
      if (existing.status === 'ACCEPTED') {
        throw new ConflictException('Bu kullanıcı zaten arkadaş listende.');
      }
      if (existing.status === 'PENDING') {
        // Karşı taraf zaten bize istek göndermişse, tekrar istek göndermek yerine otomatik kabul ediyoruz.
        if (existing.requesterId === addressee.id) {
          return this.prisma.friendship.update({
            where: { id: existing.id },
            data: { status: 'ACCEPTED' },
          });
        }
        throw new ConflictException('Zaten bekleyen bir arkadaşlık isteği var.');
      }
    }

    return this.prisma.friendship.create({
      data: { requesterId, addresseeId: addressee.id, status: 'PENDING' },
    });
  }

  // ---------------------------------------------------------------------
  // İSTEĞİ YANITLAMA (kabul / reddet)
  // ---------------------------------------------------------------------
  async acceptRequest(userId: string, friendshipId: string) {
    const friendship = await this.getPendingIncomingOrThrow(userId, friendshipId);
    return this.prisma.friendship.update({
      where: { id: friendship.id },
      data: { status: 'ACCEPTED' },
    });
  }

  async rejectRequest(userId: string, friendshipId: string) {
    const friendship = await this.getPendingIncomingOrThrow(userId, friendshipId);
    await this.prisma.friendship.delete({ where: { id: friendship.id } });
    return { message: 'Arkadaşlık isteği reddedildi.' };
  }

  async cancelRequest(userId: string, friendshipId: string) {
    const friendship = await this.prisma.friendship.findUnique({ where: { id: friendshipId } });
    if (!friendship || friendship.requesterId !== userId || friendship.status !== 'PENDING') {
      throw new NotFoundException('İptal edilecek bekleyen bir istek bulunamadı.');
    }
    await this.prisma.friendship.delete({ where: { id: friendship.id } });
    return { message: 'Gönderilen istek iptal edildi.' };
  }

  private async getPendingIncomingOrThrow(userId: string, friendshipId: string) {
    const friendship = await this.prisma.friendship.findUnique({ where: { id: friendshipId } });
    if (!friendship || friendship.addresseeId !== userId || friendship.status !== 'PENDING') {
      throw new NotFoundException('Yanıtlanacak bekleyen bir istek bulunamadı.');
    }
    return friendship;
  }

  // ---------------------------------------------------------------------
  // ARKADAŞLIKTAN ÇIKARMA
  // ---------------------------------------------------------------------
  async removeFriend(userId: string, otherUserId: string) {
    const friendship = await this.prisma.friendship.findFirst({
      where: {
        status: 'ACCEPTED',
        OR: [
          { requesterId: userId, addresseeId: otherUserId },
          { requesterId: otherUserId, addresseeId: userId },
        ],
      },
    });
    if (!friendship) {
      throw new NotFoundException('Bu kullanıcı arkadaş listende değil.');
    }
    await this.prisma.friendship.delete({ where: { id: friendship.id } });
    return { message: 'Arkadaşlıktan çıkarıldı.' };
  }

  // ---------------------------------------------------------------------
  // LİSTELEME
  // ---------------------------------------------------------------------
  async listFriends(userId: string) {
    const friendships = await this.prisma.friendship.findMany({
      where: { status: 'ACCEPTED', OR: [{ requesterId: userId }, { addresseeId: userId }] },
      include: {
        requester: { select: this.publicUserSelect },
        addressee: { select: this.publicUserSelect },
      },
    });
    // Her kayıttan "karşı taraf" olan kullanıcıyı çıkarıp düz bir liste döneriz.
    return friendships.map((f) => (f.requesterId === userId ? f.addressee : f.requester));
  }

  async listIncomingRequests(userId: string) {
    return this.prisma.friendship.findMany({
      where: { addresseeId: userId, status: 'PENDING' },
      include: { requester: { select: this.publicUserSelect } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async listOutgoingRequests(userId: string) {
    return this.prisma.friendship.findMany({
      where: { requesterId: userId, status: 'PENDING' },
      include: { addressee: { select: this.publicUserSelect } },
      orderBy: { createdAt: 'desc' },
    });
  }

  // ---------------------------------------------------------------------
  // ENGELLEME
  // ---------------------------------------------------------------------
  async blockUser(blockerId: string, blockedId: string) {
    if (blockerId === blockedId) {
      throw new BadRequestException('Kendini engelleyemezsin.');
    }
    // Engellenince mevcut arkadaşlık ilişkisi (varsa) otomatik silinir.
    await this.prisma.friendship.deleteMany({
      where: {
        OR: [
          { requesterId: blockerId, addresseeId: blockedId },
          { requesterId: blockedId, addresseeId: blockerId },
        ],
      },
    });
    return this.prisma.block.upsert({
      where: { blockerId_blockedId: { blockerId, blockedId } },
      create: { blockerId, blockedId },
      update: {},
    });
  }

  async unblockUser(blockerId: string, blockedId: string) {
    await this.prisma.block.deleteMany({ where: { blockerId, blockedId } });
    return { message: 'Engel kaldırıldı.' };
  }

  async listBlocked(blockerId: string) {
    const blocks = await this.prisma.block.findMany({
      where: { blockerId },
      include: { blocked: { select: this.publicUserSelect } },
    });
    return blocks.map((b) => b.blocked);
  }

  private readonly publicUserSelect = {
    id: true,
    username: true,
    discriminator: true,
    displayName: true,
    avatarUrl: true,
    status: true,
  } as const;
}
