import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface AuthenticatedUser {
  userId: string;
  email: string;
  username: string;
}

/**
 * Controller metotlarında @CurrentUser() ile JWT'den çözümlenmiş kullanıcı bilgisine
 * doğrudan erişim sağlar. request.user, JwtStrategy.validate() tarafından doldurulur.
 */
export const CurrentUser = createParamDecorator(
  (data: keyof AuthenticatedUser | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user: AuthenticatedUser = request.user;
    return data ? user?.[data] : user;
  },
);
