import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/message.dart';
import '../domain/message_scope.dart';

/// `GET/POST/PATCH/DELETE .../messages` uç noktalarını sarmalar. Backend'de
/// kanal ve DM mesajları AYNI `MessagesService`'i paylaştığı için (bkz.
/// `messages.controller.ts` ve `dm.controller.ts`), bu repository de tek bir
/// [MessageScope] parametresiyle iki yolu da tek bir yerden yönetir.
///
/// NOT: mesaj sabitleme (`pin`) SADECE sunucu kanallarında vardır — DM
/// controller'ında karşılığı yok (bkz. backend `dm.controller.ts`).
class MessagesListPage {
  const MessagesListPage({required this.messages, required this.hasMore});

  final List<Message> messages;
  final bool hasMore;
}

class MessagesRepository {
  MessagesRepository(this._client);

  final ApiClient _client;

  String _messagesPath(MessageScope scope) =>
      scope.isChannel ? ApiConstants.channelMessages(scope.channelId!) : ApiConstants.dmMessages(scope.dmChannelId!);

  String _messagePath(MessageScope scope, String messageId) => scope.isChannel
      ? ApiConstants.channelMessage(scope.channelId!, messageId)
      : ApiConstants.dmMessage(scope.dmChannelId!, messageId);

  String _reactionsPath(MessageScope scope, String messageId) => scope.isChannel
      ? ApiConstants.channelMessageReactions(scope.channelId!, messageId)
      : ApiConstants.dmMessageReactions(scope.dmChannelId!, messageId);

  String _reactionPath(MessageScope scope, String messageId, String emoji) => scope.isChannel
      ? ApiConstants.channelMessageReaction(scope.channelId!, messageId, emoji)
      : ApiConstants.dmMessageReaction(scope.dmChannelId!, messageId, emoji);

  /// İmleç tabanlı sayfalama: `before` verilirse o mesajdan ÖNCEKİ (daha
  /// eski) mesajlar; hiçbiri verilmezse en yeni sayfa döner. Yanıt daima
  /// kronolojik (eskiden yeniye) sırayla gelir (bkz. `MessagesService.list`).
  Future<MessagesListPage> list(MessageScope scope, {String? before, int limit = 50}) {
    return _client.guard(
      () => _client.dio.get(
        _messagesPath(scope),
        queryParameters: {
          if (before != null) 'before': before,
          'limit': limit,
        },
      ),
      (data) {
        final map = data as Map<String, dynamic>;
        final rows = (map['messages'] as List<dynamic>).map((m) => Message.fromJson(m as Map<String, dynamic>));
        return MessagesListPage(messages: rows.toList(), hasMore: map['hasMore'] as bool? ?? false);
      },
    );
  }

  Future<Message> create(
    MessageScope scope, {
    String? content,
    String? replyToId,
    List<Map<String, dynamic>>? attachments,
  }) {
    return _client.guard(
      () => _client.dio.post(
        _messagesPath(scope),
        data: {
          if (content != null && content.isNotEmpty) 'content': content,
          if (replyToId != null) 'replyToId': replyToId,
          if (attachments != null && attachments.isNotEmpty) 'attachments': attachments,
        },
      ),
      (data) => Message.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Message> update(MessageScope scope, String messageId, String content) {
    return _client.guard(
      () => _client.dio.patch(_messagePath(scope, messageId), data: {'content': content}),
      (data) => Message.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> remove(MessageScope scope, String messageId) {
    return _client.guard(
      () => _client.dio.delete(_messagePath(scope, messageId)),
      (_) => null,
    );
  }

  Future<Message> setPinned(MessageScope scope, String messageId, bool pinned) {
    assert(scope.isChannel, 'Mesaj sabitleme sadece sunucu kanallarında desteklenir.');
    final path = ApiConstants.channelMessagePin(scope.channelId!, messageId);
    return _client.guard(
      () => pinned ? _client.dio.post(path) : _client.dio.delete(path),
      (data) => Message.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> addReaction(MessageScope scope, String messageId, String emoji) {
    return _client.guard(
      () => _client.dio.post(_reactionsPath(scope, messageId), data: {'emoji': emoji}),
      (_) => null,
    );
  }

  Future<void> removeReaction(MessageScope scope, String messageId, String emoji) {
    return _client.guard(
      () => _client.dio.delete(_reactionPath(scope, messageId, emoji)),
      (_) => null,
    );
  }
}
