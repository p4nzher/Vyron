/// Backend `ServerBan` modeli ile birebir eşleşir. Yasaklı kullanıcının
/// profil bilgisi (kullanıcı adı vb.) backend'den dönmez — sadece `userId`;
/// istemci bunu listeleme sırasında olduğu gibi (kısaltılmış ID ile) gösterir.
class ServerBan {
  const ServerBan({
    required this.id,
    required this.userId,
    required this.bannedById,
    required this.createdAt,
    this.reason,
  });

  final String id;
  final String userId;
  final String bannedById;
  final DateTime createdAt;
  final String? reason;

  factory ServerBan.fromJson(Map<String, dynamic> json) {
    return ServerBan(
      id: json['id'] as String,
      userId: json['userId'] as String,
      bannedById: json['bannedById'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
    );
  }
}
