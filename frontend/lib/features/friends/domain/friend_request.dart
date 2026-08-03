import 'friend_user.dart';

/// `GET /friends/requests/incoming|outgoing` yanıtındaki her öge — bir
/// `Friendship` (status: PENDING) satırı, karşı tarafın kullanıcı bilgisiyle
/// birlikte (bkz. `FriendsService.listIncomingRequests`/`listOutgoingRequests`).
class FriendRequest {
  const FriendRequest({required this.id, required this.user, required this.createdAt});

  /// `Friendship.id` — kabul/reddet/iptal çağrılarında bu kullanılır.
  final String id;
  final FriendUser user;
  final DateTime createdAt;

  factory FriendRequest.fromJson(Map<String, dynamic> json, {required String otherUserKey}) {
    return FriendRequest(
      id: json['id'] as String,
      user: FriendUser.fromJson(json[otherUserKey] as Map<String, dynamic>),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
