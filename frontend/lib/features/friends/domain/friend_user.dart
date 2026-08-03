/// `FriendsService.publicUserSelect` ile birebir eşleşen küçük kullanıcı
/// modeli — arkadaş listesi, bekleyen istekler ve engellenenler ekranlarının
/// hepsi bu tek tipi paylaşır.
class FriendUser {
  const FriendUser({
    required this.id,
    required this.username,
    required this.discriminator,
    this.displayName,
    this.avatarUrl,
    this.status = 'OFFLINE',
  });

  final String id;
  final String username;
  final String discriminator;
  final String? displayName;
  final String? avatarUrl;
  final String status;

  String get name => displayName ?? username;
  String get tag => '$username#$discriminator';
  bool get isOnline => status != 'OFFLINE' && status != 'INVISIBLE';

  factory FriendUser.fromJson(Map<String, dynamic> json) {
    return FriendUser(
      id: json['id'] as String,
      username: json['username'] as String,
      discriminator: json['discriminator'] as String? ?? '0000',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      status: json['status'] as String? ?? 'OFFLINE',
    );
  }
}
