import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_exception.dart';
import '../domain/app_user.dart';

class AuthResult {
  const AuthResult(this.user);
  final AppUser user;
}

/// `POST /auth/2fa/generate` yanıtı — authenticator uygulamasına taranacak
/// QR kodu (otpauth:// URI'si) ve manuel girişe izin veren ham secret'ı içerir.
class TwoFactorSecret {
  const TwoFactorSecret({required this.secret, required this.otpAuthUrl});

  final String secret;
  final String otpAuthUrl;

  factory TwoFactorSecret.fromJson(Map<String, dynamic> json) {
    return TwoFactorSecret(
      secret: json['secret'] as String,
      otpAuthUrl: json['otpAuthUrl'] as String,
    );
  }
}

/// Kimlik doğrulama uç noktalarını sarmalar. Riverpod tabanlı tam
/// `AuthController` (oturum durumu, otomatik yönlendirme) Faz 6.2'de bu
/// repository'nin üzerine kurulacak; bu haliyle bile ekranlar gerçek
/// backend'e karşı çalışır (kayıt/giriş uçtan uca fonksiyoneldir).
class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    return _client.guard(
      () => _client.dio.post(ApiConstants.register, data: {
        'email': email,
        'username': username,
        'password': password,
      }),
      (data) => _handleAuthResponse(data as Map<String, dynamic>),
    );
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    return _client.guard(
      () => _client.dio.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
        if (twoFactorCode != null && twoFactorCode.isNotEmpty) 'twoFactorCode': twoFactorCode,
      }),
      (data) => _handleAuthResponse(data as Map<String, dynamic>),
    );
  }

  Future<void> logout() async {
    try {
      await _client.dio.post(ApiConstants.logout);
    } on Object {
      // Sunucuya ulaşılamasa bile yerel oturum temizlenir.
    } finally {
      await _client.storage.clear();
    }
  }

  /// Kullanıcının TÜM cihazlardaki oturumlarını sonlandırır (bkz. `Ayarlar` →
  /// `Güvenlik` — Faz 6.7). Bu cihazdaki oturum da kapatılmalıdır, bu yüzden
  /// çağıran taraf (`AuthController.logoutEverywhere`) yerel durumu da sıfırlar.
  Future<void> logoutAllDevices() async {
    try {
      await _client.dio.post(ApiConstants.logoutAll);
    } on Object {
      // aynı şekilde — yerel temizlik her durumda yapılır.
    } finally {
      await _client.storage.clear();
    }
  }

  /// Şifre sıfırlama e-postası tetikler. Kullanıcı var/yok bilgisi backend
  /// tarafından sızdırılmadığı için bu çağrı e-posta kayıtlı olmasa da başarılı
  /// döner — UI her zaman "gönderildiyse..." mesajı göstermelidir.
  Future<void> forgotPassword(String email) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.forgotPassword, data: {'email': email}),
      (_) {},
    );
  }

  /// E-postayla gelen token ile yeni şifre belirler. Başarılı olursa backend
  /// kullanıcının tüm cihazlardaki oturumlarını iptal eder; bu yüzden
  /// çağıran taraf ardından kullanıcıyı giriş ekranına yönlendirmelidir.
  Future<void> resetPassword({required String token, required String newPassword}) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.resetPassword, data: {
        'token': token,
        'newPassword': newPassword,
      }),
      (_) {},
    );
  }

  /// 2FA kurulumunun ilk adımı: authenticator QR'ı için secret üretir.
  Future<TwoFactorSecret> generate2fa() {
    return _client.guard(
      () => _client.dio.post(ApiConstants.twoFactorGenerate),
      (data) => TwoFactorSecret.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Kullanıcının authenticator'dan aldığı 6 haneli kodu doğrulayıp 2FA'yı
  /// etkinleştirir. Dönen yedek kodlar SADECE bu çağrıda gösterilir.
  Future<List<String>> enable2fa(String code) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.twoFactorEnable, data: {'code': code}),
      (data) => List<String>.from((data as Map<String, dynamic>)['backupCodes'] as List),
    );
  }

  Future<void> disable2fa() {
    return _client.guard(
      () => _client.dio.post(ApiConstants.twoFactorDisable),
      (_) {},
    );
  }

  Future<AuthResult> _handleAuthResponse(Map<String, dynamic> data) async {
    final tokens = data['tokens'] as Map<String, dynamic>;
    await _client.storage.saveTokens(
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
    return AuthResult(AppUser.fromJson(data['user'] as Map<String, dynamic>));
  }
}

/// `login()`'in `TWO_FACTOR_REQUIRED` hatasını UI'da ayırt etmek için yardımcı.
extension AuthExceptionX on ApiException {
  bool get requiresTwoFactor => isTwoFactorRequired;
}
