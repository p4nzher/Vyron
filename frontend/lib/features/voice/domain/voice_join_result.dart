import 'voice_participant.dart';

/// `POST /channels/:channelId/voice/join` yanıtı — LiveKit'e bağlanmak için
/// gereken her şeyi taşır (bkz. `voice.service.ts` — `join()`).
class VoiceJoinResult {
  const VoiceJoinResult({
    required this.token,
    required this.mediaUrl,
    required this.roomName,
    required this.voiceState,
  });

  /// Kısa ömürlü (6 saat), imzalı LiveKit erişim JWT'i.
  final String token;

  /// LiveKit medya sunucusunun WebSocket adresi (`wss://...`).
  final String mediaUrl;

  final String roomName;
  final VoiceParticipant voiceState;

  factory VoiceJoinResult.fromJson(Map<String, dynamic> json) {
    return VoiceJoinResult(
      token: json['token'] as String,
      mediaUrl: json['mediaUrl'] as String,
      roomName: json['roomName'] as String,
      voiceState: VoiceParticipant.fromJson(json['voiceState'] as Map<String, dynamic>),
    );
  }
}
