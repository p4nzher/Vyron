import { ForbiddenException, Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '@/modules/prisma/prisma.service';
import { REQUIRED_PERMISSION_KEY } from '@/common/decorators/require-permission.decorator';
import { ServerPermission } from '@/common/permissions/permissions.enum';
import { hasPermission } from '@/common/permissions/permissions.util';

/**
 * ServerPermissionGuard, `@RequirePermission()` ile işaretlenmiş endpoint'lerde:
 * 1) İsteği yapan kullanıcının route'daki `:serverId` sunucusuna üye olduğunu,
 * 2) Üyenin (veya sunucu sahibinin) istenen yetkiye sahip olduğunu doğrular.
 *
 * JwtAuthGuard'dan SONRA çalışır (global guard sıralamasına göre APP_GUARD
 * listesinde JwtAuthGuard önce tanımlıdır), bu yüzden `request.user` her
 * zaman doludur.
 */
@Injectable()
export class ServerPermissionGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredPermission = this.reflector.getAllAndOverride<ServerPermission | undefined>(
      REQUIRED_PERMISSION_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!requiredPermission) return true; // Dekoratör yoksa bu guard devre dışı

    const request = context.switchToHttp().getRequest();
    const userId: string | undefined = request.user?.userId;
    const serverId: string | undefined = request.params?.serverId;

    if (!userId || !serverId) {
      throw new ForbiddenException('Sunucu bağlamı çözümlenemedi.');
    }

    const server = await this.prisma.server.findUnique({ where: { id: serverId } });
    if (!server) throw new ForbiddenException('Sunucu bulunamadı.');

    const member = await this.prisma.serverMember.findUnique({
      where: { serverId_userId: { serverId, userId } },
      include: { roles: { include: { role: true } } },
    });
    if (!member) throw new ForbiddenException('Bu sunucunun üyesi değilsiniz.');

    const roles = member.roles.map((r) => r.role);
    const allowed = hasPermission(
      { isOwner: server.ownerId === userId, roles },
      requiredPermission,
    );
    if (!allowed) {
      throw new ForbiddenException(`Bu işlem için '${requiredPermission}' yetkisi gereklidir.`);
    }

    // Aşağı akışta (controller/service) tekrar sorgu yapmamak için context'e ekleniyor.
    request.serverMember = member;
    request.server = server;
    return true;
  }
}
