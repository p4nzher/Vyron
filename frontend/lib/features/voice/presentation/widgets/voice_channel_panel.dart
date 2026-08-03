import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../domain/voice_participant.dart';
import '../controllers/voice_call_providers.dart';
import 'voice_call_screen.dart';

/// `ContentPanel`'in sesli kanal seçildiğinde gösterdiği görünüm.
/// Bağlı DEĞİLSEK: kanaldaki mevcut katılımcıların (REST anlık görüntüsü +
/// `voice:user-joined/left` ile tazelenen) önizlemesi + "Katıl" düğmesi.
/// Bu kanala ZATEN bağlıysak: doğrudan [VoiceCallScreen] (tam ızgara).
class VoiceChannelPanel extends ConsumerStatefulWidget {
  const VoiceChannelPanel({
    required this.serverId,
    required this.channelId,
    required this.channelName,
    super.key,
  });

  final String serverId;
  final String channelId;
  final String channelName;

  @override
  ConsumerState<VoiceChannelPanel> createState() => _VoiceChannelPanelState();
}

class _VoiceChannelPanelState extends ConsumerState<VoiceChannelPanel> {
  List<VoiceParticipant>? _roster;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    setState(() => _loading = true);
    try {
      final roster = await ref.read(voiceRepositoryProvider).listParticipants(widget.channelId);
      if (mounted) setState(() => _roster = roster);
    } catch (_) {
      if (mounted) setState(() => _roster = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(voiceCallControllerProvider);
    final isConnectedHere = call != null && call.channelId == widget.channelId;

    // Bu kanala socket'in `voice:user-joined/left` yayınlarını dinleyip
    // önizlemeyi tazelemek yerine (henüz bağlı olmadığımız için o odaya
    // katılmadık), basitçe ekrana her girişte tek seferlik REST çağrısı
    // yeterli — Faz 6.6'da kanal listesindeki canlı katılımcı sayısı
    // rozetiyle birlikte bu akış zenginleştirilebilir.
    if (isConnectedHere) {
      return const VoiceCallScreen();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.volume_up_rounded, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(widget.channelName, style: AppTextStyles.title, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Sesli kanal', style: AppTextStyles.caption),
              const SizedBox(height: 20),
              if (_loading)
                const CircularProgressIndicator(strokeWidth: 2)
              else if (_roster != null && _roster!.isNotEmpty)
                _RosterPreview(roster: _roster!)
              else
                Text('Kanalda kimse yok', style: AppTextStyles.caption),
              const SizedBox(height: 24),
              GradientButton(
                label: 'Katıl',
                onPressed: () => ref.read(voiceCallControllerProvider.notifier).joinChannel(
                      serverId: widget.serverId,
                      channelId: widget.channelId,
                      channelName: widget.channelName,
                    ),
              ),
              if (call != null && call.channelId != widget.channelId) ...[
                const SizedBox(height: 12),
                Text(
                  '"${call.channelName}" görüşmesine bağlısınız — katılmak bu görüşmeden çıkarır.',
                  style: AppTextStyles.small,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RosterPreview extends StatelessWidget {
  const _RosterPreview({required this.roster});

  final List<VoiceParticipant> roster;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final p in roster)
          Chip(
            avatar: CircleAvatar(
              backgroundColor: AppColors.backgroundElevated,
              backgroundImage: p.avatarUrl != null ? CachedNetworkImageProvider(p.avatarUrl!) : null,
              child: p.avatarUrl == null ? Text(p.name.substring(0, 1).toUpperCase()) : null,
            ),
            label: Text(p.name, style: AppTextStyles.small),
            backgroundColor: AppColors.backgroundElevated,
            side: const BorderSide(color: AppColors.glassBorder),
          ),
      ],
    );
  }
}
