import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../dm/presentation/controllers/dm_providers.dart';
import '../../../servers/presentation/controllers/servers_providers.dart';
import '../../../settings/presentation/controllers/notification_prefs_controller.dart';
import '../../domain/notifications_state.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) => sl<NotificationService>());

/// GLOBAL bir provider (autoDispose DEĞİL) — `VoiceCallBar`/`voiceCallControllerProvider`
/// ile aynı mimari (bkz. `voice_call_providers.dart` notu): `HomeShellScreen`
/// ilk kez kurulduğunda başlar ve oturum boyunca (uygulama tamamen kapanana
/// kadar) canlı kalır.
///
/// SORUMLULUK: kullanıcının TÜM DM'lerine ve TÜM metin kanallarına "pasif"
/// olarak katılır (bkz. `SocketService.joinDm`/`joinChannel` — bu çağrılar
/// zaten yetki kontrolünden geçer) — bu, `MessagesController`'ın SADECE o an
/// AÇIK olan tek bir kapsama katıldığı "aktif izleme" katılımından farklı ve
/// ondan bağımsızdır (iki katılım seti aynı odada çakışsa da socket.io'da
/// tekrar katılmak zararsızdır). Böylece kullanıcı bir kanalı/DM'i
/// GÖRÜNTÜLEMİYORKEN bile `message:created` olayı bu servise ulaşır ve
/// okunmamış rozetine + yerel bildirime çevrilebilir.
///
/// SINIRLAMA: bu sadece uygulama açıkken çalışır — bkz. `NotificationService`
/// doc yorumu ve `frontend/README.md` Faz 6.7 notu.
final notificationsControllerProvider = StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  return NotificationsController(ref);
});

class NotificationsController extends StateNotifier<NotificationsState> {
  NotificationsController(this._ref) : super(const NotificationsState()) {
    _bootstrap();
  }

  final Ref _ref;
  final List<StreamSubscription<Map<String, dynamic>>> _subs = [];
  bool _bootstrapped = false;
  int _notificationIdCounter = 0;

  final Map<String, String> _channelTitles = {}; // channelId -> "#kanal - sunucu"

  Future<void> _bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final socket = _ref.read(socketServiceProvider);
    _subs.add(socket.onMessageCreated.listen(_handleMessageCreated));

    final myUserId = _ref.read(authControllerProvider).user?.id;
    if (myUserId == null) return;

    try {
      final dmChannels = await _ref.read(dmRepositoryProvider).listMine();
      for (final dm in dmChannels) {
        await socket.joinDm(dm.id);
      }
    } on Object {
      // Sessizce yut - bildirim altyapisi ana akisi asla bloklamamali.
    }

    try {
      final servers = await _ref.read(serversRepositoryProvider).listMine();
      for (final server in servers) {
        final detail = await _ref.read(serversRepositoryProvider).getDetail(server.id);
        for (final channel in detail.channels) {
          if (channel.isCategory || channel.isVoice) continue;
          _channelTitles[channel.id] = '#${channel.name} - ${server.name}';
          await socket.joinChannel(channel.id);
        }
      }
    } on Object {
      // ayni sekilde
    }
  }

  void _handleMessageCreated(Map<String, dynamic> payload) {
    final myUserId = _ref.read(authControllerProvider).user?.id;
    final authorId = payload['authorId'] as String?;
    if (authorId == null || authorId == myUserId) return;

    final channelId = payload['channelId'] as String?;
    final dmChannelId = payload['dmChannelId'] as String?;
    final key = channelId != null ? 'channel:$channelId' : (dmChannelId != null ? 'dm:$dmChannelId' : null);
    if (key == null) return;

    if (key == state.activeScopeKey) return; // zaten o kapsam acik, rahatsiz etme

    final updated = Map<String, int>.from(state.unreadByScope);
    updated[key] = (updated[key] ?? 0) + 1;
    state = state.copyWith(unreadByScope: updated);

    final author = payload['author'] as Map<String, dynamic>?;
    final authorName = (author?['displayName'] as String?) ?? (author?['username'] as String?) ?? 'Biri';
    final content = payload['content'] as String?;
    final body = (content != null && content.isNotEmpty) ? content : 'Bir ek gonderdi';

    final title = channelId != null ? (_channelTitles[channelId] ?? 'Yeni mesaj') : authorName;
    final resolvedBody = channelId != null ? '$authorName: $body' : body;

    _notificationIdCounter++;
    _ref.read(notificationServiceProvider).show(
          id: _notificationIdCounter,
          title: title,
          body: resolvedBody,
          playSound: _ref.read(notificationPrefsControllerProvider).soundsEnabled,
        );
  }

  /// `ContentPanel` bir kanal/DM'i actiginda/kapattiginda cagrilir (bkz.
  /// `_ActiveScopeReporter`). Bir kapsam aktif olarak isaretlendiginde, o
  /// kapsamin okunmamis sayaci da temizlenir.
  void setActiveScope(String? key) {
    if (key == null) {
      state = state.copyWith(clearActive: true);
      return;
    }
    final updated = Map<String, int>.from(state.unreadByScope)..remove(key);
    state = NotificationsState(unreadByScope: updated, activeScopeKey: key);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
