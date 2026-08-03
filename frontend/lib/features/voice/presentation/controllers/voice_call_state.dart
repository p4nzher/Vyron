import 'package:livekit_client/livekit_client.dart' show VideoTrack;

/// Bir sesli/görüntülü görüşmenin bağlantı yaşam döngüsü.
enum VoiceCallStatus { connecting, connected, reconnecting, failed }

/// Bir katılımcının arayüzde gösterilecek anlık görünümü. LiveKit `Room`/
/// `Participant` nesnelerinden TÜRETİLİR (bkz. `VoiceCallController`) —
/// bu yüzden `features/voice/domain` yerine burada (sunum katmanı) yaşar:
/// `VideoTrack` referansı doğrudan `livekit_client`'a bağımlıdır.
class VoiceCallParticipant {
  const VoiceCallParticipant({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.isLocal,
    required this.isMicOn,
    required this.isCameraOn,
    required this.isScreenSharing,
    required this.isSpeaking,
    this.isDeafened = false,
    this.cameraTrack,
    this.screenTrack,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final bool isLocal;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isScreenSharing;
  final bool isSpeaking;
  /// LiveKit'te doğal bir "sağırlaştırma" (deafen) kavramı YOKTUR — bu
  /// sadece bizim `VoiceState.isDeafened` alanımızdan (REST + `voice:*`
  /// socket olayları) gelir (bkz. `VoiceCallController._deafenedByUserId`).
  final bool isDeafened;
  final VideoTrack? cameraTrack;
  final VideoTrack? screenTrack;
}

class VoiceCallState {
  const VoiceCallState({
    required this.serverId,
    required this.channelId,
    required this.channelName,
    required this.status,
    this.participants = const [],
    this.isMicOn = true,
    this.isCameraOn = false,
    this.isScreenSharing = false,
    this.isDeafened = false,
    this.errorMessage,
  });

  final String serverId;
  final String channelId;
  final String channelName;
  final VoiceCallStatus status;
  final List<VoiceCallParticipant> participants;
  final bool isMicOn;
  final bool isCameraOn;
  final bool isScreenSharing;
  final bool isDeafened;
  final String? errorMessage;

  VoiceCallState copyWith({
    VoiceCallStatus? status,
    List<VoiceCallParticipant>? participants,
    bool? isMicOn,
    bool? isCameraOn,
    bool? isScreenSharing,
    bool? isDeafened,
    String? errorMessage,
  }) {
    return VoiceCallState(
      serverId: serverId,
      channelId: channelId,
      channelName: channelName,
      status: status ?? this.status,
      participants: participants ?? this.participants,
      isMicOn: isMicOn ?? this.isMicOn,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isDeafened: isDeafened ?? this.isDeafened,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
