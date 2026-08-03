/// Backend `ModerationAction` modeli — bir üyenin uyarı/timeout/kick/ban
/// geçmişini oluşturur (bkz. `moderation.service.ts` → `logAction`).
class ModerationAction {
  const ModerationAction({
    required this.id,
    required this.actionType,
    required this.createdAt,
    this.reason,
    this.durationSeconds,
    this.actorTag,
  });

  final String id;
  final String actionType; // 'KICK' | 'BAN' | 'UNBAN' | 'TIMEOUT' | 'WARN'
  final DateTime createdAt;
  final String? reason;
  final int? durationSeconds;
  final String? actorTag;

  String get label {
    switch (actionType) {
      case 'KICK':
        return 'Atıldı';
      case 'BAN':
        return 'Yasaklandı';
      case 'UNBAN':
        return 'Yasak Kaldırıldı';
      case 'TIMEOUT':
        return 'Susturuldu';
      case 'WARN':
        return 'Uyarıldı';
      default:
        return actionType;
    }
  }

  factory ModerationAction.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    return ModerationAction(
      id: json['id'] as String,
      actionType: json['actionType'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      actorTag: actor != null ? '${actor['username']}#${actor['discriminator']}' : null,
    );
  }
}
