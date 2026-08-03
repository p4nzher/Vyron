import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/glass_container.dart';
import '../../../../../core/widgets/gradient_button.dart';
import '../../../domain/invite.dart';
import '../../controllers/servers_providers.dart';

class InvitesTab extends ConsumerWidget {
  const InvitesTab({required this.serverId, super.key});
  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitesAsync = ref.watch(serverInvitesProvider(serverId));

    return Column(
      children: [
        Expanded(
          child: invitesAsync.when(
            data: (invites) {
              if (invites.isEmpty) {
                return Center(child: Text('Henüz aktif davet yok.', style: AppTextStyles.caption));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: invites.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _InviteRow(serverId: serverId, invite: invites[index]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
            error: (error, _) => Center(child: Text('Davetler yüklenemedi.', style: AppTextStyles.caption)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: GradientButton(
            label: 'Yeni Davet Oluştur',
            icon: Icons.add_link_rounded,
            onPressed: () => _showCreateInviteSheet(context, ref, serverId),
          ),
        ),
      ],
    );
  }
}

Future<void> _showCreateInviteSheet(BuildContext context, WidgetRef ref, String serverId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _CreateInviteSheet(serverId: serverId),
        ),
      ),
    ),
  );
}

class _InviteRow extends ConsumerWidget {
  const _InviteRow({required this.serverId, required this.invite});
  final String serverId;
  final Invite invite;

  String _formatExpiry() {
    if (invite.expiresAt == null) return 'Süresiz';
    if (invite.isExpired) return 'Süresi doldu';
    final remaining = invite.expiresAt!.difference(DateTime.now());
    if (remaining.inDays >= 1) return '${remaining.inDays} gün kaldı';
    if (remaining.inHours >= 1) return '${remaining.inHours} saat kaldı';
    return '${remaining.inMinutes} dakika kaldı';
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: invite.code));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Davet kodu kopyalandı: ${invite.code}', style: AppTextStyles.bodyMedium)),
      );
    }
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(invitesRepositoryProvider).revoke(serverId, invite.id);
      ref.invalidate(serverInvitesProvider(serverId));
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: invite.isActive ? AppColors.glassBorder : AppColors.statusDnd.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invite.code, style: AppTextStyles.mono(size: 16, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  '${invite.useCount}${invite.maxUses != null ? '/${invite.maxUses}' : ''} kullanım · ${_formatExpiry()}'
                  '${invite.createdByTag != null ? ' · ${invite.createdByTag}' : ''}',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: AppColors.textSecondary,
            onPressed: () => _copy(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.statusDnd,
            onPressed: () => _revoke(context, ref),
          ),
        ],
      ),
    );
  }
}

class _CreateInviteSheet extends ConsumerStatefulWidget {
  const _CreateInviteSheet({required this.serverId});
  final String serverId;

  @override
  ConsumerState<_CreateInviteSheet> createState() => _CreateInviteSheetState();
}

class _CreateInviteSheetState extends ConsumerState<_CreateInviteSheet> {
  int? _maxUses;
  int? _expiresInSeconds = 86400; // varsayılan: 1 gün
  bool _isSaving = false;
  String? _errorText;

  static const _usesOptions = <int?>[null, 1, 5, 10, 25, 50, 100];
  static const _expiryOptions = <int?, String>{
    1800: '30 dakika',
    3600: '1 saat',
    21600: '6 saat',
    86400: '1 gün',
    604800: '7 gün',
    null: 'Süresiz',
  };

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await ref.read(invitesRepositoryProvider).create(
            widget.serverId,
            maxUses: _maxUses,
            expiresInSeconds: _expiresInSeconds,
          );
      ref.invalidate(serverInvitesProvider(widget.serverId));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni Davet', style: AppTextStyles.heading(size: 20)),
          const SizedBox(height: 20),
          Text('Kullanım Limiti', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in _usesOptions)
                ChoiceChip(
                  label: Text(option == null ? 'Sınırsız' : '$option'),
                  selected: _maxUses == option,
                  onSelected: (_) => setState(() => _maxUses = option),
                  labelStyle: AppTextStyles.small.copyWith(
                    color: _maxUses == option ? Colors.white : AppColors.textSecondary,
                  ),
                  selectedColor: AppColors.brandGradientEnd,
                  backgroundColor: AppColors.backgroundElevated,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Geçerlilik Süresi', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _expiryOptions.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _expiresInSeconds == entry.key,
                  onSelected: (_) => setState(() => _expiresInSeconds = entry.key),
                  labelStyle: AppTextStyles.small.copyWith(
                    color: _expiresInSeconds == entry.key ? Colors.white : AppColors.textSecondary,
                  ),
                  selectedColor: AppColors.brandGradientEnd,
                  backgroundColor: AppColors.backgroundElevated,
                ),
            ],
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(_errorText!, style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
          ],
          const SizedBox(height: 20),
          GradientButton(label: 'Davet Oluştur', isLoading: _isSaving, onPressed: _submit),
        ],
      ),
    );
  }
}
