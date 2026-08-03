import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// `flutter_local_notifications` etrafında ince bir sarmalayıcı.
///
/// ÖNEMLİ SINIRLAMA: bu SADECE uygulama açıkken (ön planda ya da arka planda
/// çalışırken) yerel bildirim gösterir. Gerçek bir "push" (uygulama tamamen
/// kapalıyken bile bildirim alma) için backend'de bir cihaz-token kayıt
/// tablosu ve FCM/APNs entegrasyonu gerekir — bu depoda henüz yok (bkz.
/// `frontend/README.md` — Faz 6.7 notu). Bu servis, Socket.IO bağlantısı
/// açıkken gelen olayları yerel bildirime çevirerek makul bir orta yol sağlar.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool enabled = true;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    // Android 13+ (API 33) bildirim izni artık çalışma zamanında (runtime)
    // ayrıca istenmeli — eklenti bunu otomatik yapmaz.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool playSound = true,
  }) async {
    if (!_initialized || !enabled) return;
    final androidDetails = AndroidNotificationDetails(
      'vyron_messages',
      'Mesajlar ve Arkadaşlık İstekleri',
      channelDescription: 'Yeni mesaj ve arkadaşlık isteği bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      playSound: playSound,
    );
    final iosDetails = DarwinNotificationDetails(presentSound: playSound);
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
