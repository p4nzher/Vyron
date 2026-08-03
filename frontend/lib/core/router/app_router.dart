import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/settings/presentation/screens/two_factor_setup_screen.dart';
import '../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../features/shell/presentation/screens/home_shell_screen.dart';
import '../../features/servers/presentation/screens/server_settings_screen.dart';
import '../../features/friends/presentation/screens/friends_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  /// Faz 6.3 ana kabuk: DM listesi (kanal/sunucu seçili değilken varsayılan).
  static const String home = '/home';
  static const String homeDm = '/home/dm/:dmChannelId';
  static const String homeServer = '/home/servers/:serverId';
  static const String homeServerChannel = '/home/servers/:serverId/channels/:channelId';
  static const String serverSettings = '/home/servers/:serverId/settings';
  static const String friends = '/home/friends';
  static const String appSettings = '/home/settings';

  static String dmPath(String dmChannelId) => '/home/dm/$dmChannelId';
  static String serverPath(String serverId) => '/home/servers/$serverId';
  static String channelPath(String serverId, String channelId) => '/home/servers/$serverId/channels/$channelId';
  static String serverSettingsPath(String serverId) => '/home/servers/$serverId/settings';

  static const String twoFactorSetup = '/settings/2fa';
  static const String profileEdit = '/settings/profile';
}

/// `go_router`'ın `refreshListenable`'ı `Listenable` bekler; Riverpod'un
/// `StateNotifier` akışını buna köprüler. `redirect` her tetiklendiğinde
/// GÜNCEL durumu okumak için `ref.read` kullanılır (bkz. altta `redirect`).
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

/// Rota-koruma kuralları:
///  - `AuthStatus.unknown`  → splash dışındaki her yerden splash'e döner
///    (token doğrulaması bitene kadar bekler).
///  - `AuthStatus.unauthenticated` → auth rotaları (login/register/şifre
///    sıfırlama) HARİÇ her yerden `/login`'e döner.
///  - `AuthStatus.authenticated` → splash/login/register'da kalınmışsa
///    `/home`'a döner; korumalı rotalar (2FA/profil) serbest bırakılır.
final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  const authRoutes = {AppRoutes.login, AppRoutes.register, AppRoutes.forgotPassword, AppRoutes.resetPassword};

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (authState.status == AuthStatus.unknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return authRoutes.contains(location) ? null : AppRoutes.login;
      }

      // authenticated
      if (location == AppRoutes.splash || location == AppRoutes.login || location == AppRoutes.register) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          prefilledToken: state.uri.queryParameters['token'],
        ),
      ),
      // Faz 6.3 ana kabuk: hepsi aynı `HomeShellScreen`'i, farklı yol
      // parametreleriyle kurar. Seçim durumu bilinçli olarak URL'de tutulur
      // (bkz. `HomeShellScreen` doc yorumu) — ayrı bir seçim state'i yok.
      GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeShellScreen()),
      GoRoute(
        path: AppRoutes.homeDm,
        builder: (context, state) => HomeShellScreen(dmChannelId: state.pathParameters['dmChannelId']),
      ),
      GoRoute(
        path: AppRoutes.homeServer,
        builder: (context, state) => HomeShellScreen(serverId: state.pathParameters['serverId']),
      ),
      GoRoute(
        path: AppRoutes.homeServerChannel,
        builder: (context, state) => HomeShellScreen(
          serverId: state.pathParameters['serverId'],
          channelId: state.pathParameters['channelId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.twoFactorSetup,
        builder: (context, state) => const TwoFactorSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.serverSettings,
        builder: (context, state) => ServerSettingsScreen(serverId: state.pathParameters['serverId']!),
      ),
      GoRoute(
        path: AppRoutes.friends,
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: AppRoutes.appSettings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
