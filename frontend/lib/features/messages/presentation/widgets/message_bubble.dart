import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/message.dart';
import 'attachment_view.dart';
import 'emoji_picker_sheet.dart';
import 'reaction_row.dart';

/// Tek bir mesaj balonu. [showHeader] false ise (aynı yazarın kısa süre
/// içindeki ardışık mesajı) avatar/isim gizlenir — Discord'daki "gruplama"
/// davranışı (bkz. `MessageList` gruplama mantığı).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.currentUserId,
    required this.showHeader,
    required this.canPin,
    required this.onToggleReaction,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
    required this.onRetry,
    required this.onDiscardFailed,
    super.key,
  });

  final Message message;
  final String currentUserId;
  final bool showHeader;
  final bool canPin;
  final ValueChanged<String> onToggleReaction;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final VoidCallback onRetry;
  final VoidCallback onDiscardFailed;

  bool get _isMine => message.authorId == currentUserId;
  bool get _isFailed => message.localStatus == MessageLocalStatus.failed;
  bool get _isSending => message.localStatus == MessageLocalStatus.sending;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) return _SystemMessage(message: message);

    return Padding(
      padding: EdgeInsets.only(top: showHeader ? 12 : 2, left: 16, right: 16),
      child: Opacity(
        opacity: _isSending ? 0.55 : 1,
        child: GestureDetector(
          onLongPress: () => _showActions(context),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isReply) _ReplyBanner(message: message),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 38,
                      child: showHeader ? _Avatar(message: message) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader) _HeaderLine(message: message),
                          if (message.content != null && message.content!.isNotEmpty)
                            Text(message.content!, style: AppTextStyles.body),
                          if (message.isEdited)
                            Text('(düzenlendi)', style: AppTextStyles.small.copyWith(fontStyle: FontStyle.italic)),
                          for (final attachment in message.attachments)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: AttachmentView(attachment: attachment),
                            ),
                          ReactionRow(
                            reactions: message.groupedReactions,
                            currentUserId: currentUserId,
                            onToggle: onToggleReaction,
                            onAddPressed: () =>
                                showEmojiPickerSheet(context, onSelected: (emoji) => onToggleReaction(emoji)),
                          ),
                          if (_isFailed) _FailedRow(onRetry: onRetry, onDiscard: onDiscardFailed),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
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
                leading: const Icon(Icons.add_reaction_outlined, color: AppColors.textSecondary),
                title: const Text('Tepki ekle'),
                onTap: () {
                  Navigator.of(context).pop();
                  showEmojiPickerSheet(context, onSelected: onToggleReaction);
                },
              ),
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppColors.textSecondary),
                title: const Text('Yanıtla'),
                onTap: () {
                  Navigator.of(context).pop();
                  onReply();
                },
              ),
              if (canPin)
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined, color: AppColors.textSecondary),
                  title: Text(message.isPinned ? 'Sabitlemeyi kaldır' : 'Sabitle'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onTogglePin();
                  },
                ),
              if (_isMine)
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                  title: const Text('Düzenle'),
                  onTap: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                ),
              if (_isMine)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.statusDnd),
                  title: const Text('Sil', style: TextStyle(color: AppColors.statusDnd)),
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final url = message.author.avatarUrl;
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.backgroundElevated,
      backgroundImage: url != null ? CachedNetworkImageProvider(url) : null,
      child: url == null
          ? Text(message.author.name.substring(0, 1).toUpperCase(), style: AppTextStyles.caption)
          : null,
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(message.author.name, style: AppTextStyles.bodyMedium),
          const SizedBox(width: 8),
          Text(DateFormat('d MMM HH:mm', 'tr_TR').format(message.createdAt), style: AppTextStyles.small),
        ],
      ),
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final reply = message.replyTo!;
    return Padding(
      padding: const EdgeInsets.only(left: 46, bottom: 2),
      child: Row(
        children: [
          const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(reply.author.name, style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              reply.isDeleted ? 'Silinen bir mesaj' : (reply.content ?? '📎 Ek'),
              style: AppTextStyles.small,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedRow extends StatelessWidget {
  const _FailedRow({required this.onRetry, required this.onDiscard});

  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.statusDnd),
          const SizedBox(width: 4),
          Text('Gönderilemedi', style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRetry,
            child: Text('Tekrar dene', style: AppTextStyles.small.copyWith(color: AppColors.brandGradientStart)),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onDiscard,
            child: Text('Vazgeç', style: AppTextStyles.small),
          ),
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message.content ?? '${message.author.name} bir olay gerçekleştirdi.',
              style: AppTextStyles.small,
            ),
          ),
        ],
      ),
    );
  }
}
