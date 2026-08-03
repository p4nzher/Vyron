import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../data/auth_repository.dart';
import '../../data/user_repository.dart';
import '../../domain/app_user.dart';
import '../../domain/auth_state.dart';

/// `GetIt` (`sl`) tekil'lerini Riverpod dünyasına köprüler. Özellik
/// katmanları bu provider'ları tüketir; `sl` doğrudan widget'lar içinde
/// kullanılmamalıdır (bkz. `core/di/service_locator.dart` mimari notu).
final apiClientProvider = Provider<ApiClient>((ref) => sl<ApiClient>());
final secureStorageProvider = Provider<SecureStorageService>((ref) => sl<SecureStorageService>());

/// Faz 6.4: paylasilan Socket.IO baglantisi (bkz. core/realtime/socket_service.dart).
final socketServiceProvider = Provider<SocketService>((ref) => sl<SocketService>());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(userRepositoryProvider),
    ref.watch(apiClientProvider),
    ref.watch(socketServiceProvider),
  );
});

/// Kalıcı oturum durumunu yöneten tekil kaynak. Sorumlulukları:
///  1) Uygulama açılışında (`checkAuthStatus`) kayıtlı bir refresh token
///     varsa onu doğrulamak (gerçek doğrulama `GET /users/me` çağrısıdır —
///     access token süresi dolmuşsa `ApiClient` bunu sessizce yeniler).
///  2) `login`/`register`/`logout` sonrası global durumu güncellemek —
///     bu sayede `go_router` redirect'i otomatik olarak doğru ekrana geçer.
///  3) Refresh token da geçersiz hale geldiğinde (`ApiClient.onSessionExpired`)
///     uygulamanın HERHANGİ bir yerinden oturumu kapatmak.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authRepository, this._userRepository, this._apiClient, this._socketService)
      : super(const AuthState()) {
    _apiClient.onSessionExpired = () {
      _socketService.disconnect();
      state = const AuthState(status: AuthStatus.unauthenticated);
    };
    checkAuthStatus();
  }

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final ApiClient _apiClient;
  final SocketService _socketService;

  Future<void> checkAuthStatus() async {
    // Splash logosunun en az bir an görünür kalması için (algılanan
    // performans) — network ne kadar hızlı dönerse dönsün uygulanır.
    final minDelay = Future<void>.delayed(const Duration(milliseconds: 900));

    final hasSession = await _apiClient.storage.hasSession;
    if (!hasSession) {
      await minDelay;
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _userRepository.getMe();
      await minDelay;
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException {
      await _apiClient.storage.clear();
      await minDelay;
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({required String email, required String password, String? twoFactorCode}) async {
    final result = await _authRepository.login(
      email: email,
      password: password,
      twoFactorCode: twoFactorCode,
    );
    state = AuthState(status: AuthStatus.authenticated, user: result.user);
  }

  Future<void> register({required String email, required String username, required String password}) async {
    final result = await _authRepository.register(email: email, username: username, password: password);
    state = AuthState(status: AuthStatus.authenticated, user: result.user);
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _socketService.disconnect();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Faz 6.7 — Ayarlar → Güvenlik → "Tüm Cihazlardan Çıkış Yap".
  Future<void> logoutEverywhere() async {
    await _authRepository.logoutAllDevices();
    _socketService.disconnect();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Profil düzenleme / 2FA kurulumu gibi akışlar sunucuya yazdıktan sonra,
  /// tekrar bir `GET /users/me` yapmadan yerel önbelleği tazelemek için.
  void updateUser(AppUser user) {
    if (!state.isAuthenticated) return;
    state = state.copyWith(user: user);
  }
}
