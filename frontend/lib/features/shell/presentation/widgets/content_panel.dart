import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/status_dot.dart';
import '../../../dm/domain/dm_channel.dart';
import '../../../messages/domain/message_scope.dart';
import '../../../messages/presentation/widgets/message_input.dart';
import '../../../messages/presentation/widgets/message_list.dart';
import '../../../notifications/presentation/widgets/active_scope_reporter.dart';
import '../../../servers/domain/channel.dart';
import '../../../voice/presentation/widgets/voice_channel_panel.dart';

/// Üçüncü sütun: başlık + mesaj listesi (sonsuz kaydırma, Socket.IO) +
/// mesaj input'u (bkz. Faz 6.4 `features/messages`) YA DA sesli/görüntülü
/// görüşme paneli (bkz. Faz 6.5 `features/voice`). Kanal ya da DM
/// seçimine göre tek bir [MessageScope] türetilir — geri kalan her şey
/// (repository, socket odaları, Riverpod state'i) bu tek kimliğe göre
/// izole edilir (bkz. `MessagesController`).
class ContentPanel extends StatelessWidget {
  const ContentPanel({this.channel, this.dmChannel, this.currentUserId, this.serverId, super.key});

  final Channel? channel;
  final DmChannel? dmChannel;
  final String? currentUserId;
  final String? serverId;

  @override
  Widget build(BuildContext context) {
    if (channel == null && dmChannel == null) {
      return const _EmptyState();
    }

    // Kategori kanalları (bkz. Faz 6.6) mesajlaşma alanı değildir.
    if (channel != null && channel!.isCategory) {
      return _Header(channel: channel, dmChannel: dmChannel, currentUserId: currentUserId, serverId: serverId);
    }

    // Sesli/görüntülü kanallar metin mesajlaşması GÖSTERMEZ — Faz 6.5'teki
    // katıl-ekranı/görüşme ızgarası burada devreye girer.
    if (channel != null && channel!.isVoice) {
      return Column(
        children: [
          _Header(channel: channel, dmChannel: dmChannel, currentUserId: currentUserId, serverId: serverId),
          const Divider(height: 1, color: AppColors.glassBorder),
          Expanded(
            child: VoiceChannelPanel(
              serverId: serverId ?? '',
              channelId: channel!.id,
              channelName: channel!.name,
            ),
          ),
        ],
      );
    }

    final scope = channel != null ? MessageScope.channel(channel!.id) : MessageScope.dm(dmChannel!.id);
    final resolvedUserId = currentUserId ?? '';

    return ActiveScopeReporter(
      scopeKey: scope.key,
      child: Column(
        children: [
          _Header(channel: channel, dmChannel: dmChannel, currentUserId: currentUserId, serverId: serverId),
          const Divider(height: 1, color: AppColors.glassBorder),
          Expanded(
            key: ValueKey(scope.key),
            child: MessageList(scope: scope, currentUserId: resolvedUserId),
          ),
          MessageInput(key: ValueKey('input-${scope.key}'), scope: scope),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.channel, this.dmChannel, this.currentUserId, this.serverId});

  final Channel? channel;
  final DmChannel? dmChannel;
  final String? currentUserId;
  final String? serverId;

  @override
  Widget build(BuildContext context) {
    Widget leading;
    String title;
    String? subtitle;

    if (channel != null) {
      leading = Icon(
        channel!.isVoice ? Icons.volume_up_rounded : Icons.tag_rounded,
        color: AppColors.textSecondary,
      );
      title = channel!.name;
      subtitle = channel!.topic;
    } else {
      final other = currentUserId != null ? dmChannel!.otherParticipant(currentUserId!) : null;
      leading = Stack(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.backgroundElevated,
            backgroundImage: other?.avatarUrl != null ? NetworkImage(other!.avatarUrl!) : null,
            child: other?.avatarUrl == null
                ? Text(
                    (dmChannel!.displayName(currentUserId ?? '')).substring(0, 1).toUpperCase(),
                    style: AppTextStyles.caption,
                  )
                : null,
          ),
          if (other != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: StatusDot(status: other.status, size: 11, borderColor: AppColors.backgroundPrimary),
            ),
        ],
      );
      title = dmChannel!.displayName(currentUserId ?? '');
      subtitle = null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.bodyMedium, overflow: TextOverflow.ellipsis),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(subtitle, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (channel != null && serverId != null)
            IconButton(
              tooltip: 'Üye listesi',
              icon: const Icon(Icons.people_alt_outlined, color: AppColors.textSecondary, size: 20),
              onPressed: () => context.push(AppRoutes.serverSettingsPath(serverId!)),
            )
          else
            Tooltip(
              message: 'Üye listesi sadece sunucu kanallarında kullanılabilir',
              child: Icon(Icons.people_alt_outlined, color: AppColors.textSecondary.withOpacity(0.3), size: 20),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('Bir sohbet ya da kanal seç', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}
