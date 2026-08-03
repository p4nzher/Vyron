import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/notifications/notification_service.dart';

/// Bildirim tercihleri sadece CİHAZDA saklanır (`shared_preferences`) —
/// backend'de bir kullanıcı-tercihi tablosu olmadığı için bu tercihler
/// cihazlar arasında senkronize OLMAZ (bkz. `frontend/README.md` Faz 6.7 notu).
class NotificationPrefs {
  const NotificationPrefs({this.popupsEnabled = true, this.soundsEnabled = true});

  final bool popupsEnabled;
  final bool soundsEnabled;

  NotificationPrefs copyWith({bool? popupsEnabled, bool? soundsEnabled}) {
    return NotificationPrefs(
      popupsEnabled: popupsEnabled ?? this.popupsEnabled,
      soundsEnabled: soundsEnabled ?? this.soundsEnabled,
    );
  }
}

final notificationPrefsControllerProvider =
    StateNotifierProvider<NotificationPrefsController, NotificationPrefs>((ref) {
  return NotificationPrefsController();
});

class NotificationPrefsController extends StateNotifier<NotificationPrefs> {
  NotificationPrefsController() : super(const NotificationPrefs()) {
    _load();
  }

  static const _kPopups = 'vyron.notifications.popupsEnabled';
  static const _kSounds = 'vyron.notifications.soundsEnabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final popups = prefs.getBool(_kPopups) ?? true;
    final sounds = prefs.getBool(_kSounds) ?? true;
    state = NotificationPrefs(popupsEnabled: popups, soundsEnabled: sounds);
    sl<NotificationService>().enabled = popups;
  }

  Future<void> setPopupsEnabled(bool value) async {
    state = state.copyWith(popupsEnabled: value);
    sl<NotificationService>().enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPopups, value);
  }

  Future<void> setSoundsEnabled(bool value) async {
    state = state.copyWith(soundsEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSounds, value);
  }
}
