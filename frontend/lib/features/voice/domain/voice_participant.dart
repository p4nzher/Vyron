/// Backend `VoiceState` + gömülü `user` seçimiyle (bkz. `voice.service.ts`
/// `VOICE_STATE_INCLUDE`) birebir eşleşir. Bu model VERİTABANI durumunu
/// (kim bağlı, kim susturulmuş vb.) temsil eder — gerçek medya akışı
/// (video/ses track'leri) `VoiceCallController` içinde doğrudan LiveKit
/// `Room`/`Participant` nesnelerinden okunur ve bu modelle BİRLİKTE
/// gösterilir (bkz. `voice_call_providers.dart` — `mergedParticipants`).
class VoiceParticipant {
  const VoiceParticipant({
    required this.userId,
    required this.channelId,
    required this.username,
    required this.discriminator,
    this.displayName,
    this.avatarUrl,
    required this.isMuted,
    required this.isDeafened,
    required this.isCameraOn,
    required this.isScreenSharing,
    required this.joinedAt,
  });

  final String userId;
  final String channelId;
  final String username;
  final String discriminator;
  final String? displayName;
  final String? avatarUrl;
  final bool isMuted;
  final bool isDeafened;
  final bool isCameraOn;
  final bool isScreenSharing;
  final DateTime joinedAt;

  String get name => displayName ?? username;

  VoiceParticipant copyWith({
    bool? isMuted,
    bool? isDeafened,
    bool? isCameraOn,
    bool? isScreenSharing,
  }) {
    return VoiceParticipant(
      userId: userId,
      channelId: channelId,
      username: username,
      discriminator: discriminator,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isMuted: isMuted ?? this.isMuted,
      isDeafened: isDeafened ?? this.isDeafened,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      joinedAt: joinedAt,
    );
  }

  factory VoiceParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return VoiceParticipant(
      userId: json['userId'] as String,
      channelId: json['channelId'] as String,
      username: user['username'] as String? ?? '',
      discriminator: user['discriminator'] as String? ?? '0000',
      displayName: user['displayName'] as String?,
      avatarUrl: user['avatarUrl'] as String?,
      isMuted: json['isMuted'] as bool? ?? false,
      isDeafened: json['isDeafened'] as bool? ?? false,
      isCameraOn: json['isCameraOn'] as bool? ?? false,
      isScreenSharing: json['isScreenSharing'] as bool? ?? false,
      joinedAt: DateTime.parse(json['joinedAt'] as String).toLocal(),
    );
  }
}
