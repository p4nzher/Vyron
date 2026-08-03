/// `DMParticipant.user` seçimiyle birebir eşleşen katılımcı modeli.
class DmParticipant {
  const DmParticipant({
    required this.id,
    required this.username,
    required this.discriminator,
    this.displayName,
    this.avatarUrl,
    this.status = 'OFFLINE',
  });

  final String id;
  final String username;
  final String discriminator;
  final String? displayName;
  final String? avatarUrl;
  final String status;

  String get name => displayName ?? username;
  String get tag => '$username#$discriminator';

  factory DmParticipant.fromJson(Map<String, dynamic> json) {
    return DmParticipant(
      id: json['id'] as String,
      username: json['username'] as String,
      discriminator: json['discriminator'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      status: json['status'] as String? ?? 'OFFLINE',
    );
  }
}

/// Son mesajın önizlemesi (bkz. `DmService.DM_CHANNEL_INCLUDE` — her kanal
/// için en fazla 1 mesaj döner). Mesajlaşmanın tamamı Faz 6.4'te gelecek;
/// burada sadece liste önizlemesi için kullanılıyor.
class DmLastMessagePreview {
  const DmLastMessagePreview({required this.content, required this.authorId, required this.createdAt});

  final String? content;
  final String authorId;
  final DateTime createdAt;

  factory DmLastMessagePreview.fromJson(Map<String, dynamic> json) {
    return DmLastMessagePreview(
      content: json['content'] as String?,
      authorId: json['authorId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// `GET /dm-channels` yanıtındaki her öge — birebir ya da grup DM kanalı.
class DmChannel {
  const DmChannel({
    required this.id,
    required this.isGroup,
    required this.participants,
    required this.createdAt,
    this.name,
    this.lastMessage,
  });

  final String id;
  final bool isGroup;
  final String? name;
  final List<DmParticipant> participants;
  final DmLastMessagePreview? lastMessage;
  final DateTime createdAt;

  /// Birebir DM'lerde "diğer kişi" — grup DM'lerde başlık için tüm
  /// katılımcı isimleri birleştirilir (bkz. [displayName]).
  DmParticipant? otherParticipant(String currentUserId) {
    try {
      return participants.firstWhere((p) => p.id != currentUserId);
    } catch (_) {
      return participants.isNotEmpty ? participants.first : null;
    }
  }

  String displayName(String currentUserId) {
    if (isGroup) {
      if (name != null && name!.isNotEmpty) return name!;
      final others = participants.where((p) => p.id != currentUserId).map((p) => p.name);
      return others.isEmpty ? 'Grup DM' : others.join(', ');
    }
    return otherParticipant(currentUserId)?.name ?? 'Bilinmeyen kullanıcı';
  }

  factory DmChannel.fromJson(Map<String, dynamic> json) {
    final participantsJson = json['participants'] as List<dynamic>? ?? [];
    final messagesJson = json['messages'] as List<dynamic>? ?? [];
    return DmChannel(
      id: json['id'] as String,
      isGroup: json['isGroup'] as bool? ?? false,
      name: json['name'] as String?,
      participants: participantsJson
          .map((p) => DmParticipant.fromJson((p as Map<String, dynamic>)['user'] as Map<String, dynamic>))
          .toList(),
      lastMessage: messagesJson.isNotEmpty
          ? DmLastMessagePreview.fromJson(messagesJson.first as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
