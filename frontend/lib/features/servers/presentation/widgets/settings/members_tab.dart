import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/api_exception.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/widgets/glass_container.dart';
import '../../../../../core/widgets/status_dot.dart';
import '../../../../auth/presentation/controllers/auth_controller.dart';
import '../../../domain/moderation_action.dart';
import '../../../domain/role.dart';
import '../../../domain/server_member.dart';
import '../../../domain/server_permissions.dart';
import '../../controllers/servers_providers.dart';

class MembersTab extends ConsumerWidget {
  const MembersTab({required this.serverId, super.key});
  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(serverMembersProvider(serverId));

    return membersAsync.when(
      data: (members) => ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _MemberRow(serverId: serverId, member: members[index]),
      ),
      loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary)),
      error: (error, _) => Center(child: Text('Üyeler yüklenemedi.', style: AppTextStyles.caption)),
    );
  }
}

class _MemberRow extends ConsumerWidget {
  const _MemberRow({required this.serverId, required this.member});
  final String serverId;
  final ServerMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    final isSelf = member.user.id == currentUserId;

    return Material(
      color: AppColors.backgroundElevated.withOpacity(0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isSelf ? null : () => _showMemberActionsSheet(context, serverId: serverId, member: member),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.glassBorder)),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.backgroundPrimary,
                    backgroundImage: member.user.avatarUrl != null ? NetworkImage(member.user.avatarUrl!) : null,
                    child: member.user.avatarUrl == null
                        ? Text(member.displayName.substring(0, 1).toUpperCase(), style: AppTextStyles.bodyMedium)
                        : null,
                  ),
                  if (member.user.status != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: StatusDot(status: member.user.status!, size: 10, borderColor: AppColors.backgroundElevated),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(member.displayName, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
                        ),
                        if (member.isTimedOut) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.timer_outlined, size: 14, color: AppColors.statusDnd),
                        ],
                      ],
                    ),
                    if (member.roles.where((r) => !r.isEveryone).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            for (final role in member.roles.where((r) => !r.isEveryone))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: role.displayColor.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  role.name,
                                  style: AppTextStyles.small.copyWith(color: role.displayColor),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (!isSelf) const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
              if (isSelf)
                Text('(sen)', style: AppTextStyles.small),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMemberActionsSheet(BuildContext context, {required String serverId, required ServerMember member}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _MemberActionsSheet(serverId: serverId, member: member),
          ),
        ),
      ),
    ),
  );
}

class _MemberActionsSheet extends ConsumerStatefulWidget {
  const _MemberActionsSheet({required this.serverId, required this.member});
  final String serverId;
  final ServerMember member;

  @override
  ConsumerState<_MemberActionsSheet> createState() => _MemberActionsSheetState();
}

class _MemberActionsSheetState extends ConsumerState<_MemberActionsSheet> {
  bool _isWorking = false;

  Future<void> _runAction(Future<void> Function() action, {String? successMessage}) async {
    setState(() => _isWorking = true);
    try {
      await action();
      ref.invalidate(serverMembersProvider(widget.serverId));
      ref.invalidate(serverBansProvider(widget.serverId));
      if (mounted) {
        Navigator.of(context).pop();
        if (successMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
        }
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<String?> _promptReason(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.backgroundElevated,
        title: Text(title, style: AppTextStyles.title),
        content: AppTextField(label: 'Sebep (opsiyonel)', controller: controller, maxLines: 2),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Devam Et'),
          ),
        ],
      ),
    );
  }

  Future<void> _kick() async {
    final reason = await _promptReason('Üyeyi At');
    if (reason == null) return;
    await _runAction(
      () => ref.read(moderationRepositoryProvider).kick(widget.serverId, widget.member.user.id, reason: reason),
      successMessage: '${widget.member.displayName} sunucudan atıldı.',
    );
  }

  Future<void> _ban() async {
    final reason = await _promptReason('Üyeyi Yasakla');
    if (reason == null) return;
    await _runAction(
      () => ref.read(moderationRepositoryProvider).ban(widget.serverId, widget.member.user.id, reason: reason),
      successMessage: '${widget.member.displayName} yasaklandı.',
    );
  }

  Future<void> _warn() async {
    final reason = await _promptReason('Üyeyi Uyar');
    if (reason == null) return;
    await _runAction(
      () => ref.read(moderationRepositoryProvider).warn(widget.serverId, widget.member.user.id, reason: reason),
      successMessage: '${widget.member.displayName} uyarıldı.',
    );
  }

  Future<void> _timeout(int seconds, String label) async {
    await _runAction(
      () => ref.read(moderationRepositoryProvider).timeout(widget.serverId, widget.member.user.id, durationSeconds: seconds),
      successMessage: '${widget.member.displayName} $label susturuldu.',
    );
  }

  Future<void> _removeTimeout() async {
    await _runAction(
      () => ref.read(moderationRepositoryProvider).removeTimeout(widget.serverId, widget.member.user.id),
      successMessage: 'Susturma kaldırıldı.',
    );
  }

  Future<void> _toggleRole(Role role, bool assign) async {
    setState(() => _isWorking = true);
    try {
      if (assign) {
        await ref.read(rolesRepositoryProvider).assignToMember(widget.serverId, widget.member.id, role.id);
      } else {
        await ref.read(rolesRepositoryProvider).removeFromMember(widget.serverId, widget.member.id, role.id);
      }
      ref.invalidate(serverMembersProvider(widget.serverId));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.7,
            child: _MemberHistorySheet(serverId: widget.serverId, userId: widget.member.user.id),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(myServerPermissionsProvider(widget.serverId));
    final detail = ref.watch(serverDetailProvider(widget.serverId)).valueOrNull;
    final assignableRoles = detail?.roles.where((r) => !r.isEveryone).toList() ?? [];
    final memberRoleIds = widget.member.roles.map((r) => r.id).toSet();

    // Hiyerarşi kontrolü: sahip değilsen, hedeften eşit/daha yüksek rütbeliye
    // işlem uygulanamaz (bkz. backend `assertCanModerate`) — sadece UI ipucu,
    // nihai kontrol backend'de.
    final canModerateTarget = perms.isOwner || perms.highestPosition > widget.member.roles
        .map((r) => r.position)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.backgroundPrimary,
                backgroundImage: widget.member.user.avatarUrl != null ? NetworkImage(widget.member.user.avatarUrl!) : null,
                child: widget.member.user.avatarUrl == null
                    ? Text(widget.member.displayName.substring(0, 1).toUpperCase(), style: AppTextStyles.title)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.member.displayName, style: AppTextStyles.title),
                    Text(widget.member.user.tag, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                if (perms.has(ServerPermission.manageRoles) && assignableRoles.isNotEmpty) ...[
                  Text('Roller', style: AppTextStyles.caption),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final role in assignableRoles)
                        FilterChip(
                          label: Text(role.name),
                          selected: memberRoleIds.contains(role.id),
                          onSelected: _isWorking ? null : (v) => _toggleRole(role, v),
                          selectedColor: role.displayColor.withOpacity(0.35),
                          backgroundColor: AppColors.backgroundElevated,
                          labelStyle: AppTextStyles.small.copyWith(color: AppColors.textPrimary),
                        ),
                    ],
                  ),
                  const Divider(height: 28, color: AppColors.glassBorder),
                ],
                if (!canModerateTarget)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Bu üye senden eşit veya daha yüksek rütbeli — moderasyon işlemleri backend tarafından reddedilecektir.',
                      style: AppTextStyles.small,
                    ),
                  ),
                if (perms.has(ServerPermission.viewAuditLog))
                  _ActionTile(icon: Icons.history_rounded, label: 'Moderasyon Geçmişi', onTap: _showHistory),
                if (perms.has(ServerPermission.timeoutMembers)) ...[
                  _ActionTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'Uyar',
                    enabled: !_isWorking && canModerateTarget,
                    onTap: _warn,
                  ),
                  if (widget.member.isTimedOut)
                    _ActionTile(
                      icon: Icons.timer_off_outlined,
                      label: 'Susturmayı Kaldır',
                      enabled: !_isWorking && canModerateTarget,
                      onTap: _removeTimeout,
                    )
                  else
                    _ActionTile(
                      icon: Icons.timer_outlined,
                      label: 'Sustur',
                      enabled: !_isWorking && canModerateTarget,
                      onTap: () => _showTimeoutOptions(context),
                    ),
                ],
                if (perms.has(ServerPermission.kickMembers))
                  _ActionTile(
                    icon: Icons.person_remove_outlined,
                    label: 'Sunucudan At',
                    color: AppColors.statusDnd,
                    enabled: !_isWorking && canModerateTarget,
                    onTap: _kick,
                  ),
                if (perms.has(ServerPermission.banMembers))
                  _ActionTile(
                    icon: Icons.block_rounded,
                    label: 'Yasakla',
                    color: AppColors.statusDnd,
                    enabled: !_isWorking && canModerateTarget,
                    onTap: _ban,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTimeoutOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundElevated,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in const [
              [60 * 5, '5 dakika'],
              [60 * 10, '10 dakika'],
              [60 * 60, '1 saat'],
              [60 * 60 * 24, '1 gün'],
              [60 * 60 * 24 * 7, '7 gün'],
            ])
              ListTile(
                title: Text(option[1] as String, style: AppTextStyles.body),
                onTap: () {
                  Navigator.of(context).pop();
                  _timeout(option[0] as int, option[1] as String);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.color, this.enabled = true});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? (color ?? AppColors.textPrimary) : AppColors.textSecondary.withOpacity(0.4);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: fg, size: 20),
      title: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: fg)),
      onTap: enabled ? onTap : null,
    );
  }
}

class _MemberHistorySheet extends ConsumerWidget {
  const _MemberHistorySheet({required this.serverId, required this.userId});
  final String serverId;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyFuture = ref.watch(moderationRepositoryProvider).history(serverId, userId);

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Moderasyon Geçmişi', style: AppTextStyles.heading(size: 18)),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<ModerationAction>>(
              future: historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary));
                }
                final actions = snapshot.data ?? [];
                if (actions.isEmpty) {
                  return Center(child: Text('Kayıtlı bir geçmiş yok.', style: AppTextStyles.caption));
                }
                return ListView.separated(
                  itemCount: actions.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.glassBorder, height: 20),
                  itemBuilder: (context, index) {
                    final action = actions[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(action.label, style: AppTextStyles.bodyMedium),
                        if (action.reason != null && action.reason!.isNotEmpty)
                          Text(action.reason!, style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(
                          '${action.actorTag ?? 'Bilinmeyen'} · ${action.createdAt.toLocal()}',
                          style: AppTextStyles.small,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
