import { SetMetadata } from '@nestjs/common';
import { ServerPermission } from '@/common/permissions/permissions.enum';

export const REQUIRED_PERMISSION_KEY = 'requiredPermission';

/**
 * @RequirePermission(ServerPermission.MANAGE_CHANNELS) ile işaretlenen bir
 * endpoint, ServerPermissionGuard tarafından route parametresindeki
 * `:serverId` üzerinden çağıranın gerçekten bu yetkiye sahip olup olmadığı
 * kontrol edilmeden çalıştırılmaz.
 */
export const RequirePermission = (permission: ServerPermission) =>
  SetMetadata(REQUIRED_PERMISSION_KEY, permission);
