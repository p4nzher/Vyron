/**
 * Vyron Sunucu Yetki Sistemi
 * ---------------------------------------------------------------------------
 * Discord'daki bitmask yaklaşımı yerine, Prisma şemasında `Role.permissions`
 * alanı bir JSON obje olarak tutulur: { "MANAGE_CHANNELS": true, ... }.
 * Bu, okunabilirliği artırır ve yeni yetki eklemeyi migration gerektirmeden
 * yapılabilir kılar (sadece bu enum'a eklemek yeterlidir).
 *
 * `ADMINISTRATOR` özel bir yetkidir: tüm diğer kontrolleri by-pass eder.
 * Sunucu sahibi (Server.ownerId) HER ZAMAN tüm yetkilere sahiptir; bu kural
 * kod içinde ayrıca kontrol edilir (bkz. permissions.util.ts).
 */
export enum ServerPermission {
  ADMINISTRATOR = 'ADMINISTRATOR',

  // Sunucu yönetimi
  MANAGE_SERVER = 'MANAGE_SERVER',
  MANAGE_CHANNELS = 'MANAGE_CHANNELS',
  MANAGE_ROLES = 'MANAGE_ROLES',
  MANAGE_EMOJIS = 'MANAGE_EMOJIS',
  VIEW_AUDIT_LOG = 'VIEW_AUDIT_LOG',

  // Üye yönetimi / moderasyon
  KICK_MEMBERS = 'KICK_MEMBERS',
  BAN_MEMBERS = 'BAN_MEMBERS',
  TIMEOUT_MEMBERS = 'TIMEOUT_MEMBERS',
  MANAGE_NICKNAMES = 'MANAGE_NICKNAMES',

  // Davetler
  CREATE_INVITE = 'CREATE_INVITE',
  MANAGE_INVITES = 'MANAGE_INVITES',

  // Metin kanalları
  SEND_MESSAGES = 'SEND_MESSAGES',
  MANAGE_MESSAGES = 'MANAGE_MESSAGES',
  ATTACH_FILES = 'ATTACH_FILES',
  ADD_REACTIONS = 'ADD_REACTIONS',
  MENTION_EVERYONE = 'MENTION_EVERYONE',

  // Sesli/görüntülü kanallar
  CONNECT_VOICE = 'CONNECT_VOICE',
  SPEAK_VOICE = 'SPEAK_VOICE',
  VIDEO_VOICE = 'VIDEO_VOICE',
  MUTE_MEMBERS_VOICE = 'MUTE_MEMBERS_VOICE',
  DEAFEN_MEMBERS_VOICE = 'DEAFEN_MEMBERS_VOICE',
  MOVE_MEMBERS_VOICE = 'MOVE_MEMBERS_VOICE',
  SCREEN_SHARE = 'SCREEN_SHARE',
}

/**
 * Yeni oluşturulan bir sunucuda varsayılan "@everyone" rolüne (herkes) atanan
 * temel yetki seti. Yönetimsel hiçbir yetki içermez.
 */
export const DEFAULT_EVERYONE_PERMISSIONS: Record<string, boolean> = {
  [ServerPermission.SEND_MESSAGES]: true,
  [ServerPermission.ADD_REACTIONS]: true,
  [ServerPermission.ATTACH_FILES]: true,
  [ServerPermission.CREATE_INVITE]: true,
  [ServerPermission.CONNECT_VOICE]: true,
  [ServerPermission.SPEAK_VOICE]: true,
  [ServerPermission.VIDEO_VOICE]: true,
  [ServerPermission.SCREEN_SHARE]: true,
};
