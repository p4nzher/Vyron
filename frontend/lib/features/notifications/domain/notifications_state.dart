/// Bkz. `notifications_controller.dart` — okunmamış sayaçlar `MessageScope.key`
/// (`"channel:<id>"` / `"dm:<id>"`) ile anahtarlanır, böylece hem kanal listesi
/// hem DM listesi aynı haritayı doğrudan okuyabilir.
class NotificationsState {
  const NotificationsState({this.unreadByScope = const {}, this.activeScopeKey});

  final Map<String, int> unreadByScope;
  final String? activeScopeKey;

  int unreadFor(String key) => unreadByScope[key] ?? 0;

  int get totalUnread => unreadByScope.values.fold(0, (a, b) => a + b);

  NotificationsState copyWith({Map<String, int>? unreadByScope, String? activeScopeKey, bool clearActive = false}) {
    return NotificationsState(
      unreadByScope: unreadByScope ?? this.unreadByScope,
      activeScopeKey: clearActive ? null : (activeScopeKey ?? this.activeScopeKey),
    );
  }
}
