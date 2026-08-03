import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../servers/domain/channel.dart';
import '../../../servers/presentation/controllers/servers_providers.dart';

/// İkinci sütun — bir sunucu seçiliyken gösterilen kanal listesi.
/// Metin/sesli kanallar iki basit grupta, konum sırasına göre listelenir.
/// Kanal/rol/davet CRUD'u ve moderasyon Faz 6.6'da `ServerSettingsScreen`'e
/// taşındı (başlıktaki dişli/ok ikonuna dokunarak erişilir); okunmamış mesaj
/// rozetleri Faz 6.7'de eklendi (bkz. `notificationsControllerProvider`).
class ChannelListPanel extends ConsumerWidget {
  const ChannelListPanel({required this.serverId, this.selectedChannelId, super.key});

  final String serverId;
  final String? selectedChannelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(serverDetailProvider(serverId));

    return Container(
      color: AppColors.backgroundSecondary.withOpacity(0.6),
      child: detailAsync.when(
        data: (detail) {
          final textChannels = detail.channels.where((c) => !c.isVoice && !c.isCategory).toList();
          final voiceChannels = detail.channels.where((c) => c.isVoice).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        detail.server.name,
                        style: AppTextStyles.title,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.push(AppRoutes.serverSettingsPath(serverId)),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.expand_more_rounded, color: AppColors.textSecondary, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.glassBorder),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (textChannels.isNotEmpty) ...[
                      const _GroupLabel('METİN KANALLARI'),
                      for (final channel in textChannels)
                        _ChannelTile(
                          channel: channel,
                          isSelected: channel.id == selectedChannelId,
                          onTap: () => context.go(AppRoutes.channelPath(serverId, channel.id)),
                        ),
                    ],
                    if (voiceChannels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const _GroupLabel('SESLİ KANALLAR'),
                      for (final channel in voiceChannels)
                        _ChannelTile(
                          channel: channel,
                          isSelected: channel.id == selectedChannelId,
                          onTap: () => context.go(AppRoutes.channelPath(serverId, channel.id)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
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
                Text('Kanallar yüklenemedi.', style: AppTextStyles.caption, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(serverDetailProvider(serverId)),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(label, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  const _ChannelTile({required this.channel, required this.isSelected, required this.onTap});

  final Channel channel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = channel.isVoice
        ? 0
        : ref.watch(notificationsControllerProvider).unreadFor('channel:${channel.id}');

    return Material(
      color: isSelected ? AppColors.backgroundElevated : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              Icon(
                channel.isVoice ? Icons.volume_up_rounded : Icons.tag_rounded,
                size: 18,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  channel.name,
                  style: (isSelected || unread > 0 ? AppTextStyles.bodyMedium : AppTextStyles.body).copyWith(
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unread > 0)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: const BoxDecoration(color: AppColors.statusDnd, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
