import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/notification_prefs_controller.dart';

/// Faz 6.7 - Ayarlar hub'i. Rayin alt-sol avatarina dokununca acilir (bkz.
/// `app_rail.dart`). Alt bolumlere derinlemesine gitmek yerine (or. ayri
/// "Guvenlik ekrani", "Bildirim ekrani") her seyi tek bir kaydirilabilir
/// sayfada gruplar - Discord'un mobil ayarlar sekmesine daha yakin bir
/// deneyim ve az sayida ekranla bakimi kolay tutar.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: Text(title, style: AppTextStyles.title),
        content: Text(message, style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel, style: const TextStyle(color: AppColors.statusDnd)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final prefs = ref.watch(notificationPrefsControllerProvider);

    if (user == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text('Ayarlar', style: AppTextStyles.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.backgroundPrimary,
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null
                      ? Text(user.username.substring(0, 1).toUpperCase(), style: AppTextStyles.title)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName ?? user.username, style: AppTextStyles.title),
                      Text(user.tag, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.profileEdit),
                  child: const Text('Düzenle'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('GÜVENLİK'),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    user.twoFactorEnabled ? Icons.verified_user_rounded : Icons.shield_outlined,
                    color: user.twoFactorEnabled ? AppColors.statusOnline : AppColors.textSecondary,
                  ),
                  title: Text('İki Faktörlü Doğrulama', style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    user.twoFactorEnabled ? 'Etkin' : 'Devre dışı — hesabını daha güvenli yap',
                    style: AppTextStyles.small,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  onTap: () async {
                    if (user.twoFactorEnabled) {
                      await _confirmAndRun(
                        context,
                        ref,
                        title: '2FA Devre Dışı Bırakılsın mı?',
                        message: 'Hesabın artık sadece şifrenle korunacak.',
                        confirmLabel: 'Devre Dışı Bırak',
                        action: () async {
                          await ref.read(authRepositoryProvider).disable2fa();
                          ref.read(authControllerProvider.notifier).updateUser(user.copyWith(twoFactorEnabled: false));
                        },
                      );
                    } else {
                      if (context.mounted) context.push(AppRoutes.twoFactorSetup);
                    }
                  },
                ),
                const Divider(height: 1, color: AppColors.glassBorder, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.block_rounded, color: AppColors.textSecondary),
                  title: Text('Engellenen Kullanıcılar', style: AppTextStyles.bodyMedium),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  onTap: () => context.push(AppRoutes.friends),
                ),
                const Divider(height: 1, color: AppColors.glassBorder, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.devices_other_rounded, color: AppColors.statusDnd),
                  title: Text(
                    'Tüm Cihazlardan Çıkış Yap',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.statusDnd),
                  ),
                  subtitle: Text('Bu cihaz dahil, tüm oturumları sonlandırır.', style: AppTextStyles.small),
                  onTap: () => _confirmAndRun(
                    context,
                    ref,
                    title: 'Tüm Cihazlardan Çıkış Yap',
                    message: 'Bu işlem, bu cihaz dahil tüm aktif oturumları sonlandırır. Emin misin?',
                    confirmLabel: 'Çıkış Yap',
                    action: () => ref.read(authControllerProvider.notifier).logoutEverywhere(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('BİLDİRİMLER'),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(
              children: [
                SwitchListTile(
                  value: prefs.popupsEnabled,
                  onChanged: (v) => ref.read(notificationPrefsControllerProvider.notifier).setPopupsEnabled(v),
                  activeColor: AppColors.brandGradientEnd,
                  title: Text('Anlık Bildirimler', style: AppTextStyles.bodyMedium),
                  subtitle: Text('Uygulama açıkken yeni mesaj/istek bildirimleri göster', style: AppTextStyles.small),
                ),
                SwitchListTile(
                  value: prefs.soundsEnabled,
                  onChanged: (v) => ref.read(notificationPrefsControllerProvider.notifier).setSoundsEnabled(v),
                  activeColor: AppColors.brandGradientEnd,
                  title: Text('Bildirim Sesi', style: AppTextStyles.bodyMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    'Not: bunlar uygulama açıkken (ön planda veya arka planda çalışırken) çalışan '
                    'yerel bildirimlerdir. Uygulama tamamen kapalıyken bildirim almak için bir '
                    'push sunucusu (FCM/APNs) entegrasyonu gerekir — bu henüz eklenmedi.',
                    style: AppTextStyles.small,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('HESAP'),
          GlassContainer(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.statusDnd),
              title: Text('Çıkış Yap', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.statusDnd)),
              onTap: () => _confirmAndRun(
                context,
                ref,
                title: 'Çıkış Yap',
                message: 'Bu cihazdaki oturumun kapatılacak.',
                confirmLabel: 'Çıkış Yap',
                action: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(label, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}
