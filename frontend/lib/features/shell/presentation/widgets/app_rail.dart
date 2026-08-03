import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/status_dot.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../servers/domain/server.dart';
import '../../../servers/presentation/controllers/servers_providers.dart';
import '../../../servers/presentation/widgets/create_server_sheet.dart';

/// En soldaki dikey ikon rayı: DM girişi (okunmamış toplam rozetiyle),
/// katılınan sunucular (Faz 6.6'da kanal okunmamış rozetiyle) ve "sunucu
/// oluştur/katıl" butonu. Geniş ekranda sabit bir sütun, dar ekranda
/// [Drawer] içeriği olarak kullanılır (bkz. `HomeShellScreen`). Alttaki
/// avatar Faz 6.7'de Ayarlar hub'ına yönlendirecek şekilde güncellendi.
class AppRail extends ConsumerWidget {
  const AppRail({required this.isDmSpace, this.selectedServerId, super.key});

  final bool isDmSpace;
  final String? selectedServerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversAsync = ref.watch(serverListProvider);
    final user = ref.watch(authControllerProvider).user;

    return Container(
      color: AppColors.backgroundSecondary,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            _RailButton(
              tooltip: 'Direkt Mesajlar',
              isSelected: isDmSpace,
              onTap: () => context.go(AppRoutes.home),
              badgeCount: ref.watch(notificationsControllerProvider).totalUnread,
              child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Container(width: 32, height: 2, color: AppColors.glassBorder),
            const SizedBox(height: 8),
            Expanded(
              child: serversAsync.when(
                data: (servers) => ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    final selected = !isDmSpace && server.id == selectedServerId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _RailButton(
                        tooltip: server.name,
                        isSelected: selected,
                        onTap: () => context.go(AppRoutes.serverPath(server.id)),
                        child: _ServerIcon(server: server),
                      ),
                    );
                  },
                ),
                loading: () => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
                  ),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: IconButton(
                    tooltip: 'Sunucular yüklenemedi — tekrar dene',
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.statusDnd),
                    onPressed: () => ref.invalidate(serverListProvider),
                  ),
                ),
              ),
            ),
            _RailButton(
              tooltip: 'Sunucu Oluştur / Katıl',
              onTap: () => showCreateOrJoinServerSheet(context),
              child: const Icon(Icons.add_rounded, color: AppColors.statusOnline, size: 22),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => context.push(AppRoutes.appSettings),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.backgroundElevated,
                      backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                      child: user?.avatarUrl == null
                          ? Text(
                              _initial(user?.displayName ?? user?.username ?? '?'),
                              style: AppTextStyles.bodyMedium,
                            )
                          : null,
                    ),
                    if (user != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: StatusDot(status: user.status, size: 12, borderColor: AppColors.backgroundSecondary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

}

String _initial(String value) => value.isEmpty ? '?' : value.substring(0, 1).toUpperCase();

class _ServerIcon extends StatelessWidget {
  const _ServerIcon({required this.server});

  final Server server;

  @override
  Widget build(BuildContext context) {
    if (server.iconUrl != null) {
      return ClipOval(
        child: Image.network(server.iconUrl!, fit: BoxFit.cover, width: 48, height: 48),
      );
    }
    return Center(
      child: Text(server.initials, style: AppTextStyles.bodyMedium.copyWith(fontSize: 14)),
    );
  }
}

/// Discord'daki "seçiliyken daireden yuvarlak kareye morfing" davranışının
/// sadeleştirilmiş hali: seçili ikon köşeleri yumuşak bir kareye döner ve
/// solunda ince bir gösterge çubuğu belirir.
class _RailButton extends StatelessWidget {
  const _RailButton({required this.child, required this.onTap, this.tooltip, this.isSelected = false, this.badgeCount = 0});

  final Widget child;
  final VoidCallback onTap;
  final String? tooltip;
  final bool isSelected;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final button = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppMotion.fast,
          width: 4,
          height: isSelected ? 28 : 0,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: AppColors.brandAccent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(isSelected ? 16 : 24),
            child: AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.backgroundElevated : AppColors.backgroundElevated.withOpacity(0.5),
                gradient: isSelected ? AppColors.brandGradient : null,
                borderRadius: BorderRadius.circular(isSelected ? 16 : 24),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(child: child),
                  if (badgeCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: AppColors.statusDnd,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: AppColors.backgroundSecondary, width: 2),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.small.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
