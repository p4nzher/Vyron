/// Backend `PublicUser` (bkz. `auth.service.ts`) ve `users.service.ts` içindeki
/// `findById` seçimi ile birebir eşleşen model.
/// Faz 6.2'de `freezed`'e taşınacak; şimdilik basit ve bağımlısız tutuldu.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.discriminator,
    required this.email,
    required this.status,
    required this.twoFactorEnabled,
    this.displayName,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.customStatusText,
    this.createdAt,
  });

  final String id;
  final String username;
  final String discriminator;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final String? customStatusText;
  final String status;
  final bool twoFactorEnabled;
  final DateTime? createdAt;

  /// Discord'daki "kullanıcı#1234" biçimi.
  String get tag => '$username#$discriminator';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      discriminator: json['discriminator'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      bio: json['bio'] as String?,
      customStatusText: json['customStatusText'] as String?,
      status: json['status'] as String? ?? 'OFFLINE',
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
    );
  }

  /// Sunucuya profil/durum güncellemesi gönderdikten sonra, tekrar bir
  /// `GET /users/me` yapmadan yerel önbelleği güncellemek için kullanılır
  /// (bkz. `AuthController.updateUser`, `ProfileEditScreen`).
  AppUser copyWith({
    String? displayName,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    String? customStatusText,
    String? status,
    bool? twoFactorEnabled,
  }) {
    return AppUser(
      id: id,
      username: username,
      discriminator: discriminator,
      email: email,
      status: status ?? this.status,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      customStatusText: customStatusText ?? this.customStatusText,
      createdAt: createdAt,
    );
  }
}
