import { Injectable } from '@nestjs/common';
import { AuditLogAction, Prisma } from '@prisma/client';
import { PrismaService } from '@/modules/prisma/prisma.service';

/**
 * AuditLogService, sunucu yöneticilerinin "kim, ne zaman, ne yaptı" sorusunu
 * cevaplayabilmesi için tüm kritik yönetimsel aksiyonları (kanal/rol
 * oluşturma-silme, üye atma/yasaklama, davet oluşturma vb.) kalıcı olarak
 * `audit_logs` tablosuna yazar. Bu servis fire-and-forget mantığıyla
 * çağrılır: bir log kaydı başarısız olsa dahi ana işlem geri alınmaz.
 */
@Injectable()
export class AuditLogService {
  constructor(private readonly prisma: PrismaService) {}

  async record(params: {
    serverId?: string;
    userId: string;
    action: AuditLogAction;
    targetType?: string;
    targetId?: string;
    metadata?: Prisma.InputJsonValue;
    ipAddress?: string;
  }): Promise<void> {
    await this.prisma.auditLog.create({
      data: {
        serverId: params.serverId,
        userId: params.userId,
        action: params.action,
        targetType: params.targetType,
        targetId: params.targetId,
        metadata: params.metadata,
        ipAddress: params.ipAddress,
      },
    });
  }

  async listForServer(serverId: string, take = 100) {
    return this.prisma.auditLog.findMany({
      where: { serverId },
      orderBy: { createdAt: 'desc' },
      take,
      include: {
        user: { select: { id: true, username: true, discriminator: true, avatarUrl: true } },
      },
    });
  }
}
