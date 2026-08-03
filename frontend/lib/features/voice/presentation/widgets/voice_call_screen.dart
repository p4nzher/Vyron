import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../controllers/voice_call_state.dart';
import '../controllers/voice_call_providers.dart';
import 'participant_tile.dart';

/// Bir sesli/görüntülü kanala bağlıyken gösterilen tam ekran görüşme
/// arayüzü: katılımcı ızgarası + alt kontrol çubuğu (mikrofon/kamera/ekran
/// paylaşımı/sağırlaştır/ayrıl). `voiceCallControllerProvider` üzerinden
/// beslenir — bu global/tekil olduğu için burada bir `MessageScope` benzeri
/// parametre YOKTUR, sadece "şu an bağlı olunan görüşme" gösterilir.
class VoiceCallScreen extends ConsumerWidget {
  const VoiceCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(voiceCallControllerProvider);
    final controller = ref.read(voiceCallControllerProvider.notifier);

    if (call == null) {
      return const Center(
        child: Text('Bir görüşmeye bağlı değilsiniz.', style: AppTextStyles.caption),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.volume_up_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(child: Text(call.channelName, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis)),
              _StatusPill(status: call.status),
            ],
          ),
        ),
        if (call.errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(call.errorMessage!, style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
          ),
        Expanded(
          child: call.participants.isEmpty
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = call.participants.length <= 1
                          ? 1
                          : call.participants.length <= 4
                              ? 2
                              : 3;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 4 / 3,
                        ),
                        itemCount: call.participants.length,
                        itemBuilder: (context, index) {
                          final participant = call.participants[index];
                          return ParticipantTile(
                            participant: participant,
                            onLongPress:
                                participant.isLocal ? null : () => _showModerationSheet(context, ref, participant),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
        _CallControlBar(call: call, controller: controller),
      ],
    );
  }

  void _showModerationSheet(BuildContext context, WidgetRef ref, VoiceCallParticipant participant) {
    final controller = ref.read(voiceCallControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  participant.isMicOn ? Icons.mic_off_rounded : Icons.mic_rounded,
                  color: AppColors.textSecondary,
                ),
                title: Text(participant.isMicOn ? 'Zorla sustur' : 'Susturmayı kaldır'),
                subtitle: const Text('MUTE_MEMBERS_VOICE yetkisi gerekir', style: AppTextStyles.small),
                onTap: () {
                  Navigator.of(context).pop();
                  controller.forceMuteMember(participant.userId, participant.isMicOn);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: AppColors.statusDnd),
                title: const Text('Görüşmeden at', style: TextStyle(color: AppColors.statusDnd)),
                subtitle: const Text('MOVE_MEMBERS_VOICE yetkisi gerekir', style: AppTextStyles.small),
                onTap: () {
                  Navigator.of(context).pop();
                  controller.disconnectMember(participant.userId);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final VoiceCallStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      VoiceCallStatus.connecting => ('Bağlanıyor…', AppColors.textSecondary),
      VoiceCallStatus.connected => ('Bağlandı', AppColors.statusOnline),
      VoiceCallStatus.reconnecting => ('Yeniden bağlanıyor…', AppColors.statusIdle),
      VoiceCallStatus.failed => ('Bağlantı hatası', AppColors.statusDnd),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTextStyles.small.copyWith(color: color)),
    );
  }
}

class _CallControlBar extends StatelessWidget {
  const _CallControlBar({required this.call, required this.controller});

  final VoiceCallState call;
  final VoiceCallController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.glassBorder))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: call.isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
            active: call.isMicOn,
            onTap: controller.toggleMic,
          ),
          _ControlButton(
            icon: call.isDeafened ? Icons.headset_off_rounded : Icons.headset_rounded,
            active: !call.isDeafened,
            onTap: controller.toggleDeafen,
          ),
          _ControlButton(
            icon: call.isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            active: call.isCameraOn,
            onTap: controller.toggleCamera,
          ),
          _ControlButton(
            icon: Icons.screen_share_rounded,
            active: call.isScreenSharing,
            onTap: controller.toggleScreenShare,
          ),
          _ControlButton(
            icon: Icons.call_end_rounded,
            active: false,
            isDanger: true,
            onTap: controller.leaveCall,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({required this.icon, required this.active, required this.onTap, this.isDanger = false});

  final IconData icon;
  final bool active;
  final bool isDanger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDanger
        ? AppColors.statusDnd
        : active
            ? AppColors.backgroundElevated
            : AppColors.statusDnd.withOpacity(0.85);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
