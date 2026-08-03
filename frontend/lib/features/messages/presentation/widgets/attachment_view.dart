import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/attachment.dart';

/// Bir mesaj balonu içindeki tek bir ek (attachment). Görsel/GIF/sticker
/// için önizleme, ses/sesli not için oynatıcı, diğer her şey için genel
/// dosya kartı gösterir.
class AttachmentView extends StatelessWidget {
  const AttachmentView({required this.attachment, super.key});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) return _ImageAttachment(attachment: attachment);
    if (attachment.isAudio) return _AudioAttachment(attachment: attachment);
    return _FileAttachment(attachment: attachment);
  }
}

class _ImageAttachment extends StatelessWidget {
  const _ImageAttachment({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = (attachment.width != null && attachment.height != null && attachment.height! > 0)
        ? attachment.width! / attachment.height!
        : 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
        child: AspectRatio(
          aspectRatio: aspectRatio.clamp(0.5, 2.2),
          child: CachedNetworkImage(
            imageUrl: attachment.url,
            fit: BoxFit.cover,
            placeholder: (context, _) => Container(color: AppColors.backgroundElevated),
            errorWidget: (context, _, __) => Container(
              color: AppColors.backgroundElevated,
              child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioAttachment extends StatefulWidget {
  const _AudioAttachment({required this.attachment});

  final Attachment attachment;

  @override
  State<_AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<_AudioAttachment> {
  late final AudioPlayer _player = AudioPlayer();
  bool _loaded = false;

  Future<void> _togglePlay() async {
    if (!_loaded) {
      try {
        await _player.setUrl(widget.attachment.url);
        _loaded = true;
      } catch (_) {
        return;
      }
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return IconButton(
                onPressed: _togglePlay,
                icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 30),
                color: AppColors.brandGradientStart,
              );
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.attachment.isVoiceNote ? 'Sesli not' : widget.attachment.fileName,
                  style: AppTextStyles.caption,
                  overflow: TextOverflow.ellipsis,
                ),
                StreamBuilder<Duration?>(
                  stream: _player.durationStream,
                  builder: (context, snapshot) {
                    final duration = snapshot.data ??
                        (widget.attachment.durationMs != null
                            ? Duration(milliseconds: widget.attachment.durationMs!)
                            : null);
                    if (duration == null) return const SizedBox.shrink();
                    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
                    return Text('${duration.inMinutes}:$seconds', style: AppTextStyles.small);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  const _FileAttachment({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(attachment.fileName, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
                Text(attachment.humanSize, style: AppTextStyles.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
