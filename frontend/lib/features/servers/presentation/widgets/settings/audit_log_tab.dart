import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../controllers/servers_providers.dart';

class AuditLogTab extends ConsumerWidget {
  const AuditLogTab({required this.serverId, super.key});
  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(serverAuditLogProvider(serverId));

    return logAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Center(child: Text('Henüz bir kayıt yok.', style: AppTextStyles.caption));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.glassBorder, height: 20),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  '${entry.userTag ?? 'Sistem'} · ${entry.createdAt.toLocal()}',
                  style: AppTextStyles.small,
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Denetim kaydı yüklenemedi.', style: AppTextStyles.caption)),
    );
  }
}
