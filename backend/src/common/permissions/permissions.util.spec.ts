import { getHighestPosition, hasPermission, mergePermissions } from './permissions.util';
import { ServerPermission } from './permissions.enum';

// Faz 7.2 — bu dosya, `flutter` istemcisindeki `MemberPermissions` (bkz.
// `frontend/lib/features/servers/domain/server_permissions.dart`) ile
// SENKRON olması gereken hiyerarşi/yetki mantığını doğrudan test eder. Bu
// fonksiyonlar hiçbir dış bağımlılığa (DB, Redis, HTTP) ihtiyaç duymadığı
// için CI'da her zaman hızlı ve deterministik çalışır.
describe('permissions.util', () => {
  describe('mergePermissions', () => {
    it('birden fazla roldeki yetkileri OR mantığıyla birleştirir', () => {
      const roles = [
        { position: 1, permissions: { [ServerPermission.KICK_MEMBERS]: true } },
        { position: 2, permissions: { [ServerPermission.BAN_MEMBERS]: true, [ServerPermission.KICK_MEMBERS]: false } },
      ];

      const merged = mergePermissions(roles);

      // KICK_MEMBERS ilk rolde true olduğu için, ikinci roldeki `false`
      // onu GERİ ALMAZ — OR mantığı budur.
      expect(merged[ServerPermission.KICK_MEMBERS]).toBe(true);
      expect(merged[ServerPermission.BAN_MEMBERS]).toBe(true);
      expect(merged[ServerPermission.MANAGE_ROLES]).toBeUndefined();
    });

    it('boş rol listesinde boş obje döner', () => {
      expect(mergePermissions([])).toEqual({});
    });

    it('permissions alanı olmayan/null bir rolü çökmeden atlar', () => {
      const roles = [{ position: 1, permissions: null }];
      expect(mergePermissions(roles as never)).toEqual({});
    });
  });

  describe('hasPermission', () => {
    it('sunucu sahibi her zaman true döner, roller boş olsa bile', () => {
      const result = hasPermission({ isOwner: true, roles: [] }, ServerPermission.BAN_MEMBERS);
      expect(result).toBe(true);
    });

    it('ADMINISTRATOR yetkisi olan bir rol, aranan yetki açıkça verilmemiş olsa bile true döner', () => {
      const roles = [{ position: 5, permissions: { [ServerPermission.ADMINISTRATOR]: true } }];
      const result = hasPermission({ isOwner: false, roles }, ServerPermission.MANAGE_CHANNELS);
      expect(result).toBe(true);
    });

    it('yetki açıkça verilmemişse false döner', () => {
      const roles = [{ position: 1, permissions: { [ServerPermission.SEND_MESSAGES]: true } }];
      const result = hasPermission({ isOwner: false, roles }, ServerPermission.BAN_MEMBERS);
      expect(result).toBe(false);
    });

    it('yetki açıkça verilmişse true döner', () => {
      const roles = [{ position: 1, permissions: { [ServerPermission.MANAGE_ROLES]: true } }];
      const result = hasPermission({ isOwner: false, roles }, ServerPermission.MANAGE_ROLES);
      expect(result).toBe(true);
    });
  });

  describe('getHighestPosition', () => {
    it('boş dizide 0 döner', () => {
      expect(getHighestPosition([])).toBe(0);
    });

    it('birden fazla roldeki en yüksek position değerini döner', () => {
      const roles = [{ position: 3, permissions: {} }, { position: 7, permissions: {} }, { position: 1, permissions: {} }];
      expect(getHighestPosition(roles)).toBe(7);
    });
  });
});
