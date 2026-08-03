import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/router/app_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/glass_container.dart';
import '../../../../../core/widgets/gradient_button.dart';
import '../../../../auth/presentation/controllers/auth_controller.dart';
import '../../../domain/server_permissions.dart';
import '../../controllers/servers_providers.dart';

class OverviewTab extends ConsumerStatefulWidget {
  const OverviewTab({required this.serverId, super.key});
  final String serverId;

  @override
  ConsumerState<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<OverviewTab> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _initialized = false;
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await ref.read(serversRepositoryProvider).update(
            widget.serverId,
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
          );
      ref.invalidate(serverDetailProvider(widget.serverId));
      ref.invalidate(serverListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sunucu ayarları kaydedildi.', style: AppTextStyles.bodyMedium)),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await _confirmDialog(
      title: 'Sunucuyu Sil',
      message: 'Bu işlem GERİ ALINAMAZ. Tüm kanallar, mesajlar ve roller kalıcı olarak silinecek.',
      confirmLabel: 'Sil',
    );
    if (confirmed != true) return;
    try {
      await ref.read(serversRepositoryProvider).delete(widget.serverId);
      ref.invalidate(serverListProvider);
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _confirmAndLeave() async {
    final confirmed = await _confirmDialog(
      title: 'Sunucudan Ayrıl',
      message: 'Bu sunucudan ayrılmak istediğine emin misin? Tekrar girmek için yeni bir davete ihtiyacın olacak.',
      confirmLabel: 'Ayrıl',
    );
    if (confirmed != true) return;
    try {
      await ref.read(serversRepositoryProvider).leave(widget.serverId);
      ref.invalidate(serverListProvider);
      if (!mounted) return;
      context.go(AppRoutes.home);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<bool?> _confirmDialog({required String title, required String message, required String confirmLabel}) {
    return showDialog<bool>(
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
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(serverDetailProvider(widget.serverId));
    final perms = ref.watch(myServerPermissionsProvider(widget.serverId));
    final currentUserId = ref.watch(authControllerProvider).user?.id;

    return detailAsync.when(
      data: (detail) {
        if (!_initialized) {
          _nameController.text = detail.server.name;
          _descriptionController.text = detail.server.description ?? '';
          _initialized = true;
        }
        final isOwner = detail.server.ownerId == currentUserId;
        final canManage = perms.has(ServerPermission.manageServer);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Sunucu Bilgileri', style: AppTextStyles.title),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Sunucu adı',
                    controller: _nameController,
                    errorText: _errorText,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Açıklama',
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: 300,
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 16),
                    GradientButton(label: 'Kaydet', isLoading: _isSaving, onPressed: _save),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tehlikeli Bölge', style: AppTextStyles.title.copyWith(color: AppColors.statusDnd)),
                  const SizedBox(height: 12),
                  if (isOwner)
                    OutlinedButton.icon(
                      onPressed: _confirmAndDelete,
                      icon: const Icon(Icons.delete_forever_rounded, color: AppColors.statusDnd),
                      label: Text('Sunucuyu Sil', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.statusDnd)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.statusDnd)),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _confirmAndLeave,
                      icon: const Icon(Icons.logout_rounded, color: AppColors.statusDnd),
                      label: Text('Sunucudan Ayrıl', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.statusDnd)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.statusDnd)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Sunucu yüklenemedi.', style: AppTextStyles.caption)),
    );
  }
}
