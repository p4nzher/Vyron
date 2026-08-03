import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../domain/server_ban.dart';
import '../../controllers/servers_providers.dart';

class BansTab extends ConsumerWidget {
  const BansTab({required this.serverId, super.key});
  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bansAsync = ref.watch(serverBansProvider(serverId));

    return bansAsync.when(
      data: (bans) {
        if (bans.isEmpty) {
          return Center(child: Text('Yasaklı üye yok.', style: AppTextStyles.caption));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: bans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _BanRow(serverId: serverId, ban: bans[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Yasaklı listesi yüklenemedi.', style: AppTextStyles.caption)),
    );
  }
}

class _BanRow extends ConsumerWidget {
  const _BanRow({required this.serverId, required this.ban});
  final String serverId;
  final ServerBan ban;

  Future<void> _unban(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(moderationRepositoryProvider).unban(serverId, ban.userId);
      ref.invalidate(serverBansProvider(serverId));
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: AppColors.statusDnd, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kullanıcı ID: ${ban.userId}', style: AppTextStyles.bodyMedium),
                if (ban.reason != null && ban.reason!.isNotEmpty)
                  Text(ban.reason!, style: AppTextStyles.caption)
                else
                  Text('Sebep belirtilmedi', style: AppTextStyles.small),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _unban(context, ref),
            child: Text('Yasağı Kaldır', style: AppTextStyles.small.copyWith(color: AppColors.brandGradientEnd)),
          ),
        ],
      ),
    );
  }
}
