import 'package:get_it/get_it.dart';
import '../network/api_client.dart';
import '../notifications/notification_service.dart';
import '../realtime/socket_service.dart';
import '../storage/secure_storage_service.dart';

final GetIt sl = GetIt.instance;

/// Uygulama genelinde (Riverpod dışında kalan, ör. Dio) tekil bağımlılıkları
/// kaydeder. Özellik-bazlı repository'ler bu servisleri Riverpod
/// `Provider`ları ÜZERİNDEN enjekte eder (bkz. Faz 6.2 `auth_providers.dart`);
/// `sl` doğrudan widget'lar içinde kullanılmaz.
Future<void> setupServiceLocator() async {
  final storage = SecureStorageService();
  sl.registerSingleton<SecureStorageService>(storage);
  sl.registerSingleton<ApiClient>(ApiClient(storage: storage));
  // Tek bir Socket.IO bağlantısı — Faz 6.4 mesajlaşma ve Faz 6.7 bildirimleri
  // için paylaşılır.
  sl.registerSingleton<SocketService>(SocketService(storage: storage));
  // Faz 6.7: yerel bildirimler (bkz. `notification_service.dart` sınırlama notu).
  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } on Object {
    // Bildirim izni reddedilmiş/desteklenmeyen bir platform olsa bile
    // uygulama başlatılabilmeli — `NotificationService.show` zaten
    // `_initialized` bayrağını kontrol ederek sessizce hiçbir şey yapmaz.
  }
  sl.registerSingleton<NotificationService>(notificationService);
}
