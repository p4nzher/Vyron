import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@/modules/prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async findById(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        username: true,
        discriminator: true,
        email: true,
        displayName: true,
        avatarUrl: true,
        bannerUrl: true,
        bio: true,
        status: true,
        customStatusText: true,
        twoFactorEnabled: true,
        createdAt: true,
      },
    });
    if (!user) throw new NotFoundException('Kullanıcı bulunamadı.');
    return user;
  }

  async updateProfile(
    userId: string,
    data: { displayName?: string; bio?: string; avatarUrl?: string; bannerUrl?: string },
  ) {
    return this.prisma.user.update({
      where: { id: userId },
      data,
      select: {
        id: true,
        username: true,
        discriminator: true,
        displayName: true,
        avatarUrl: true,
        bannerUrl: true,
        bio: true,
      },
    });
  }

  async updateStatus(userId: string, status: 'ONLINE' | 'IDLE' | 'DND' | 'INVISIBLE') {
    return this.prisma.user.update({
      where: { id: userId },
      data: { status },
      select: { id: true, status: true },
    });
  }

  /** Kullanıcı adı#discriminator veya kısmi kullanıcı adına göre arama (arkadaş ekleme için). */
  async search(query: string, excludeUserId: string) {
    return this.prisma.user.findMany({
      where: {
        AND: [
          { id: { not: excludeUserId } },
          {
            OR: [
              { username: { contains: query, mode: 'insensitive' } },
              { displayName: { contains: query, mode: 'insensitive' } },
            ],
          },
        ],
      },
      select: {
        id: true,
        username: true,
        discriminator: true,
        displayName: true,
        avatarUrl: true,
        status: true,
      },
      take: 20,
    });
  }
}
