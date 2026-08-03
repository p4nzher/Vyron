/// Backend `Invite` modeli ile birebir eşleşir (bkz. `invites.controller.ts`).
class Invite {
  const Invite({
    required this.id,
    required this.code,
    required this.serverId,
    required this.createdAt,
    this.createdByTag,
    this.maxUses,
    this.useCount = 0,
    this.expiresAt,
  });

  final String id;
  final String code;
  final String serverId;
  final DateTime createdAt;
  final String? createdByTag;
  final int? maxUses;
  final int useCount;
  final DateTime? expiresAt;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isExhausted => maxUses != null && useCount >= maxUses!;
  bool get isActive => !isExpired && !isExhausted;

  factory Invite.fromJson(Map<String, dynamic> json) {
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    return Invite(
      id: json['id'] as String,
      code: json['code'] as String,
      serverId: json['serverId'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      createdByTag: createdBy != null ? '${createdBy['username']}#${createdBy['discriminator']}' : null,
      maxUses: json['maxUses'] as int?,
      useCount: json['useCount'] as int? ?? 0,
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt'] as String) : null,
    );
  }
}

/// `GET /invites/:code` önizleme yanıtı (katılmadan önce gösterilir).
class InvitePreview {
  const InvitePreview({required this.serverName, required this.memberCount, this.serverIconUrl});

  final String serverName;
  final String? serverIconUrl;
  final int memberCount;

  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    final server = json['server'] as Map<String, dynamic>;
    final count = server['_count'] as Map<String, dynamic>?;
    return InvitePreview(
      serverName: server['name'] as String,
      serverIconUrl: server['iconUrl'] as String?,
      memberCount: count != null ? (count['members'] as int? ?? 0) : 0,
    );
  }
}
