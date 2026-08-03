import 'role.dart';

/// `backend/src/common/permissions/permissions.enum.ts` ile birebir aynı
/// anahtarlar. Migration gerektirmeden backend'e yeni yetki eklenebildiği
/// için bu liste kasıtlı olarak backend'deki enum'un bir kopyasıdır — tek
/// gerçek kaynak (source of truth) her zaman backend'dir, istemci sadece
/// hangi anahtarların var olduğunu ve nasıl gruplandığını bilir.
abstract final class ServerPermission {
  static const String administrator = 'ADMINISTRATOR';

  static const String manageServer = 'MANAGE_SERVER';
  static const String manageChannels = 'MANAGE_CHANNELS';
  static const String manageRoles = 'MANAGE_ROLES';
  static const String manageEmojis = 'MANAGE_EMOJIS';
  static const String viewAuditLog = 'VIEW_AUDIT_LOG';

  static const String kickMembers = 'KICK_MEMBERS';
  static const String banMembers = 'BAN_MEMBERS';
  static const String timeoutMembers = 'TIMEOUT_MEMBERS';
  static const String manageNicknames = 'MANAGE_NICKNAMES';

  static const String createInvite = 'CREATE_INVITE';
  static const String manageInvites = 'MANAGE_INVITES';

  static const String sendMessages = 'SEND_MESSAGES';
  static const String manageMessages = 'MANAGE_MESSAGES';
  static const String attachFiles = 'ATTACH_FILES';
  static const String addReactions = 'ADD_REACTIONS';
  static const String mentionEveryone = 'MENTION_EVERYONE';

  static const String connectVoice = 'CONNECT_VOICE';
  static const String speakVoice = 'SPEAK_VOICE';
  static const String videoVoice = 'VIDEO_VOICE';
  static const String muteMembersVoice = 'MUTE_MEMBERS_VOICE';
  static const String deafenMembersVoice = 'DEAFEN_MEMBERS_VOICE';
  static const String moveMembersVoice = 'MOVE_MEMBERS_VOICE';
  static const String screenShare = 'SCREEN_SHARE';
}

/// Rol editöründe yetkileri anlamlı gruplar altında göstermek için.
class ServerPermissionGroup {
  const ServerPermissionGroup(this.label, this.permissions);
  final String label;
  final List<String> permissions;
}

const List<ServerPermissionGroup> serverPermissionGroups = [
  ServerPermissionGroup('Genel', [ServerPermission.administrator]),
  ServerPermissionGroup('Sunucu Yönetimi', [
    ServerPermission.manageServer,
    ServerPermission.manageChannels,
    ServerPermission.manageRoles,
    ServerPermission.manageEmojis,
    ServerPermission.viewAuditLog,
  ]),
  ServerPermissionGroup('Üye Yönetimi', [
    ServerPermission.kickMembers,
    ServerPermission.banMembers,
    ServerPermission.timeoutMembers,
    ServerPermission.manageNicknames,
  ]),
  ServerPermissionGroup('Davetler', [
    ServerPermission.createInvite,
    ServerPermission.manageInvites,
  ]),
  ServerPermissionGroup('Metin Kanalları', [
    ServerPermission.sendMessages,
    ServerPermission.manageMessages,
    ServerPermission.attachFiles,
    ServerPermission.addReactions,
    ServerPermission.mentionEveryone,
  ]),
  ServerPermissionGroup('Sesli/Görüntülü Kanallar', [
    ServerPermission.connectVoice,
    ServerPermission.speakVoice,
    ServerPermission.videoVoice,
    ServerPermission.muteMembersVoice,
    ServerPermission.deafenMembersVoice,
    ServerPermission.moveMembersVoice,
    ServerPermission.screenShare,
  ]),
];

const Map<String, String> serverPermissionLabels = {
  ServerPermission.administrator: 'Yönetici (tüm kontrolleri atlar)',
  ServerPermission.manageServer: 'Sunucuyu Yönet',
  ServerPermission.manageChannels: 'Kanalları Yönet',
  ServerPermission.manageRoles: 'Rolleri Yönet',
  ServerPermission.manageEmojis: 'Emojileri Yönet',
  ServerPermission.viewAuditLog: 'Denetim Kaydını Görüntüle',
  ServerPermission.kickMembers: 'Üyeleri At',
  ServerPermission.banMembers: 'Üyeleri Yasakla',
  ServerPermission.timeoutMembers: 'Üyeleri Sustur',
  ServerPermission.manageNicknames: 'Takma Adları Yönet',
  ServerPermission.createInvite: 'Davet Oluştur',
  ServerPermission.manageInvites: 'Davetleri Yönet',
  ServerPermission.sendMessages: 'Mesaj Gönder',
  ServerPermission.manageMessages: 'Mesajları Yönet',
  ServerPermission.attachFiles: 'Dosya Ekle',
  ServerPermission.addReactions: 'Tepki Ekle',
  ServerPermission.mentionEveryone: '@everyone Etiketle',
  ServerPermission.connectVoice: 'Sesli Kanala Bağlan',
  ServerPermission.speakVoice: 'Konuş',
  ServerPermission.videoVoice: 'Kamera Aç',
  ServerPermission.muteMembersVoice: 'Üyeleri Sustur (Ses)',
  ServerPermission.deafenMembersVoice: 'Üyeleri Sağırlaştır',
  ServerPermission.moveMembersVoice: 'Üyeleri Taşı',
  ServerPermission.screenShare: 'Ekran Paylaş',
};

/// `permissions.util.ts`'nin istemci karşılığı: bir üyenin rollerini OR
/// mantığıyla birleştirir, sahiplik ve `ADMINISTRATOR` bypass'ını uygular.
/// UI'da düğme/menü gizleme için kullanılır — NİHAİ yetkilendirme HER ZAMAN
/// backend'de yapılır, bu sadece iyi bir kullanıcı deneyimi içindir.
class MemberPermissions {
  const MemberPermissions({required this.isOwner, required this.roles});

  final bool isOwner;
  final List<Role> roles;

  static Map<String, bool> merge(List<Role> roles) {
    final merged = <String, bool>{};
    for (final role in roles) {
      role.permissions.forEach((key, value) {
        if (value) merged[key] = true;
      });
    }
    return merged;
  }

  bool has(String permission) {
    if (isOwner) return true;
    final merged = merge(roles);
    if (merged[ServerPermission.administrator] == true) return true;
    return merged[permission] == true;
  }

  int get highestPosition {
    if (roles.isEmpty) return 0;
    return roles.map((r) => r.position).reduce((a, b) => a > b ? a : b);
  }

  static const empty = MemberPermissions(isOwner: false, roles: []);
}
