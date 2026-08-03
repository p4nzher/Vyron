import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

/// Backend `MessagesGateway` (`/realtime` ad alanı) ile tek bir kalıcı
/// bağlantıyı yönetir. Mimari karar (bkz. `messages.gateway.ts` yorumu):
/// mesaj OLUŞTURMA/DÜZENLEME/SİLME REST üzerinden yapılır, bu servis SADECE
/// gerçek-zamanlı YAYINLARI (message:*, reaction:*, typing:*, presence:*)
/// dinler ve oda (room) katılım sinyallerini gönderir.
///
/// Tekil (singleton) olarak `GetIt` üzerinden kaydedilir (bkz.
/// `core/di/service_locator.dart`) ve tüm özellik katmanları bunu Riverpod
/// `socketServiceProvider` üzerinden tüketir — tıpkı `ApiClient` gibi.
class SocketService {
  SocketService({required this.storage});

  final SecureStorageService storage;

  io.Socket? _socket;
  bool _connecting = false;

  final _messageCreated = StreamController<Map<String, dynamic>>.broadcast();
  final _messageUpdated = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeleted = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionAdded = StreamController<Map<String, dynamic>>.broadcast();
  final _reactionRemoved = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStart = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStop = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceUpdate = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionState = StreamController<bool>.broadcast();

  // --- Faz 6.5: sesli/görüntülü görüşme sinyalleri (bkz. `voice.service.ts`) ---
  final _voiceUserJoined = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceUserLeft = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceStateUpdated = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceForceMuted = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceForceDeafened = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceMovedIn = StreamController<Map<String, dynamic>>.broadcast();
  final _voiceYouWereMoved = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessageCreated => _messageCreated.stream;
  Stream<Map<String, dynamic>> get onMessageUpdated => _messageUpdated.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeleted.stream;
  Stream<Map<String, dynamic>> get onReactionAdded => _reactionAdded.stream;
  Stream<Map<String, dynamic>> get onReactionRemoved => _reactionRemoved.stream;
  Stream<Map<String, dynamic>> get onTypingStart => _typingStart.stream;
  Stream<Map<String, dynamic>> get onTypingStop => _typingStop.stream;
  Stream<Map<String, dynamic>> get onPresenceUpdate => _presenceUpdate.stream;
  Stream<bool> get onConnectionState => _connectionState.stream;

  // --- Faz 6.5: sesli/görüntülü görüşme ---
  Stream<Map<String, dynamic>> get onVoiceUserJoined => _voiceUserJoined.stream;
  Stream<Map<String, dynamic>> get onVoiceUserLeft => _voiceUserLeft.stream;
  Stream<Map<String, dynamic>> get onVoiceStateUpdated => _voiceStateUpdated.stream;
  Stream<Map<String, dynamic>> get onVoiceForceMuted => _voiceForceMuted.stream;
  Stream<Map<String, dynamic>> get onVoiceForceDeafened => _voiceForceDeafened.stream;
  Stream<Map<String, dynamic>> get onVoiceMovedIn => _voiceMovedIn.stream;
  /// Bir moderatör bu kullanıcıyı BAŞKA bir sesli kanala taşıdığında tetiklenir
  /// — hangi kanalda olursa olsun her zaman dinlenir (kişisel `user:<id>`
  /// odasına yayınlanır, bkz. `voice.service.ts` — `moveMember`).
  Stream<Map<String, dynamic>> get onVoiceYouWereMoved => _voiceYouWereMoved.stream;

  bool get isConnected => _socket?.connected ?? false;

  /// Bağlantıyı kurar (zaten bağlıysa hiçbir şey yapmaz). Token her
  /// bağlantıda `SecureStorageService`'ten TAZE okunur; access token süresi
  /// dolmuşsa `ApiClient` zaten sessizce yenilemiş olur (REST çağrıları
  /// sayesinde), bu yüzden burada ayrı bir refresh akışı gerekmez — sadece
  /// bağlantı koptuğunda son bilinen token ile yeniden denenir.
  Future<void> ensureConnected() async {
    if (isConnected || _connecting) return;
    _connecting = true;
    try {
      final token = await storage.accessToken;
      if (token == null) return;

      _socket?.dispose();
      _socket = io.io(
        ApiConstants.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .enableReconnection()
            .setAuth({'token': token})
            .setExtraHeaders({'Authorization': 'Bearer $token'})
            .setNamespace(ApiConstants.realtimeNamespace)
            .build(),
      );
      _bindListeners(_socket!);
    } finally {
      _connecting = false;
    }
  }

  void _bindListeners(io.Socket socket) {
    socket.onConnect((_) => _connectionState.add(true));
    socket.onDisconnect((_) => _connectionState.add(false));
    socket.onConnectError((_) => _connectionState.add(false));

    socket.on('message:created', (data) => _emit(_messageCreated, data));
    socket.on('message:updated', (data) => _emit(_messageUpdated, data));
    socket.on('message:deleted', (data) => _emit(_messageDeleted, data));
    socket.on('reaction:added', (data) => _emit(_reactionAdded, data));
    socket.on('reaction:removed', (data) => _emit(_reactionRemoved, data));
    socket.on('typing:start', (data) => _emit(_typingStart, data));
    socket.on('typing:stop', (data) => _emit(_typingStop, data));
    socket.on('presence:update', (data) => _emit(_presenceUpdate, data));

    socket.on('voice:user-joined', (data) => _emit(_voiceUserJoined, data));
    socket.on('voice:user-left', (data) => _emit(_voiceUserLeft, data));
    socket.on('voice:state-updated', (data) => _emit(_voiceStateUpdated, data));
    socket.on('voice:force-muted', (data) => _emit(_voiceForceMuted, data));
    socket.on('voice:force-deafened', (data) => _emit(_voiceForceDeafened, data));
    socket.on('voice:moved-in', (data) => _emit(_voiceMovedIn, data));
    socket.on('voice:you-were-moved', (data) => _emit(_voiceYouWereMoved, data));
  }

  void _emit(StreamController<Map<String, dynamic>> controller, dynamic data) {
    if (data is Map) {
      controller.add(Map<String, dynamic>.from(data));
    }
  }

  Future<void> joinChannel(String channelId) async {
    await ensureConnected();
    _socket?.emit('channel:join', {'channelId': channelId});
  }

  void leaveChannel(String channelId) {
    _socket?.emit('channel:leave', {'channelId': channelId});
  }

  Future<void> joinDm(String dmChannelId) async {
    await ensureConnected();
    _socket?.emit('dm:join', {'dmChannelId': dmChannelId});
  }

  void leaveDm(String dmChannelId) {
    _socket?.emit('dm:leave', {'dmChannelId': dmChannelId});
  }

  void emitTypingStart({String? channelId, String? dmChannelId}) {
    _socket?.emit('typing:start', {'channelId': channelId, 'dmChannelId': dmChannelId});
  }

  void emitTypingStop({String? channelId, String? dmChannelId}) {
    _socket?.emit('typing:stop', {'channelId': channelId, 'dmChannelId': dmChannelId});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
