import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/message_scope.dart';
import '../controllers/messages_providers.dart';
import 'message_bubble.dart';
import 'typing_indicator.dart';

/// Sonsuz kaydırmalı (yukarı doğru eskiye giden) mesaj listesi. `reverse:
/// true` ile en yeni mesaj altta görünür; listenin GÖRSEL üstüne
/// (`maxScrollExtent`e) yaklaşınca `loadMoreOlder()` tetiklenir.
class MessageList extends ConsumerStatefulWidget {
  const MessageList({required this.scope, required this.currentUserId, super.key});

  final MessageScope scope;
  final String currentUserId;

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(messagesControllerProvider(widget.scope).notifier).loadMoreOlder();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesControllerProvider(widget.scope));
    final controller = ref.read(messagesControllerProvider(widget.scope).notifier);

    if (state.isLoadingInitial) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (state.error != null && state.messages.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: controller.loadInitial);
    }

    if (state.messages.isEmpty) {
      return const _EmptyMessagesState();
    }

    // Ekranda en yeniden en eskiye gösterilecek şekilde ters çevrilir
    // (ListView `reverse: true` ile birlikte kullanılır).
    final reversedMessages = state.messages.reversed.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: reversedMessages.length + (state.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == reversedMessages.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }

              final message = reversedMessages[index];
              // Kronolojik dizide bir öncekiyle (yani ters listede bir
              // SONRAKİ ile) aynı yazar mı, kısa aralıkla mı geldi bakılır.
              final chronologicalIndex = reversedMessages.length - 1 - index;
              final previous =
                  chronologicalIndex > 0 ? state.messages[chronologicalIndex - 1] : null;
              final showHeader = previous == null ||
                  previous.authorId != message.authorId ||
                  message.createdAt.difference(previous.createdAt).inMinutes.abs() > 5 ||
                  previous.isSystem != message.isSystem;

              return MessageBubble(
                message: message,
                currentUserId: widget.currentUserId,
                showHeader: showHeader,
                canPin: widget.scope.isChannel,
                onToggleReaction: (emoji) => controller.toggleReaction(message, emoji),
                onReply: () => controller.setReplyingTo(message),
                onEdit: () => controller.startEditing(message),
                onDelete: () => controller.deleteMessage(message.id),
                onTogglePin: () => controller.togglePin(message),
                onRetry: () => controller.retrySend(message.id),
                onDiscardFailed: () => controller.discardFailed(message.id),
              );
            },
          ),
        ),
        TypingIndicator(usernames: state.typingUsernames),
      ],
    );
  }
}

class _EmptyMessagesState extends StatelessWidget {
  const _EmptyMessagesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('Henüz mesaj yok — ilk mesajı sen gönder!', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.statusDnd),
            const SizedBox(height: 12),
            Text('Mesajlar yüklenemedi', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 4),
            Text(message, style: AppTextStyles.caption, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}
