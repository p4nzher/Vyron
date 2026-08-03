import { ServerPermission } from './permissions.enum';

type RoleLike = { permissions: unknown; position: number };

/**
 * Bir üyenin sahip olduğu tüm rollerin yetkilerini birleştirir (OR mantığı):
 * herhangi bir rolde `true` olan yetki, üye için geçerlidir.
 */
export function mergePermissions(roles: RoleLike[]): Record<string, boolean> {
  const merged: Record<string, boolean> = {};
  for (const role of roles) {
    const perms = (role.permissions ?? {}) as Record<string, boolean>;
    for (const [key, value] of Object.entries(perms)) {
      if (value) merged[key] = true;
    }
  }
  return merged;
}

/**
 * Bir kullanıcının aranan yetkiye sahip olup olmadığını kontrol eder.
 *
 * Öncelik sırası:
 * 1) Sunucu sahibi (ownerId === userId) => her zaman true
 * 2) ADMINISTRATOR yetkisine sahip herhangi bir rol => her zaman true
 * 3) Aranan yetkinin birleşik rol setinde açıkça true olması
 */
export function hasPermission(
  params: { isOwner: boolean; roles: RoleLike[] },
  permission: ServerPermission,
): boolean {
  if (params.isOwner) return true;
  const merged = mergePermissions(params.roles);
  if (merged[ServerPermission.ADMINISTRATOR]) return true;
  return Boolean(merged[permission]);
}

/**
 * İki üyenin rol hiyerarşisini karşılaştırır (moderasyon işlemlerinde
 * "kendinden yüksek/eşit rütbeliyi susturamazsın" kuralı için kullanılır).
 * `position` değeri yüksek olan rol daha yetkilidir (Discord'daki gibi).
 */
export function getHighestPosition(roles: RoleLike[]): number {
  if (roles.length === 0) return 0;
  return Math.max(...roles.map((r) => r.position));
}
