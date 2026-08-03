import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/app_user.dart';

/// `GET/PATCH /users/me` uç noktalarını sarmalar. `AuthRepository`'den ayrı
/// tutulmasının nedeni: burası kimlik doğrulama değil, profil/hesap yönetimi
/// sorumluluğu taşır (bkz. Faz 6.2 profil düzenleme ekranı).
class UserRepository {
  UserRepository(this._client);

  final ApiClient _client;

  Future<AppUser> getMe() {
    return _client.guard(
      () => _client.dio.get(ApiConstants.me),
      (data) => AppUser.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Sadece verilen alanları günceller (null bırakılanlar dokunulmadan kalır).
  /// Backend'in `PATCH /users/me` yanıtı kısmi bir seçim döndürdüğü için
  /// (email/status/twoFactorEnabled içermez), burada `void` dönülür — çağıran
  /// taraf gönderdiği değerlerle yerel `AppUser.copyWith` uygular
  /// (bkz. `ProfileEditScreen._save`).
  Future<void> updateProfile({String? displayName, String? bio, String? avatarUrl, String? bannerUrl}) {
    return _client.guard(
      () => _client.dio.patch(ApiConstants.me, data: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (bannerUrl != null) 'bannerUrl': bannerUrl,
      }),
      (_) {},
    );
  }

  /// `status`: 'ONLINE' | 'IDLE' | 'DND' | 'INVISIBLE'
  Future<void> updateStatus(String status) {
    return _client.guard(
      () => _client.dio.patch(ApiConstants.meStatus, data: {'status': status}),
      (_) {},
    );
  }
}
