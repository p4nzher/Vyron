import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/friend_request.dart';
import '../domain/friend_user.dart';

/// `/friends` uç noktalarını sarmalar (bkz. `friends.controller.ts`) —
/// arkadaş listesi, istek gönder/kabul et/reddet/iptal et, kaldır, engelle.
class FriendsRepository {
  FriendsRepository(this._client);

  final ApiClient _client;

  Future<List<FriendUser>> listFriends() {
    return _client.guard(
      () => _client.dio.get(ApiConstants.friends),
      (data) => (data as List<dynamic>).map((u) => FriendUser.fromJson(u as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<FriendRequest>> listIncoming() {
    return _client.guard(
      () => _client.dio.get(ApiConstants.friendRequestsIncoming),
      (data) => (data as List<dynamic>)
          .map((r) => FriendRequest.fromJson(r as Map<String, dynamic>, otherUserKey: 'requester'))
          .toList(),
    );
  }

  Future<List<FriendRequest>> listOutgoing() {
    return _client.guard(
      () => _client.dio.get(ApiConstants.friendRequestsOutgoing),
      (data) => (data as List<dynamic>)
          .map((r) => FriendRequest.fromJson(r as Map<String, dynamic>, otherUserKey: 'addressee'))
          .toList(),
    );
  }

  /// `usernameTag`: "kullaniciadi#0000" formatında.
  Future<void> sendRequest(String usernameTag) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.friendRequests, data: {'usernameTag': usernameTag}),
      (_) => null,
    );
  }

  Future<void> accept(String friendshipId) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.friendRequestAccept, data: {'friendshipId': friendshipId}),
      (_) => null,
    );
  }

  Future<void> reject(String friendshipId) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.friendRequestReject, data: {'friendshipId': friendshipId}),
      (_) => null,
    );
  }

  Future<void> cancel(String friendshipId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.friendRequestCancel(friendshipId)),
      (_) => null,
    );
  }

  Future<void> remove(String userId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.friend(userId)),
      (_) => null,
    );
  }

  Future<List<FriendUser>> listBlocked() {
    return _client.guard(
      () => _client.dio.get(ApiConstants.friendsBlocked),
      (data) => (data as List<dynamic>).map((u) => FriendUser.fromJson(u as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> block(String userId) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.friendBlock(userId)),
      (_) => null,
    );
  }

  Future<void> unblock(String userId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.friendBlock(userId)),
      (_) => null,
    );
  }
}
