import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/status_dot.dart';
import '../../domain/friend_request.dart';
import '../../domain/friend_user.dart';
import '../controllers/friends_providers.dart';
import '../widgets/add_friend_sheet.dart';
import 'start_dm_mixin.dart';

/// Faz 6.7 — Discord'daki "Arkadaşlarım" sayfasının karşılığı. `DmListPanel`
/// üstündeki "Arkadaşlar" satırından (bkz. `dm_list_panel.dart`) tam ekran
/// olarak açılır. Bekleyen istek varsa doğrudan o sekmeyle açılır.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _initializedInitialTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final incomingCount = ref.watch(pendingIncomingCountProvider);

    if (!_initializedInitialTab) {
      _initializedInitialTab = true;
      if (incomingCount > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _tabController.animateTo(1));
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text('Arkadaşlar', style: AppTextStyles.title),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.brandGradientEnd,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            const Tab(text: 'Çevrimiçi'),
            Tab(text: incomingCount > 0 ? 'Bekleyen ($incomingCount)' : 'Bekleyen'),
            const Tab(text: 'Tümü'),
            const Tab(text: 'Engellenenler'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Arkadaş Ekle',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => showAddFriendSheet(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _OnlineFriendsTab(),
          _PendingRequestsTab(),
          _AllFriendsTab(),
          _BlockedTab(),
        ],
      ),
    );
  }
}

class _OnlineFriendsTab extends ConsumerWidget {
  const _OnlineFriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    return friendsAsync.when(
      data: (friends) {
        final online = friends.where((f) => f.isOnline).toList();
        if (online.isEmpty) {
          return Center(child: Text('Çevrimiçi arkadaşın yok.', style: AppTextStyles.caption));
        }
        return _FriendList(friends: online);
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Arkadaşlar yüklenemedi.', style: AppTextStyles.caption)),
    );
  }
}

class _AllFriendsTab extends ConsumerWidget {
  const _AllFriendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    return friendsAsync.when(
      data: (friends) {
        if (friends.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Henüz arkadaşın yok.\nSağ üstteki + ile arkadaş ekleyebilirsin.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
          );
        }
        return _FriendList(friends: friends);
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Arkadaşlar yüklenemedi.', style: AppTextStyles.caption)),
    );
  }
}

class _FriendList extends ConsumerWidget {
  const _FriendList({required this.friends});
  final List<FriendUser> friends;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _FriendRow(friend: friends[index]),
    );
  }
}

class _FriendRow extends ConsumerWidget with StartDmMixin {
  const _FriendRow({required this.friend});
  final FriendUser friend;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: Text('${friend.name} arkadaşlıktan çıkarılsın mı?', style: AppTextStyles.title),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çıkar', style: TextStyle(color: AppColors.statusDnd)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(friendsRepositoryProvider).remove(friend.id);
      ref.invalidate(friendsListProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(friendsRepositoryProvider).block(friend.id);
      ref.invalidate(friendsListProvider);
      ref.invalidate(blockedListProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.backgroundPrimary,
                backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                child: friend.avatarUrl == null
                    ? Text(friend.name.substring(0, 1).toUpperCase(), style: AppTextStyles.bodyMedium)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: StatusDot(status: friend.status, borderColor: AppColors.backgroundElevated),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name, style: AppTextStyles.bodyMedium),
                Text(friend.tag, style: AppTextStyles.small),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Mesaj Gönder',
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            color: AppColors.textSecondary,
            onPressed: () => startDmWith(context, ref, friend.id),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            color: AppColors.backgroundElevated,
            onSelected: (value) {
              if (value == 'remove') _remove(context, ref);
              if (value == 'block') _block(context, ref);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'remove', child: Text('Arkadaşlıktan Çıkar')),
              const PopupMenuItem(value: 'block', child: Text('Engelle')),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingRequestsTab extends ConsumerWidget {
  const _PendingRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingAsync = ref.watch(incomingRequestsProvider);
    final outgoingAsync = ref.watch(outgoingRequestsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('GELEN İSTEKLER', style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        incomingAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('Bekleyen gelen istek yok.', style: AppTextStyles.caption),
              );
            }
            return Column(
              children: [for (final r in requests) _IncomingRequestRow(request: r)],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
          ),
          error: (error, _) => Text('İstekler yüklenemedi.', style: AppTextStyles.caption),
        ),
        const SizedBox(height: 24),
        Text('GÖNDERİLEN İSTEKLER', style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        outgoingAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return Text('Bekleyen giden istek yok.', style: AppTextStyles.caption);
            }
            return Column(
              children: [for (final r in requests) _OutgoingRequestRow(request: r)],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
          ),
          error: (error, _) => Text('İstekler yüklenemedi.', style: AppTextStyles.caption),
        ),
      ],
    );
  }
}

class _IncomingRequestRow extends ConsumerWidget {
  const _IncomingRequestRow({required this.request});
  final FriendRequest request;

  Future<void> _respond(WidgetRef ref, BuildContext context, bool accept) async {
    try {
      if (accept) {
        await ref.read(friendsRepositoryProvider).accept(request.id);
      } else {
        await ref.read(friendsRepositoryProvider).reject(request.id);
      }
      ref.invalidate(incomingRequestsProvider);
      ref.invalidate(friendsListProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.backgroundPrimary,
              backgroundImage: request.user.avatarUrl != null ? NetworkImage(request.user.avatarUrl!) : null,
              child: request.user.avatarUrl == null
                  ? Text(request.user.name.substring(0, 1).toUpperCase(), style: AppTextStyles.bodyMedium)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.user.name, style: AppTextStyles.bodyMedium),
                  Text(request.user.tag, style: AppTextStyles.small),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Kabul Et',
              icon: const Icon(Icons.check_circle_rounded),
              color: AppColors.statusOnline,
              onPressed: () => _respond(ref, context, true),
            ),
            IconButton(
              tooltip: 'Reddet',
              icon: const Icon(Icons.cancel_rounded),
              color: AppColors.statusDnd,
              onPressed: () => _respond(ref, context, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingRequestRow extends ConsumerWidget {
  const _OutgoingRequestRow({required this.request});
  final FriendRequest request;

  Future<void> _cancel(WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(friendsRepositoryProvider).cancel(request.id);
      ref.invalidate(outgoingRequestsProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.backgroundPrimary,
              backgroundImage: request.user.avatarUrl != null ? NetworkImage(request.user.avatarUrl!) : null,
              child: request.user.avatarUrl == null
                  ? Text(request.user.name.substring(0, 1).toUpperCase(), style: AppTextStyles.bodyMedium)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(request.user.name, style: AppTextStyles.bodyMedium),
                  Text('Yanıt bekleniyor…', style: AppTextStyles.small),
                ],
              ),
            ),
            TextButton(onPressed: () => _cancel(ref, context), child: const Text('İptal Et')),
          ],
        ),
      ),
    );
  }
}

class _BlockedTab extends ConsumerWidget {
  const _BlockedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedListProvider);
    return blockedAsync.when(
      data: (blocked) {
        if (blocked.isEmpty) {
          return Center(child: Text('Engellenen kimse yok.', style: AppTextStyles.caption));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: blocked.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _BlockedRow(user: blocked[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Liste yüklenemedi.', style: AppTextStyles.caption)),
    );
  }
}

class _BlockedRow extends ConsumerWidget {
  const _BlockedRow({required this.user});
  final FriendUser user;

  Future<void> _unblock(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(friendsRepositoryProvider).unblock(user.id);
      ref.invalidate(blockedListProvider);
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.backgroundPrimary,
            backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(user.name.substring(0, 1).toUpperCase(), style: AppTextStyles.bodyMedium)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(user.tag, style: AppTextStyles.bodyMedium)),
          TextButton(onPressed: () => _unblock(context, ref), child: const Text('Engeli Kaldır')),
        ],
      ),
    );
  }
}
