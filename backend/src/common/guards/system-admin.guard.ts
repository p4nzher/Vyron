import { CanActivate, ExecutionContext, ForbiddenException, Injectable } from '@nestjs/common';
import { Request } from 'express';
import { PrismaService } from '@/modules/prisma/prisma.service';

/**
 * Faz 7.4 — platform-genel (`/admin/**`) uç noktalarını sadece
 * `User.isSystemAdmin = true` olan kullanıcılara açar.
 *
 * BİLİNÇLİ TASARIM KARARI: yetki, JWT payload'ından DEĞİL her istekte
 * VERİTABANINDAN taze okunur (bkz. `JwtAccessStrategy` — payload sadece
 * `userId`/`email`/`username` taşır, `isSystemAdmin` taşımaz). Bu, bir admin
 * yetkisi geri alındığında (`isSystemAdmin: false` yapıldığında) DEĞİŞİKLİĞİN
 * o kullanıcının access token'ı süresi dolana kadar (15 dk) beklemeden ANINDA
 * etkili olmasını sağlar — ayrıcalıklı bir yetki için bu gecikme kabul
 * edilemez bir güvenlik riski olurdu. Ekstra bir DB sorgusu maliyeti
 * (`/admin/**` uç noktaları düşük trafiklidir) buna değer.
 *
 * `JwtAuthGuard`'dan SONRA çalışır (global guard sırası), bu yüzden
 * `request.user` her zaman doludur.
 */
@Injectable()
export class SystemAdminGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request & { user?: { userId: string } }>();
    const userId = request.user?.userId;
    if (!userId) throw new ForbiddenException('Bu işlem için yönetici yetkisi gerekir.');

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { isSystemAdmin: true, isBanned: true },
    });

    if (!user || !user.isSystemAdmin || user.isBanned) {
      throw new ForbiddenException('Bu işlem için yönetici yetkisi gerekir.');
    }

    return true;
  }
}
