import { PrismaClient, ChannelType } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

/**
 * Geliştirme ortamında hızlı test için örnek veri oluşturur:
 * 1 sistem yöneticisi, 2 normal kullanıcı, aralarında arkadaşlık ve
 * varsayılan kanallara sahip bir örnek sunucu.
 *
 * Çalıştırma: npm run seed
 */
async function main(): Promise<void> {
  const passwordHash = await argon2.hash('GucluSifre!123');

  const admin = await prisma.user.upsert({
    where: { email: 'admin@vyron.dev' },
    update: {},
    create: {
      username: 'vyron_admin',
      discriminator: '0001',
      email: 'admin@vyron.dev',
      passwordHash,
      isEmailVerified: true,
      isSystemAdmin: true,
    },
  });

  const enes = await prisma.user.upsert({
    where: { email: 'enes@vyron.dev' },
    update: {},
    create: {
      username: 'enes',
      discriminator: '0001',
      email: 'enes@vyron.dev',
      passwordHash,
      isEmailVerified: true,
    },
  });

  const irem = await prisma.user.upsert({
    where: { email: 'irem@vyron.dev' },
    update: {},
    create: {
      username: 'irem',
      discriminator: '0001',
      email: 'irem@vyron.dev',
      passwordHash,
      isEmailVerified: true,
    },
  });

  await prisma.friendship.upsert({
    where: { requesterId_addresseeId: { requesterId: enes.id, addresseeId: irem.id } },
    update: {},
    create: { requesterId: enes.id, addresseeId: irem.id, status: 'ACCEPTED' },
  });

  const existingServer = await prisma.server.findFirst({ where: { name: 'Vyron Test Sunucusu' } });
  if (!existingServer) {
    const server = await prisma.server.create({
      data: { name: 'Vyron Test Sunucusu', ownerId: enes.id, isPublic: true },
    });

    const everyoneRole = await prisma.role.create({
      data: { serverId: server.id, name: '@everyone', position: 0 },
    });

    const enesMember = await prisma.serverMember.create({
      data: { serverId: server.id, userId: enes.id },
    });
    await prisma.memberRole.create({ data: { serverMemberId: enesMember.id, roleId: everyoneRole.id } });

    const iremMember = await prisma.serverMember.create({
      data: { serverId: server.id, userId: irem.id },
    });
    await prisma.memberRole.create({ data: { serverMemberId: iremMember.id, roleId: everyoneRole.id } });

    await prisma.channel.create({
      data: { serverId: server.id, name: 'genel', type: ChannelType.TEXT, position: 0 },
    });
    await prisma.channel.create({
      data: { serverId: server.id, name: 'Genel', type: ChannelType.VOICE, position: 1 },
    });
  }

  // eslint-disable-next-line no-console
  console.log('✅ Seed tamamlandı:', { admin: admin.email, enes: enes.email, irem: irem.email });
}

main()
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error('❌ Seed başarısız:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
