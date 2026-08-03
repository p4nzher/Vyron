import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../controllers/voice_call_providers.dart';
import '../controllers/voice_call_state.dart';

/// Discord'daki gibi: bir sesli/görüntülü görüşmeye bağlıyken, uygulamanın
/// HERHANGİ bir ekranında (başka bir sunucu/kanal gezilirken dahi) altta
/// sabit kalan ince çubuk. Dokunmak ilgili sunucu/kanala geri gider; sağdaki
/// hızlı eylemler (sustur/sağırlaştır/ayrıl) navigasyon gerektirmez.
///
/// `voiceCallControllerProvider` GLOBAL bir provider olduğu için bu widget
/// `HomeShellScreen`'in HER dalında (dar/geniş, sunucu seçili/seçili değil)
/// aynı şekilde çalışır — bkz. `voice_call_providers.dart` mimari notu.
class VoiceCallBar extends ConsumerWidget {
  const VoiceCallBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(voiceCallControllerProvider);
    if (call == null) return const SizedBox.shrink();

    final controller = ref.read(voiceCallControllerProvider.notifier);
    final statusLabel = switch (call.status) {
      VoiceCallStatus.connecting => 'Bağlanıyor…',
      VoiceCallStatus.connected => 'Sesli görüşme',
      VoiceCallStatus.reconnecting => 'Yeniden bağlanıyor…',
      VoiceCallStatus.failed => 'Bağlantı hatası',
    };

    return Material(
      color: AppColors.backgroundElevated,
      child: InkWell(
        onTap: () => context.go(AppRoutes.channelPath(call.serverId, call.channelId)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.glassBorder))),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: call.status == VoiceCallStatus.connected ? AppColors.statusOnline : AppColors.statusIdle,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(statusLabel, style: AppTextStyles.small),
                    Text(call.channelName, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              _QuickIconButton(
                icon: call.isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                active: call.isMicOn,
                onTap: controller.toggleMic,
              ),
              const SizedBox(width: 4),
              _QuickIconButton(
                icon: call.isDeafened ? Icons.headset_off_rounded : Icons.headset_rounded,
                active: !call.isDeafened,
                onTap: controller.toggleDeafen,
              ),
              const SizedBox(width: 4),
              _QuickIconButton(
                icon: Icons.call_end_rounded,
                active: false,
                isDanger: true,
                onTap: controller.leaveCall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickIconButton extends StatelessWidget {
  const _QuickIconButton({required this.icon, required this.active, required this.onTap, this.isDanger = false});

  final IconData icon;
  final bool active;
  final bool isDanger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDanger
        ? AppColors.statusDnd
        : active
            ? AppColors.textPrimary
            : AppColors.statusDnd;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 19, color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
