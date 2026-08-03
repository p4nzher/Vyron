import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/voice_join_result.dart';
import '../domain/voice_participant.dart';

/// `POST/PATCH/GET/DELETE .../voice/*` uç noktalarını sarmalar (bkz.
/// `voice.controller.ts`). Gerçek medya bağlantısı BURADA kurulmaz — sadece
/// LiveKit erişim token'ı ve katılımcı/durum meta verisi taşınır (bkz.
/// `VoiceCallController` — gerçek `Room.connect` çağrısı orada yapılır).
class VoiceRepository {
  VoiceRepository(this._client);

  final ApiClient _client;

  Future<VoiceJoinResult> join(String channelId) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.voiceJoin(channelId)),
      (data) => VoiceJoinResult.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> leave(String channelId) {
    return _client.guard(() => _client.dio.post(ApiConstants.voiceLeave(channelId)), (_) => null);
  }

  Future<VoiceParticipant> updateState(
    String channelId, {
    bool? isMuted,
    bool? isDeafened,
    bool? isCameraOn,
    bool? isScreenSharing,
  }) {
    return _client.guard(
      () => _client.dio.patch(
        ApiConstants.voiceState(channelId),
        data: {
          if (isMuted != null) 'isMuted': isMuted,
          if (isDeafened != null) 'isDeafened': isDeafened,
          if (isCameraOn != null) 'isCameraOn': isCameraOn,
          if (isScreenSharing != null) 'isScreenSharing': isScreenSharing,
        },
      ),
      (data) => VoiceParticipant.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<VoiceParticipant>> listParticipants(String channelId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.voiceParticipants(channelId)),
      (data) => (data as List<dynamic>).map((e) => VoiceParticipant.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Aşağıdaki moderasyon eylemleri sunucu tarafında yetki (bkz.
  /// `MUTE_MEMBERS_VOICE`/`DEAFEN_MEMBERS_VOICE`/`MOVE_MEMBERS_VOICE`) ve
  /// rol hiyerarşisi ile korunur; istemci sadece isteği yapar, 403 durumunda
  /// çağıran taraf (bkz. `VoiceCallController`) hatayı sessizce yutar.
  Future<void> forceMute(String channelId, String userId, bool muted) {
    final path = ApiConstants.voiceMemberMute(channelId, userId);
    return _client.guard(() => muted ? _client.dio.post(path) : _client.dio.delete(path), (_) => null);
  }

  Future<void> forceDeafen(String channelId, String userId, bool deafened) {
    final path = ApiConstants.voiceMemberDeafen(channelId, userId);
    return _client.guard(() => deafened ? _client.dio.post(path) : _client.dio.delete(path), (_) => null);
  }

  Future<void> moveMember(String channelId, String userId, String targetChannelId) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.voiceMemberMove(channelId, userId), data: {'targetChannelId': targetChannelId}),
      (_) => null,
    );
  }

  Future<void> disconnectMember(String channelId, String userId) {
    return _client.guard(() => _client.dio.delete(ApiConstants.voiceMemberDisconnect(channelId, userId)), (_) => null);
  }
}
