import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/server_permissions.dart';
import '../controllers/servers_providers.dart';
import '../widgets/settings/audit_log_tab.dart';
import '../widgets/settings/bans_tab.dart';
import '../widgets/settings/channels_tab.dart';
import '../widgets/settings/invites_tab.dart';
import '../widgets/settings/members_tab.dart';
import '../widgets/settings/overview_tab.dart';
import '../widgets/settings/roles_tab.dart';

/// Sunucu yönetim ekranı — Faz 6.6 kapsamının kalbi. Görünen sekmeler
/// kullanıcının etkin yetkilerine göre değişir (bkz. `myServerPermissionsProvider`):
/// yetkisi olmayan bir üye sadece "Genel Bakış" (ayrılma) ve "Üyeler"i
/// (salt okunur listeleme) görür; backend zaten her uç noktayı ayrıca
/// yetki kontrolünden geçirir, bu sadece UI gürültüsünü azaltır.
class ServerSettingsScreen extends ConsumerWidget {
  const ServerSettingsScreen({required this.serverId, super.key});

  final String serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(serverDetailProvider(serverId));
    final perms = ref.watch(myServerPermissionsProvider(serverId));

    final tabs = <_SettingsTab>[
      _SettingsTab('Genel Bakış', Icons.info_outline_rounded, (_) => OverviewTab(serverId: serverId)),
      if (perms.has(ServerPermission.manageChannels))
        _SettingsTab('Kanallar', Icons.tag_rounded, (_) => ChannelsTab(serverId: serverId)),
      if (perms.has(ServerPermission.manageRoles))
        _SettingsTab('Roller', Icons.shield_outlined, (_) => RolesTab(serverId: serverId)),
      if (perms.has(ServerPermission.manageInvites) || perms.has(ServerPermission.createInvite))
        _SettingsTab('Davetler', Icons.link_rounded, (_) => InvitesTab(serverId: serverId)),
      _SettingsTab('Üyeler', Icons.people_outline_rounded, (_) => MembersTab(serverId: serverId)),
      if (perms.has(ServerPermission.banMembers))
        _SettingsTab('Yasaklılar', Icons.block_rounded, (_) => BansTab(serverId: serverId)),
      if (perms.has(ServerPermission.viewAuditLog))
        _SettingsTab('Denetim Kaydı', Icons.history_rounded, (_) => AuditLogTab(serverId: serverId)),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundSecondary,
          title: Text(
            detailAsync.valueOrNull?.server.name ?? 'Sunucu Ayarları',
            style: AppTextStyles.title,
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: AppColors.brandGradientEnd,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: [for (final tab in tabs) Tab(icon: Icon(tab.icon, size: 18), text: tab.label)],
          ),
        ),
        body: detailAsync.when(
          data: (_) => TabBarView(children: [for (final tab in tabs) tab.builder(context)]),
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
          ),
          error: (error, _) => Center(
            child: Text('Sunucu bilgisi yüklenemedi.', style: AppTextStyles.caption),
          ),
        ),
      ),
    );
  }
}

class _SettingsTab {
  const _SettingsTab(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final Widget Function(BuildContext) builder;
}
