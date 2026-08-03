/// `GET /servers/:serverId/audit-log` yanıtındaki her öge
/// (bkz. `audit-log.service.ts` → `listForServer`).
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.userTag,
    this.targetType,
    this.targetId,
    this.metadata,
  });

  final String id;
  final String action;
  final DateTime createdAt;
  final String? userTag;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic>? metadata;

  static const Map<String, String> _labels = {
    'USER_LOGIN': 'Giriş yapıldı',
    'USER_LOGOUT': 'Çıkış yapıldı',
    'USER_UPDATE': 'Profil güncellendi',
    'SERVER_CREATE': 'Sunucu oluşturuldu',
    'SERVER_UPDATE': 'Sunucu güncellendi',
    'SERVER_DELETE': 'Sunucu silindi',
    'CHANNEL_CREATE': 'Kanal oluşturuldu',
    'CHANNEL_UPDATE': 'Kanal güncellendi',
    'CHANNEL_DELETE': 'Kanal silindi',
    'ROLE_CREATE': 'Rol oluşturuldu',
    'ROLE_UPDATE': 'Rol güncellendi',
    'ROLE_DELETE': 'Rol silindi',
    'MEMBER_BAN': 'Üye yasaklandı',
    'MEMBER_KICK': 'Üye atıldı',
    'MEMBER_TIMEOUT': 'Üye susturuldu',
    'MESSAGE_DELETE': 'Mesaj silindi',
    'INVITE_CREATE': 'Davet oluşturuldu',
    'INVITE_DELETE': 'Davet iptal edildi',
  };

  String get label => _labels[action] ?? action;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return AuditLogEntry(
      id: json['id'] as String,
      action: json['action'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      userTag: user != null ? '${user['username']}#${user['discriminator']}' : null,
      targetType: json['targetType'] as String?,
      targetId: json['targetId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
