import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../controllers/voice_call_state.dart';

/// Görüşme ızgarasındaki tek bir katılımcı karosu. Ekran paylaşımı > kamera >
/// avatar önceliğiyle render edilir; konuşurken marka rengi bir çerçeve,
/// susturulmuşken küçük bir mikrofon-kapalı rozeti gösterilir.
class ParticipantTile extends StatelessWidget {
  const ParticipantTile({required this.participant, this.onLongPress, super.key});

  final VoiceCallParticipant participant;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final videoTrack = participant.screenTrack ?? participant.cameraTrack;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: participant.isSpeaking ? AppColors.brandGradientStart : AppColors.glassBorder,
            width: participant.isSpeaking ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (videoTrack != null)
              VideoTrackRenderer(videoTrack)
            else
              _AvatarFill(name: participant.name, avatarUrl: participant.avatarUrl),
            Positioned(
              left: 8,
              bottom: 8,
              child: _NameChip(participant: participant),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarFill extends StatelessWidget {
  const _AvatarFill({required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundElevated,
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.backgroundSecondary,
        backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
        child: avatarUrl == null
            ? Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: AppTextStyles.title)
            : null,
      ),
    );
  }
}

class _NameChip extends StatelessWidget {
  const _NameChip({required this.participant});

  final VoiceCallParticipant participant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            participant.isDeafened
                ? Icons.headset_off_rounded
                : participant.isMicOn
                    ? Icons.mic_none_rounded
                    : Icons.mic_off_rounded,
            size: 13,
            color: !participant.isMicOn || participant.isDeafened ? AppColors.statusDnd : Colors.white,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              participant.name,
              style: AppTextStyles.small.copyWith(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
