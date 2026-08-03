import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/**
 * @Public() dekoratörü ile işaretlenen endpoint'ler global JwtAuthGuard'dan muaf tutulur.
 * Örn: /auth/login, /auth/register gibi kimlik doğrulama gerektirmeyen uçlar için kullanılır.
 */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
