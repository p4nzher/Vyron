import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { SystemAdminGuard } from './system-admin.guard';
import { PrismaService } from '../../modules/prisma/prisma.service';

// Faz 7.4 — `PrismaService` mock'lanır (gerçek DB gerekmez), bu yüzden
// diğer birim testleri gibi CI'da her zaman hızlı çalışır. Gerçek DB'ye
// karşı doğrulama isteyen davranış zaten `health.e2e-spec.ts` örüntüsüyle
// e2e katmanında yapılmalı — bu test SADECE guard'ın karar mantığını izole eder.
describe('SystemAdminGuard', () => {
  function buildContext(userId?: string): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ user: userId ? { userId } : undefined }),
      }),
    } as unknown as ExecutionContext;
  }

  it('userId yoksa (kimliksiz istek) ForbiddenException fırlatır', async () => {
    const prisma = { user: { findUnique: jest.fn() } };
    const guard = new SystemAdminGuard(prisma as unknown as PrismaService);

    await expect(guard.canActivate(buildContext(undefined))).rejects.toThrow(ForbiddenException);
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });

  it('kullanıcı isSystemAdmin=false ise ForbiddenException fırlatır', async () => {
    const prisma = {
      user: { findUnique: jest.fn().mockResolvedValue({ isSystemAdmin: false, isBanned: false }) },
    };
    const guard = new SystemAdminGuard(prisma as unknown as PrismaService);

    await expect(guard.canActivate(buildContext('user-1'))).rejects.toThrow(ForbiddenException);
  });

  it('kullanıcı isSystemAdmin=true ve yasaklı değilse true döner', async () => {
    const prisma = {
      user: { findUnique: jest.fn().mockResolvedValue({ isSystemAdmin: true, isBanned: false }) },
    };
    const guard = new SystemAdminGuard(prisma as unknown as PrismaService);

    await expect(guard.canActivate(buildContext('user-1'))).resolves.toBe(true);
  });

  it('kullanıcı admin OLSA BİLE yasaklıysa (isBanned) ForbiddenException fırlatır', async () => {
    const prisma = {
      user: { findUnique: jest.fn().mockResolvedValue({ isSystemAdmin: true, isBanned: true }) },
    };
    const guard = new SystemAdminGuard(prisma as unknown as PrismaService);

    await expect(guard.canActivate(buildContext('user-1'))).rejects.toThrow(ForbiddenException);
  });

  it('kullanıcı veritabanında bulunamazsa (silinmiş) ForbiddenException fırlatır', async () => {
    const prisma = { user: { findUnique: jest.fn().mockResolvedValue(null) } };
    const guard = new SystemAdminGuard(prisma as unknown as PrismaService);

    await expect(guard.canActivate(buildContext('deleted-user'))).rejects.toThrow(ForbiddenException);
  });
});
