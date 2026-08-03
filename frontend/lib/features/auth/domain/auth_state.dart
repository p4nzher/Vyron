import '../domain/app_user.dart';

/// Uygulama genelindeki oturum durumu. `router.redirect` bu duruma göre
/// kullanıcıyı doğru ekrana yönlendirir (bkz. `core/router/app_router.dart`).
enum AuthStatus {
  /// Uygulama açılışında token doğrulaması henüz tamamlanmadı — splash ekranı
  /// bu durumda gösterilmeye devam eder.
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user});

  final AuthStatus status;
  final AppUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, AppUser? user}) {
    return AuthState(status: status ?? this.status, user: user ?? this.user);
  }
}
