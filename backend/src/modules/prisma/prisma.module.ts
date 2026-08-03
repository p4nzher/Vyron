import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

/**
 * @Global() işaretlemesi sayesinde PrismaService, her modülde ayrıca
 * import edilmeden inject edilebilir. Bu, veritabanı erişiminin
 * uygulama genelinde tutarlı ve tek bir bağlantı havuzu üzerinden olmasını sağlar.
 */
@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
