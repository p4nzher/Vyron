import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/glass_container.dart';
import '../../../../../core/widgets/gradient_button.dart';
import '../../../domain/role.dart';
import '../../../domain/server_permissions.dart';
import '../../controllers/servers_providers.dart';

class RolesTab extends ConsumerWidget {
  const RolesTab({required this.serverId, super.key});
  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(serverDetailProvider(serverId));

    return detailAsync.when(
      data: (detail) {
        final roles = detail.roles; // zaten position'a göre azalan sırada
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _RoleRow(serverId: serverId, role: roles[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                label: 'Rol Oluştur',
                icon: Icons.add_rounded,
                onPressed: () => _showRoleEditor(context, serverId: serverId),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Roller yüklenemedi.', style: AppTextStyles.caption)),
    );
  }
}

Future<void> _showRoleEditor(BuildContext context, {required String serverId, Role? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _RoleEditorSheet(serverId: serverId, existing: existing),
          ),
        ),
      ),
    ),
  );
}

class _RoleRow extends ConsumerWidget {
  const _RoleRow({required this.serverId, required this.role});
  final String serverId;
  final Role role;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: Text('"${role.name}" silinsin mi?', style: AppTextStyles.title),
        content: Text('Bu role sahip üyeler rolü kaybedecek.', style: AppTextStyles.body),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil', style: TextStyle(color: AppColors.statusDnd)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(rolesRepositoryProvider).remove(serverId, role.id);
      ref.invalidate(serverDetailProvider(serverId));
      ref.invalidate(serverMembersProvider(serverId));
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.backgroundElevated.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showRoleEditor(context, serverId: serverId, existing: role),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: role.displayColor, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(role.name, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
              if (!role.isEveryone)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: AppColors.statusDnd,
                  onPressed: () => _delete(context, ref),
                ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleEditorSheet extends ConsumerStatefulWidget {
  const _RoleEditorSheet({required this.serverId, this.existing});
  final String serverId;
  final Role? existing;

  @override
  ConsumerState<_RoleEditorSheet> createState() => _RoleEditorSheetState();
}

class _RoleEditorSheetState extends ConsumerState<_RoleEditorSheet> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? 'Yeni Rol');
  late Map<String, bool> _permissions = {...(widget.existing?.permissions ?? {})};
  late Color _color = widget.existing?.displayColor ?? const Color(0xFF99AAB5);
  late bool _isHoisted = widget.existing?.isHoisted ?? false;
  late bool _isMentionable = widget.existing?.isMentionable ?? true;
  bool _isSaving = false;
  String? _errorText;

  bool get _isEditing => widget.existing != null;
  bool get _isEveryone => widget.existing?.isEveryone ?? false;

  static const _palette = [
    Color(0xFF99AAB5),
    Color(0xFFE9E4FF),
    Color(0xFF4C5FD5),
    Color(0xFF9F7AEA),
    Color(0xFF4ADE80),
    Color(0xFFFBBF24),
    Color(0xFFF87171),
    Color(0xFF38BDF8),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _colorHex(Color c) => '#${c.value.toRadixString(16).substring(2).toUpperCase()}';

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Rol adı gerekli.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      if (_isEditing) {
        await ref.read(rolesRepositoryProvider).update(
              widget.serverId,
              widget.existing!.id,
              name: _isEveryone ? null : name,
              color: _colorHex(_color),
              permissions: _permissions,
              isHoisted: _isHoisted,
              isMentionable: _isMentionable,
            );
      } else {
        await ref.read(rolesRepositoryProvider).create(
              widget.serverId,
              name: name,
              color: _colorHex(_color),
              permissions: _permissions,
              isHoisted: _isHoisted,
              isMentionable: _isMentionable,
            );
      }
      ref.invalidate(serverDetailProvider(widget.serverId));
      ref.invalidate(serverMembersProvider(widget.serverId));
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isEditing ? 'Rolü Düzenle' : 'Yeni Rol', style: AppTextStyles.heading(size: 20)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                AppTextField(
                  label: 'Rol adı',
                  controller: _nameController,
                  errorText: _errorText,
                  maxLength: 50,
                ),
                if (_isEveryone)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('@everyone rolünün adı değiştirilemez.', style: AppTextStyles.small),
                  ),
                const SizedBox(height: 16),
                Text('Renk', style: AppTextStyles.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _palette)
                      InkWell(
                        onTap: () => setState(() => _color = c),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color.value == c.value ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isHoisted,
                  onChanged: (v) => setState(() => _isHoisted = v),
                  title: Text('Üye listesinde ayrı göster', style: AppTextStyles.bodyMedium),
                  activeColor: AppColors.brandGradientEnd,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isMentionable,
                  onChanged: (v) => setState(() => _isMentionable = v),
                  title: Text('Etiketlenebilir', style: AppTextStyles.bodyMedium),
                  activeColor: AppColors.brandGradientEnd,
                ),
                const SizedBox(height: 8),
                Text('Yetkiler', style: AppTextStyles.title),
                const SizedBox(height: 4),
                for (final group in serverPermissionGroups) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(group.label, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  for (final perm in group.permissions)
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _permissions[perm] == true,
                      onChanged: (v) => setState(() => _permissions[perm] = v),
                      title: Text(serverPermissionLabels[perm] ?? perm, style: AppTextStyles.body),
                      activeColor: AppColors.brandGradientEnd,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(label: _isEditing ? 'Kaydet' : 'Oluştur', isLoading: _isSaving, onPressed: _submit),
        ],
      ),
    );
  }
}
