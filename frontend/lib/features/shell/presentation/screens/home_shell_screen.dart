import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../dm/presentation/controllers/dm_providers.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../servers/presentation/controllers/servers_providers.dart';
import '../../../voice/presentation/widgets/voice_call_bar.dart';
import '../widgets/app_rail.dart';
import '../widgets/channel_list_panel.dart';
import '../widgets/content_panel.dart';
import '../widgets/dm_list_panel.dart';

/// Geniş ekranda sunucu rayı + kanal/DM listesi + içerik panelinin aynı
/// anda göründüğü sabit üç sütun; dar ekranda tek sütun + rayın [Drawer]'a
/// taşındığı, geri okuyla gezinilen adaptif düzen (bkz. `frontend/README.md`
/// — Faz 6.3 açıklaması).
///
/// Seçim durumu (hangi sunucu/DM/kanal açık) kasıtlı olarak `go_router` yol
/// parametrelerinden okunur — ayrı bir "seçim state'i" tutulmaz. Böylece
/// tarayıcıda geri/ileri tuşları ve derin bağlantılar (`/home/servers/...`)
/// doğru şekilde çalışır.
class HomeShellScreen extends ConsumerWidget {
  const HomeShellScreen({this.serverId, this.channelId, this.dmChannelId, super.key});

  static const double _wideBreakpoint = 860;

  final String? serverId;
  final String? channelId;
  final String? dmChannelId;

  bool get isDmSpace => serverId == null;
  bool get _hasContentSelection => channelId != null || dmChannelId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authControllerProvider).user?.id;
    // `notificationsControllerProvider` GLOBAL bir provider — burada watch
    // edilmesi, kullanıcı ana kabuğa ulaştığı an bir kez kurulup oturum
    // boyunca canlı kalmasını sağlar (bkz. `notifications_controller.dart`
    // mimari notu, `VoiceCallBar` ile aynı desen).
    ref.watch(notificationsControllerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        if (isWide) return _buildWide(context, ref, currentUserId);
        return _buildNarrow(context, ref, currentUserId);
      },
    );
  }

  Widget _buildWide(BuildContext context, WidgetRef ref, String? currentUserId) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Row(
        children: [
          SizedBox(width: 72, child: AppRail(isDmSpace: isDmSpace, selectedServerId: serverId)),
          const VerticalDivider(width: 1, color: AppColors.glassBorder),
          SizedBox(width: 280, child: _secondaryPanel()),
          const VerticalDivider(width: 1, color: AppColors.glassBorder),
          Expanded(child: _contentPanel(ref, currentUserId)),
        ],
      ),
      bottomNavigationBar: const VoiceCallBar(),
    );
  }

  Widget _buildNarrow(BuildContext context, WidgetRef ref, String? currentUserId) {
    if (_hasContentSelection) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundSecondary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(isDmSpace ? AppRoutes.home : AppRoutes.serverPath(serverId!)),
          ),
          title: Text(_narrowTitle(ref, currentUserId), style: AppTextStyles.title),
        ),
        body: _contentPanel(ref, currentUserId),
        bottomNavigationBar: const VoiceCallBar(),
      );
    }

    // Sunucu seçili ama kanal seçilmemiş → kanal listesi tam ekran.
    if (serverId != null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundSecondary,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.backgroundSecondary,
          width: 88,
          child: AppRail(isDmSpace: isDmSpace, selectedServerId: serverId),
        ),
        body: _secondaryPanel(),
        bottomNavigationBar: const VoiceCallBar(),
      );
    }

    // Ne sunucu ne DM detayı seçili → DM listesi ana ekran.
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        backgroundColor: AppColors.backgroundSecondary,
        width: 88,
        child: AppRail(isDmSpace: isDmSpace, selectedServerId: serverId),
      ),
      body: _secondaryPanel(),
      bottomNavigationBar: const VoiceCallBar(),
    );
  }

  Widget _secondaryPanel() {
    if (!isDmSpace) {
      return ChannelListPanel(serverId: serverId!, selectedChannelId: channelId);
    }
    return DmListPanel(selectedDmChannelId: dmChannelId);
  }

  Widget _contentPanel(WidgetRef ref, String? currentUserId) {
    if (channelId != null && serverId != null) {
      final detail = ref.watch(serverDetailProvider(serverId!)).valueOrNull;
      final channel = detail?.channels.where((c) => c.id == channelId).toList();
      return ContentPanel(
        channel: channel != null && channel.isNotEmpty ? channel.first : null,
        currentUserId: currentUserId,
        serverId: serverId,
      );
    }
    if (dmChannelId != null) {
      final list = ref.watch(dmListProvider).valueOrNull;
      final match = list?.where((c) => c.id == dmChannelId).toList();
      return ContentPanel(
        dmChannel: match != null && match.isNotEmpty ? match.first : null,
        currentUserId: currentUserId,
      );
    }
    return const ContentPanel();
  }

  String _narrowTitle(WidgetRef ref, String? currentUserId) {
    if (channelId != null && serverId != null) {
      final detail = ref.watch(serverDetailProvider(serverId!)).valueOrNull;
      final match = detail?.channels.where((c) => c.id == channelId).toList();
      if (match != null && match.isNotEmpty) return '# ${match.first.name}';
      return '';
    }
    if (dmChannelId != null && currentUserId != null) {
      final list = ref.watch(dmListProvider).valueOrNull;
      final match = list?.where((c) => c.id == dmChannelId).toList();
      if (match != null && match.isNotEmpty) return match.first.displayName(currentUserId);
    }
    return '';
  }
}
