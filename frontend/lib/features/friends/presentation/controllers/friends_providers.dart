import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/friends_repository.dart';
import '../../domain/friend_request.dart';
import '../../domain/friend_user.dart';

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) {
  return FriendsRepository(ref.watch(apiClientProvider));
});

final friendsListProvider = FutureProvider<List<FriendUser>>((ref) {
  return ref.watch(friendsRepositoryProvider).listFriends();
});

final incomingRequestsProvider = FutureProvider<List<FriendRequest>>((ref) {
  return ref.watch(friendsRepositoryProvider).listIncoming();
});

final outgoingRequestsProvider = FutureProvider<List<FriendRequest>>((ref) {
  return ref.watch(friendsRepositoryProvider).listOutgoing();
});

final blockedListProvider = FutureProvider<List<FriendUser>>((ref) {
  return ref.watch(friendsRepositoryProvider).listBlocked();
});

/// Rayda/DM listesinde "Arkadaşlar" rozetinin sayısı için — sadece gelen
/// (yanıt bekleyen) istekleri sayar, giden istekleri saymaz.
final pendingIncomingCountProvider = Provider<int>((ref) {
  return ref.watch(incomingRequestsProvider).valueOrNull?.length ?? 0;
});
