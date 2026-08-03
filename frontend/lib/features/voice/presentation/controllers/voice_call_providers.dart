import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/voice_repository.dart';
import '../../domain/voice_participant.dart';
import 'voice_call_state.dart';

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) => VoiceRepository(ref.watch(apiClientProvider)));

/// Bir sesli/görüntülü görüşmenin TÜM yaşam döngüsünü yönetir: LiveKit
/// `Room` bağlantısı, mikrofon/kamera/ekran paylaşımı, "sağırlaştırma"
/// (deafen — LiveKit'te karşılığı olmayan, tamamen bizim uyguladığımız bir
/// davranış), ve moderasyon eylemleri (zorla sustur/at/taşı).
///
/// KASITLI OLARAK global/tekil bir provider'dır (Faz 6.4'teki
/// `messagesControllerProvider.autoDispose.family`'nin AKSİNE): Discord'da
/// olduğu gibi bir sesli kanala bağlıyken uygulamanın başka bir yerine
/// (başka bir metin kanalına, başka bir sunucuya) gidildiğinde görüşme
/// KOPMAMALIDIR. Bu yüzden `HomeShellScreen` her zaman bu state'i izleyip
/// bağlıyken kalıcı bir çubuk (`VoiceCallBar`) gösterir.
class VoiceCallController extends StateNotifier<VoiceCallState?> {
  VoiceCallController(this._ref) : super(null) {
    _subscribeGlobalSignals();
  }

  final Ref _ref;

  Room? _room;
  EventsListener<RoomEvent>? _roomEvents;
  final List<StreamSubscription<dynamic>> _globalSubs = [];

  /// Sunucudaki `VoiceState.isDeafened` — LiveKit'in kendisi bunu bilmez,
  /// sadece bizim `voice:state-updated`/`voice:force-deafened` olaylarımızla
  /// (ve katılım anındaki `listParticipants` anlık görüntüsüyle) beslenir.
  final Map<String, bool> _deafenedByUserId = {};

  /// LiveKit sadece `identity`/`name` taşır; avatar gibi zengin profil
  /// bilgisi REST (`listParticipants`) + `voice:user-joined` yükünden gelir.
  final Map<String, VoiceParticipant> _rosterByUserId = {};

  void _subscribeGlobalSignals() {
    final socket = _ref.read(socketServiceProvider);

    // Bir moderatör bizi BAŞKA bir sesli kanala taşıdığında — hangi ekranda
    // olursak olalım dinlenir (kişisel `user:<id>` odasına yayınlanır).
    _globalSubs.add(socket.onVoiceYouWereMoved.listen((payload) async {
      final toChannelId = payload['toChannelId'] as String?;
      final current = state;
      if (toChannelId == null || current == null) return;
      await joinChannel(serverId: current.serverId, channelId: toChannelId, channelName: current.channelName);
    }));

    _globalSubs.add(socket.onVoiceUserJoined.listen((payload) {
      final userId = payload['userId'] as String?;
      if (userId == null) return;
      try {
        _rosterByUserId[userId] = VoiceParticipant.fromJson(payload);
        _deafenedByUserId[userId] = payload['isDeafened'] as bool? ?? false;
      } catch (_) {
        // Beklenmeyen yük şekli — sessizce yok say, LiveKit zaten katılımcıyı gösterecek.
      }
      _recomputeParticipants();
    }));

    _globalSubs.add(socket.onVoiceUserLeft.listen((payload) {
      final userId = payload['userId'] as String?;
      if (userId == null) return;
      _rosterByUserId.remove(userId);
      _deafenedByUserId.remove(userId);
    }));

    _globalSubs.add(socket.onVoiceStateUpdated.listen(_onVoiceStateBroadcast));
    _globalSubs.add(socket.onVoiceForceDeafened.listen((payload) {
      final userId = payload['userId'] as String?;
      final isDeafened = payload['isDeafened'] as bool?;
      if (userId == null || isDeafened == null) return;
      _deafenedByUserId[userId] = isDeafened;
      _recomputeParticipants();
    }));
  }

  void _onVoiceStateBroadcast(Map<String, dynamic> payload) {
    final userId = payload['userId'] as String?;
    final isDeafened = payload['isDeafened'] as bool?;
    if (userId == null || isDeafened == null) return;
    _deafenedByUserId[userId] = isDeafened;
    _recomputeParticipants();
  }

  bool get isInCall => state != null;
  bool isInChannel(String channelId) => state?.channelId == channelId;

  // ---------------------------------------------------------------------
  // KATILMA / AYRILMA
  // ---------------------------------------------------------------------

  Future<void> joinChannel({required String serverId, required String channelId, required String channelName}) async {
    if (state != null && state!.channelId == channelId) return; // zaten bu kanaldayız
    if (state != null) {
      await leaveCall();
    }

    state = VoiceCallState(
      serverId: serverId,
      channelId: channelId,
      channelName: channelName,
      status: VoiceCallStatus.connecting,
    );

    try {
      final socket = _ref.read(socketServiceProvider);
      final repository = _ref.read(voiceRepositoryProvider);

      // `channel:<id>` odasına katıl — `voice:*` yayınları bu odadan gelir
      // (bkz. `messages.gateway.ts`/`voice.service.ts` — aynı oda adlandırması).
      await socket.joinChannel(channelId);

      // Kanaldaki mevcut katılımcıların profillerini (avatar vb.) önceden al.
      try {
        final roster = await repository.listParticipants(channelId);
        for (final p in roster) {
          _rosterByUserId[p.userId] = p;
          _deafenedByUserId[p.userId] = p.isDeafened;
        }
      } catch (_) {
        // Kritik değil — LiveKit yine de katılımcıları gösterecek.
      }

      final joinResult = await repository.join(channelId);

      final room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true));
      _room = room;
      room.addListener(_recomputeParticipants);

      _roomEvents = room.createListener()
        ..on<RoomDisconnectedEvent>((_) => _handleUnexpectedDisconnect())
        ..on<ParticipantConnectedEvent>((event) => _attachParticipantListener(event.participant))
        ..on<ParticipantDisconnectedEvent>((event) => event.participant.removeListener(_recomputeParticipants));

      await room.connect(joinResult.mediaUrl, joinResult.token);

      // Bağlanmadan önce zaten odada olan katılımcılar `ParticipantConnectedEvent`
      // TETİKLEMEZ — bu yüzden mevcut listeye elle dinleyici eklenir.
      for (final participant in room.remoteParticipants.values) {
        _attachParticipantListener(participant);
      }
      room.localParticipant?.addListener(_recomputeParticipants);

      await room.localParticipant?.setMicrophoneEnabled(true);

      state = state?.copyWith(status: VoiceCallStatus.connected, isMicOn: true);
      _recomputeParticipants();
    } catch (e) {
      state = state?.copyWith(status: VoiceCallStatus.failed, errorMessage: e.toString());
    }
  }

  void _attachParticipantListener(RemoteParticipant participant) {
    participant.addListener(_recomputeParticipants);
    // Zaten sağırlaştırılmış durumdaysak yeni katılan kişinin sesini de kes.
    if (state?.isDeafened == true) {
      _setParticipantAudioSubscribed(participant, false);
    }
  }

  void _handleUnexpectedDisconnect() {
    if (state == null) return;
    state = state!.copyWith(status: VoiceCallStatus.reconnecting);
  }

  Future<void> leaveCall() async {
    final current = state;
    if (current == null) return;

    try {
      await _ref.read(voiceRepositoryProvider).leave(current.channelId);
    } catch (_) {
      // Zaten ayrılmışızdır ya da ağ hatası — yerel temizliği yine de yap.
    }
    _ref.read(socketServiceProvider).leaveChannel(current.channelId);
    await _teardownRoom();
    _rosterByUserId.clear();
    _deafenedByUserId.clear();
    state = null;
  }

  Future<void> _teardownRoom() async {
    final room = _room;
    _room = null;
    _roomEvents = null;
    if (room != null) {
      room.removeListener(_recomputeParticipants);
      room.localParticipant?.removeListener(_recomputeParticipants);
      for (final participant in room.remoteParticipants.values) {
        participant.removeListener(_recomputeParticipants);
      }
      await room.disconnect();
    }
  }

  // ---------------------------------------------------------------------
  // KENDİ MEDYA DURUMUNU DEĞİŞTİRME
  // ---------------------------------------------------------------------

  Future<void> toggleMic() async {
    final current = state;
    if (current == null || _room == null) return;
    final next = !current.isMicOn;
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(next);
      state = current.copyWith(isMicOn: next, isDeafened: next ? false : current.isDeafened);
      if (next && current.isDeafened) {
        _setAllRemoteAudioSubscribed(true);
      }
      _recomputeParticipants();
      unawaited(_ref.read(voiceRepositoryProvider).updateState(
            current.channelId,
            isMuted: !next,
            isDeafened: next ? false : null,
          ));
    } catch (e) {
      state = state?.copyWith(errorMessage: 'Mikrofon değiştirilemedi: $e');
    }
  }

  Future<void> toggleCamera() async {
    final current = state;
    if (current == null || _room == null) return;
    final next = !current.isCameraOn;
    try {
      await _room!.localParticipant?.setCameraEnabled(next);
      state = current.copyWith(isCameraOn: next);
      _recomputeParticipants();
      unawaited(_ref.read(voiceRepositoryProvider).updateState(current.channelId, isCameraOn: next));
    } catch (e) {
      state = state?.copyWith(errorMessage: 'Kamera açılamadı: $e');
    }
  }

  Future<void> toggleScreenShare() async {
    final current = state;
    if (current == null || _room == null) return;
    final next = !current.isScreenSharing;
    try {
      await _room!.localParticipant?.setScreenShareEnabled(next);
      state = current.copyWith(isScreenSharing: next);
      _recomputeParticipants();
      unawaited(_ref.read(voiceRepositoryProvider).updateState(current.channelId, isScreenSharing: next));
    } catch (e) {
      state = state?.copyWith(errorMessage: 'Ekran paylaşımı başlatılamadı: $e');
    }
  }

  Future<void> toggleDeafen() async {
    final current = state;
    if (current == null) return;
    final next = !current.isDeafened;

    _setAllRemoteAudioSubscribed(!next);
    if (next && (_room?.localParticipant?.isMicrophoneEnabled() ?? false)) {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
    }
    state = current.copyWith(isDeafened: next, isMicOn: next ? false : current.isMicOn);
    _recomputeParticipants();
    unawaited(_ref.read(voiceRepositoryProvider).updateState(
          current.channelId,
          isDeafened: next,
          isMuted: next ? true : null,
        ));
  }

  void _setAllRemoteAudioSubscribed(bool subscribed) {
    final room = _room;
    if (room == null) return;
    for (final participant in room.remoteParticipants.values) {
      _setParticipantAudioSubscribed(participant, subscribed);
    }
  }

  void _setParticipantAudioSubscribed(RemoteParticipant participant, bool subscribed) {
    for (final pub in participant.audioTrackPublications) {
      if (pub is RemoteTrackPublication) {
        if (subscribed) {
          pub.subscribe();
        } else {
          pub.unsubscribe();
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // MODERASYON (bkz. `voice.controller.ts` — yetki/hiyerarşi sunucuda kontrol edilir)
  // ---------------------------------------------------------------------

  Future<void> forceMuteMember(String userId, bool muted) async {
    final current = state;
    if (current == null) return;
    try {
      await _ref.read(voiceRepositoryProvider).forceMute(current.channelId, userId, muted);
    } catch (_) {
      // Yetki hatası vb. — sessizce yok say (UI zaten bu düğmeyi göstermemeli).
    }
  }

  Future<void> forceDeafenMember(String userId, bool deafened) async {
    final current = state;
    if (current == null) return;
    try {
      await _ref.read(voiceRepositoryProvider).forceDeafen(current.channelId, userId, deafened);
    } catch (_) {}
  }

  Future<void> disconnectMember(String userId) async {
    final current = state;
    if (current == null) return;
    try {
      await _ref.read(voiceRepositoryProvider).disconnectMember(current.channelId, userId);
    } catch (_) {}
  }

  // ---------------------------------------------------------------------
  // KATILIMCI LİSTESİNİ TÜRETME
  // ---------------------------------------------------------------------

  void _recomputeParticipants() {
    final room = _room;
    final current = state;
    if (room == null || current == null) return;

    final list = <VoiceCallParticipant>[];
    final local = room.localParticipant;
    if (local != null) {
      list.add(VoiceCallParticipant(
        userId: local.identity,
        name: _displayNameFor(local.identity, fallback: local.name),
        avatarUrl: _rosterByUserId[local.identity]?.avatarUrl,
        isLocal: true,
        isMicOn: local.isMicrophoneEnabled(),
        isCameraOn: local.isCameraEnabled(),
        isScreenSharing: local.isScreenShareEnabled(),
        isSpeaking: local.isSpeaking,
        isDeafened: current.isDeafened,
        cameraTrack: _videoTrackFor(local, TrackSource.camera),
        screenTrack: _videoTrackFor(local, TrackSource.screenShareVideo),
      ));
    }

    for (final participant in room.remoteParticipants.values) {
      list.add(VoiceCallParticipant(
        userId: participant.identity,
        name: _displayNameFor(participant.identity, fallback: participant.name),
        avatarUrl: _rosterByUserId[participant.identity]?.avatarUrl,
        isLocal: false,
        isMicOn: participant.isMicrophoneEnabled(),
        isCameraOn: participant.isCameraEnabled(),
        isScreenSharing: participant.isScreenShareEnabled(),
        isSpeaking: participant.isSpeaking,
        isDeafened: _deafenedByUserId[participant.identity] ?? false,
        cameraTrack: _videoTrackFor(participant, TrackSource.camera),
        screenTrack: _videoTrackFor(participant, TrackSource.screenShareVideo),
      ));
    }

    state = current.copyWith(participants: list);
  }

  String _displayNameFor(String userId, {required String fallback}) {
    final roster = _rosterByUserId[userId];
    if (roster != null) return roster.name;
    return fallback.isNotEmpty ? fallback : userId;
  }

  VideoTrack? _videoTrackFor(Participant participant, TrackSource source) {
    final publication = participant.getTrackPublicationBySource(source);
    final track = publication?.track;
    return track is VideoTrack ? track : null;
  }

  @override
  void dispose() {
    for (final sub in _globalSubs) {
      sub.cancel();
    }
    unawaited(_teardownRoom());
    super.dispose();
  }
}

final voiceCallControllerProvider = StateNotifierProvider<VoiceCallController, VoiceCallState?>((ref) {
  return VoiceCallController(ref);
});
