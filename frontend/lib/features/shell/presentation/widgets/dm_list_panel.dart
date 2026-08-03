import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/status_dot.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../dm/domain/dm_channel.dart';
import '../../../dm/presentation/controllers/dm_providers.dart';
import '../../../friends/presentation/controllers/friends_providers.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';

/// İkinci sütun — DM alanı seçiliyken gösterilen konuşma listesi.
class DmListPanel extends ConsumerStatefulWidget {
  const DmListPanel({this.selectedDmChannelId, super.key});

  final String? selectedDmChannelId;

  @override
  ConsumerState<DmListPanel> createState() => _DmListPanelState();
}

class _DmListPanelState extends ConsumerState<DmListPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final dmListAsync = ref.watch(dmListProvider);
    final currentUserId = ref.watch(authControllerProvider).user?.id;

    return Container(
      color: AppColors.backgroundSecondary.withOpacity(0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Direkt Mesajlar', style: AppTextStyles.title),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _FriendsEntryButton(),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppTextField(
              label: '',
              hint: 'Konuşma ara',
              prefixIcon: Icons.search_rounded,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: dmListAsync.when(
              data: (channels) {
                if (currentUserId == null) return const SizedBox.shrink();
                final filtered = _query.isEmpty
                    ? channels
                    : channels
                        .where((c) => c.displayName(currentUserId).toLowerCase().contains(_query))
                        .toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        channels.isEmpty
                            ? 'Henüz bir konuşman yok.\nArkadaşlar sekmesinden birine mesaj gönderebilirsin.'
                            : 'Sonuç bulunamadı.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final channel = filtered[index];
                    final other = channel.otherParticipant(currentUserId);
                    final selected = channel.id == widget.selectedDmChannelId;
                    return _DmListTile(
                      channel: channel,
                      other: other,
                      currentUserId: currentUserId,
                      isSelected: selected,
                      onTap: () => context.go(AppRoutes.dmPath(channel.id)),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Konuşmalar yüklenemedi.', style: AppTextStyles.caption),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(dmListProvider),
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmListTile extends ConsumerWidget {
  const _DmListTile({
    required this.channel,
    required this.other,
    required this.currentUserId,
    required this.isSelected,
    required this.onTap,
  });

  final DmChannel channel;
  final DmParticipant? other;
  final String currentUserId;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = channel.lastMessage;
    final previewText = preview == null
        ? 'Henüz mesaj yok'
        : (preview.content?.isNotEmpty == true ? preview.content! : 'Ek gönderildi');
    final unread = ref.watch(notificationsControllerProvider).unreadFor('dm:${channel.id}');

    return Material(
      color: isSelected ? AppColors.backgroundElevated : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.backgroundElevated,
                    backgroundImage: other?.avatarUrl != null ? NetworkImage(other!.avatarUrl!) : null,
                    child: other?.avatarUrl == null
                        ? Text(_initial(channel.displayName(currentUserId)), style: AppTextStyles.bodyMedium)
                        : null,
                  ),
                  if (!channel.isGroup && other != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: StatusDot(status: other!.status, borderColor: AppColors.backgroundSecondary),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      channel.displayName(currentUserId),
                      style: AppTextStyles.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      previewText,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (unread > 0) _UnreadBadge(count: unread),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: BoxDecoration(color: AppColors.statusDnd, borderRadius: BorderRadius.circular(10)),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: AppTextStyles.small.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FriendsEntryButton extends ConsumerWidget {
  const _FriendsEntryButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingIncomingCountProvider);

    return Material(
      color: AppColors.backgroundElevated.withOpacity(0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(AppRoutes.friends),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.people_alt_rounded, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Arkadaşlar', style: AppTextStyles.bodyMedium)),
              if (pending > 0) _UnreadBadge(count: pending),
            ],
          ),
        ),
      ),
    );
  }
}

String _initial(String value) => value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();
