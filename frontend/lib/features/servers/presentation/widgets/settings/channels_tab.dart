import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/glass_container.dart';
import '../../../../../core/widgets/gradient_button.dart';
import '../../../domain/channel.dart';
import '../../controllers/servers_providers.dart';

class ChannelsTab extends ConsumerWidget {
  const ChannelsTab({required this.serverId, super.key});
  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(serverDetailProvider(serverId));

    return detailAsync.when(
      data: (detail) {
        final channels = [...detail.channels]..sort((a, b) => a.position.compareTo(b.position));
        return Column(
          children: [
            Expanded(
              child: channels.isEmpty
                  ? Center(child: Text('Henüz kanal yok.', style: AppTextStyles.caption))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: channels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _ChannelRow(
                        serverId: serverId,
                        channel: channels[index],
                        canMoveUp: index > 0,
                        canMoveDown: index < channels.length - 1,
                        onMoveUp: () => _swap(ref, channels, index, index - 1),
                        onMoveDown: () => _swap(ref, channels, index, index + 1),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                label: 'Kanal Oluştur',
                icon: Icons.add_rounded,
                expand: true,
                onPressed: () => _showChannelEditor(context, ref, serverId: serverId, channels: channels),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Kanallar yüklenemedi.', style: AppTextStyles.caption)),
    );
  }

  Future<void> _swap(WidgetRef ref, List<Channel> channels, int a, int b) async {
    final reordered = [...channels];
    final tmp = reordered[a];
    reordered[a] = reordered[b];
    reordered[b] = tmp;
    final items = [
      for (var i = 0; i < reordered.length; i++)
        {'id': reordered[i].id, 'position': i, 'parentId': reordered[i].parentId},
    ];
    try {
      await ref.read(channelsRepositoryProvider).reorder(serverId, items);
    } finally {
      ref.invalidate(serverDetailProvider(serverId));
    }
  }
}

Future<void> _showChannelEditor(
  BuildContext context,
  WidgetRef ref, {
  required String serverId,
  required List<Channel> channels,
  Channel? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _ChannelEditorSheet(serverId: serverId, channels: channels, existing: existing),
        ),
      ),
    ),
  );
}

class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({
    required this.serverId,
    required this.channel,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final String serverId;
  final Channel channel;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  IconData get _icon {
    if (channel.isCategory) return Icons.folder_outlined;
    if (channel.isVoice) return Icons.volume_up_rounded;
    return Icons.tag_rounded;
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: Text('"${channel.name}" silinsin mi?', style: AppTextStyles.title),
        content: Text('Bu kanaldaki tüm mesajlar kalıcı olarak silinecek.', style: AppTextStyles.body),
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
      await ref.read(channelsRepositoryProvider).remove(serverId, channel.id);
      ref.invalidate(serverDetailProvider(serverId));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(channel.name, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
            color: canMoveUp ? AppColors.textSecondary : AppColors.textSecondary.withOpacity(0.2),
            onPressed: canMoveUp ? onMoveUp : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
            color: canMoveDown ? AppColors.textSecondary : AppColors.textSecondary.withOpacity(0.2),
            onPressed: canMoveDown ? onMoveDown : null,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.textSecondary,
            onPressed: () => _showChannelEditor(context, ref, serverId: serverId, channels: const [], existing: channel),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.statusDnd,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _ChannelEditorSheet extends ConsumerStatefulWidget {
  const _ChannelEditorSheet({required this.serverId, required this.channels, this.existing});
  final String serverId;
  final List<Channel> channels;
  final Channel? existing;

  @override
  ConsumerState<_ChannelEditorSheet> createState() => _ChannelEditorSheetState();
}

class _ChannelEditorSheetState extends ConsumerState<_ChannelEditorSheet> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _topicController = TextEditingController(text: widget.existing?.topic ?? '');
  late String _type = widget.existing?.type ?? 'TEXT';
  bool _isSaving = false;
  String? _errorText;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Kanal adı gerekli.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      if (_isEditing) {
        await ref.read(channelsRepositoryProvider).update(
              widget.serverId,
              widget.existing!.id,
              name: name,
              topic: _topicController.text.trim(),
            );
      } else {
        await ref.read(channelsRepositoryProvider).create(
              widget.serverId,
              name: name,
              type: _type,
              topic: _topicController.text.trim(),
            );
      }
      ref.invalidate(serverDetailProvider(widget.serverId));
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
          Text(_isEditing ? 'Kanalı Düzenle' : 'Yeni Kanal', style: AppTextStyles.heading(size: 20)),
          const SizedBox(height: 20),
          if (!_isEditing) ...[
            Text('Kanal Türü', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Row(
              children: [
                _TypeChip(label: 'Metin', icon: Icons.tag_rounded, value: 'TEXT', groupValue: _type,
                    onSelected: (v) => setState(() => _type = v)),
                const SizedBox(width: 8),
                _TypeChip(label: 'Sesli', icon: Icons.volume_up_rounded, value: 'VOICE', groupValue: _type,
                    onSelected: (v) => setState(() => _type = v)),
                const SizedBox(width: 8),
                _TypeChip(label: 'Kategori', icon: Icons.folder_outlined, value: 'CATEGORY', groupValue: _type,
                    onSelected: (v) => setState(() => _type = v)),
              ],
            ),
            const SizedBox(height: 16),
          ],
          AppTextField(
            label: 'Kanal adı',
            controller: _nameController,
            errorText: _errorText,
            autofocus: true,
            maxLength: 100,
          ),
          if (_type != 'CATEGORY' && _type != 'VOICE') ...[
            const SizedBox(height: 12),
            AppTextField(label: 'Konu (opsiyonel)', controller: _topicController, maxLines: 2, maxLength: 1024),
          ],
          const SizedBox(height: 20),
          GradientButton(
            label: _isEditing ? 'Kaydet' : 'Oluştur',
            isLoading: _isSaving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final String value;
  final String groupValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return Expanded(
      child: InkWell(
        onTap: () => onSelected(value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.backgroundElevated : Colors.transparent,
            gradient: selected ? AppColors.brandGradient : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(height: 4),
              Text(label, style: AppTextStyles.small.copyWith(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
