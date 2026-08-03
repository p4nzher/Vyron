import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/**
 * `ServerPermissionGuard` çalıştıktan sonra request üzerine eklediği
 * `server` ve `serverMember` (rolleri dahil) bilgisini controller'a taşır.
 * SADECE `@UseGuards(ServerPermissionGuard)` uygulanan route'larda doludur.
 */
export const CurrentServerMember = createParamDecorator((_: unknown, ctx: ExecutionContext) => {
  const request = ctx.switchToHttp().getRequest();
  return {
    server: request.server,
    serverMember: request.serverMember,
  };
});
