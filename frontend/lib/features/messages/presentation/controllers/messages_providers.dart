import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/realtime/socket_service.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/messages_repository.dart';
import '../../domain/message.dart';
import '../../domain/message_scope.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(ref.watch(apiClientProvider));
});

/// Aynı anda yazan kullanıcı(lar) — Discord'daki "X yazıyor..." göstergesi
/// için. Kullanıcı adına göre tutulur (kendi kendine göstermemek için
/// `MessagesController` kendi socket'inden gelen olayı zaten almaz — sunucu
/// tarafı `client.to(room)` kullanır, yani gönderen kendi olayını almaz).
class MessagesState {
  const MessagesState({
    this.messages = const [],
    this.isLoadingInitial = true,
    this.isLoadingMore = false,
    this.hasMoreOlder = true,
    this.error,
    this.typingUsernames = const {},
    this.replyingTo,
    this.editingMessage,
  });

  final List<Message> messages;
  final bool isLoadingInitial;
  final bool isLoadingMore;
  final bool hasMoreOlder;
  final String? error;
  final Set<String> typingUsernames;
  final Message? replyingTo;
  final Message? editingMessage;

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoadingInitial,
    bool? isLoadingMore,
    bool? hasMoreOlder,
    String? error,
    bool clearError = false,
    Set<String>? typingUsernames,
    Message? replyingTo,
    bool clearReplyingTo = false,
    Message? editingMessage,
    bool clearEditingMessage = false,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      error: clearError ? null : (error ?? this.error),
      typingUsernames: typingUsernames ?? this.typingUsernames,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
      editingMessage: clearEditingMessage ? null : (editingMessage ?? this.editingMessage),
    );
  }
}

/// Bir kanal ya da DM'in TÜM mesajlaşma yaşam döngüsünü yönetir: ilk yükleme,
/// eskiye doğru sayfalama, iyimser (optimistic) gönderim, düzenleme/silme,
/// tepkiler ve gerçek-zamanlı (Socket.IO) senkronizasyon.
///
/// Mimari not (bkz. `messages.gateway.ts`): REST çağrıları komut, socket
/// olayları ise yayındır. Bu yüzden `send`/`edit`/`delete`/tepki metodları
/// SONUCU REST yanıtından uygular; socket'ten gelen aynı olay (kendi
/// isteğimiz için de yayınlanır) sadece ID eşleşmesiyle yok sayılır —
/// böylece çiftlenme (duplicate) olmaz.
class MessagesController extends StateNotifier<MessagesState> {
  MessagesController({
    required this.scope,
    required this.repository,
    required this.socket,
    required this.currentUserId,
    required this.currentUsername,
  }) : super(const MessagesState()) {
    _connect();
  }

  final MessageScope scope;
  final MessagesRepository repository;
  final SocketService socket;
  final String currentUserId;
  final String currentUsername;

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _typingStopTimer;
  bool _typingActive = false;

  Future<void> _connect() async {
    if (scope.isChannel) {
      await socket.joinChannel(scope.channelId!);
    } else {
      await socket.joinDm(scope.dmChannelId!);
    }
    _subs.add(socket.onMessageCreated.listen(_onSocketMessageCreated));
    _subs.add(socket.onMessageUpdated.listen(_onSocketMessageUpdated));
    _subs.add(socket.onMessageDeleted.listen(_onSocketMessageDeleted));
    _subs.add(socket.onReactionAdded.listen(_onSocketReactionAdded));
    _subs.add(socket.onReactionRemoved.listen(_onSocketReactionRemoved));
    _subs.add(socket.onTypingStart.listen(_onSocketTypingStart));
    _subs.add(socket.onTypingStop.listen(_onSocketTypingStop));
    await loadInitial();
  }

  bool _matchesScope(Map<String, dynamic> payload) {
    if (scope.isChannel) return payload['channelId'] == scope.channelId;
    return payload['dmChannelId'] == scope.dmChannelId;
  }

  // ---------------------------------------------------------------------
  // YÜKLEME / SAYFALAMA
  // ---------------------------------------------------------------------

  Future<void> loadInitial() async {
    state = state.copyWith(isLoadingInitial: true, clearError: true);
    try {
      final page = await repository.list(scope);
      state = state.copyWith(
        messages: page.messages,
        isLoadingInitial: false,
        hasMoreOlder: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingInitial: false, error: e.toString());
    }
  }

  Future<void> loadMoreOlder() async {
    if (state.isLoadingMore || !state.hasMoreOlder || state.messages.isEmpty) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final oldestId = state.messages.first.id;
      final page = await repository.list(scope, before: oldestId);
      state = state.copyWith(
        messages: [...page.messages, ...state.messages],
        isLoadingMore: false,
        hasMoreOlder: page.hasMore,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  // ---------------------------------------------------------------------
  // GÖNDERME (iyimser / optimistic)
  // ---------------------------------------------------------------------

  Future<void> send({String? content, List<Map<String, dynamic>>? attachments}) async {
    final hasContent = content != null && content.trim().isNotEmpty;
    final hasAttachments = attachments != null && attachments.isNotEmpty;
    if (!hasContent && !hasAttachments) return;

    final replyTo = state.replyingTo;
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = Message(
      id: tempId,
      authorId: currentUserId,
      author: MessageAuthor(id: currentUserId, username: currentUsername, discriminator: '0000'),
      content: hasContent ? content.trim() : null,
      type: replyTo != null ? 'REPLY' : 'DEFAULT',
      replyToId: replyTo?.id,
      replyTo: replyTo != null
          ? ReplyPreview(id: replyTo.id, author: replyTo.author, content: replyTo.content, isDeleted: false)
          : null,
      isEdited: false,
      isPinned: false,
      isDeleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      attachments: const [],
      reactions: const [],
      localStatus: MessageLocalStatus.sending,
    );

    state = state.copyWith(messages: [...state.messages, optimistic], clearReplyingTo: true);
    stopTyping();

    try {
      final created = await repository.create(
        scope,
        content: hasContent ? content.trim() : null,
        replyToId: replyTo?.id,
        attachments: attachments,
      );
      _replaceMessage(tempId, created);
    } catch (_) {
      _updateMessage(tempId, (m) => m.copyWith(localStatus: MessageLocalStatus.failed));
    }
  }

  Future<void> retrySend(String tempId) async {
    final target = state.messages.where((m) => m.id == tempId).toList();
    if (target.isEmpty) return;
    final msg = target.first;
    _updateMessage(tempId, (m) => m.copyWith(localStatus: MessageLocalStatus.sending));
    try {
      final created = await repository.create(scope, content: msg.content, replyToId: msg.replyToId);
      _replaceMessage(tempId, created);
    } catch (_) {
      _updateMessage(tempId, (m) => m.copyWith(localStatus: MessageLocalStatus.failed));
    }
  }

  void discardFailed(String tempId) {
    state = state.copyWith(messages: state.messages.where((m) => m.id != tempId).toList());
  }

  // ---------------------------------------------------------------------
  // DÜZENLEME / SİLME
  // ---------------------------------------------------------------------

  void startEditing(Message message) => state = state.copyWith(editingMessage: message);
  void cancelEditing() => state = state.copyWith(clearEditingMessage: true);

  Future<void> submitEdit(String content) async {
    final editing = state.editingMessage;
    if (editing == null || content.trim().isEmpty) return;
    state = state.copyWith(clearEditingMessage: true);
    try {
      final updated = await repository.update(scope, editing.id, content.trim());
      _replaceMessage(editing.id, updated);
    } catch (_) {
      // Sessizce yok say; kullanıcı düzenle butonunu tekrar deneyebilir.
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final previous = state.messages;
    state = state.copyWith(messages: state.messages.where((m) => m.id != messageId).toList());
    try {
      await repository.remove(scope, messageId);
    } catch (_) {
      state = state.copyWith(messages: previous);
    }
  }

  Future<void> togglePin(Message message) async {
    if (!scope.isChannel) return;
    try {
      final updated = await repository.setPinned(scope, message.id, !message.isPinned);
      _replaceMessage(message.id, updated);
    } catch (_) {
      // yetki hatası vb. — sessizce yok say
    }
  }

  // ---------------------------------------------------------------------
  // YANIT
  // ---------------------------------------------------------------------

  void setReplyingTo(Message message) => state = state.copyWith(replyingTo: message);
  void cancelReplying() => state = state.copyWith(clearReplyingTo: true);

  // ---------------------------------------------------------------------
  // TEPKİLER
  // ---------------------------------------------------------------------

  Future<void> toggleReaction(Message message, String emoji) async {
    final alreadyReacted = message.reactions.any((r) => r.userId == currentUserId && r.emoji == emoji);
    _updateMessage(message.id, (m) {
      final next = List<RawReaction>.from(m.reactions);
      if (alreadyReacted) {
        next.removeWhere((r) => r.userId == currentUserId && r.emoji == emoji);
      } else {
        next.add(RawReaction(userId: currentUserId, emoji: emoji));
      }
      return m.copyWith(reactions: next);
    });
    try {
      if (alreadyReacted) {
        await repository.removeReaction(scope, message.id, emoji);
      } else {
        await repository.addReaction(scope, message.id, emoji);
      }
    } catch (_) {
      // Socket geri bildirimi/yeniden senkron olmazsa bir sonraki yüklemede düzelir.
    }
  }

  // ---------------------------------------------------------------------
  // YAZIYOR... (TYPING)
  // ---------------------------------------------------------------------

  void notifyTyping() {
    if (!_typingActive) {
      _typingActive = true;
      socket.emitTypingStart(channelId: scope.channelId, dmChannelId: scope.dmChannelId);
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(seconds: 4), stopTyping);
  }

  void stopTyping() {
    if (_typingActive) {
      _typingActive = false;
      socket.emitTypingStop(channelId: scope.channelId, dmChannelId: scope.dmChannelId);
    }
    _typingStopTimer?.cancel();
  }

  // ---------------------------------------------------------------------
  // SOCKET OLAY İŞLEYİCİLERİ
  // ---------------------------------------------------------------------

  void _onSocketMessageCreated(Map<String, dynamic> payload) {
    if (!_matchesScope(payload)) return;
    final incoming = Message.fromJson(payload);
    if (state.messages.any((m) => m.id == incoming.id)) return; // kendi optimistic gönderimimiz zaten değişti
    state = state.copyWith(messages: [...state.messages, incoming]);
  }

  void _onSocketMessageUpdated(Map<String, dynamic> payload) {
    if (!_matchesScope(payload)) return;
    final updated = Message.fromJson(payload);
    _replaceMessage(updated.id, updated, onlyIfExists: true);
  }

  void _onSocketMessageDeleted(Map<String, dynamic> payload) {
    final id = payload['id'] as String?;
    if (id == null) return;
    state = state.copyWith(messages: state.messages.where((m) => m.id != id).toList());
  }

  void _onSocketReactionAdded(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String?;
    final userId = payload['userId'] as String?;
    final emoji = payload['emoji'] as String?;
    if (messageId == null || userId == null || emoji == null) return;
    if (userId == currentUserId) return; // kendi tepkimizi zaten iyimser uyguladık
    _updateMessage(messageId, (m) {
      if (m.reactions.any((r) => r.userId == userId && r.emoji == emoji)) return m;
      return m.copyWith(reactions: [...m.reactions, RawReaction(userId: userId, emoji: emoji)]);
    });
  }

  void _onSocketReactionRemoved(Map<String, dynamic> payload) {
    final messageId = payload['messageId'] as String?;
    final userId = payload['userId'] as String?;
    final emoji = payload['emoji'] as String?;
    if (messageId == null || userId == null || emoji == null) return;
    if (userId == currentUserId) return;
    _updateMessage(
      messageId,
      (m) => m.copyWith(reactions: m.reactions.where((r) => !(r.userId == userId && r.emoji == emoji)).toList()),
    );
  }

  void _onSocketTypingStart(Map<String, dynamic> payload) {
    // NOT: `typing:start` yükü SADECE {userId, username} içerir — kapsam
    // filtrelemesi gerekmez çünkü Socket.IO zaten sadece katıldığımız
    // odaya (bkz. `MessagesGateway.onTypingStart`) yayın yapar.
    final username = payload['username'] as String?;
    if (username == null || username == currentUsername) return;
    state = state.copyWith(typingUsernames: {...state.typingUsernames, username});
  }

  void _onSocketTypingStop(Map<String, dynamic> payload) {
    final username = payload['username'] as String?;
    if (username == null) return;
    final next = Set<String>.from(state.typingUsernames)..remove(username);
    state = state.copyWith(typingUsernames: next);
  }

  // ---------------------------------------------------------------------
  // YARDIMCILAR
  // ---------------------------------------------------------------------

  void _updateMessage(String id, Message Function(Message) transform) {
    state = state.copyWith(
      messages: state.messages.map((m) => m.id == id ? transform(m) : m).toList(),
    );
  }

  void _replaceMessage(String oldId, Message replacement, {bool onlyIfExists = false}) {
    final exists = state.messages.any((m) => m.id == oldId);
    if (onlyIfExists && !exists) return;
    if (!exists) {
      state = state.copyWith(messages: [...state.messages, replacement]);
      return;
    }
    state = state.copyWith(messages: state.messages.map((m) => m.id == oldId ? replacement : m).toList());
  }

  @override
  void dispose() {
    _typingStopTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    if (scope.isChannel) {
      socket.leaveChannel(scope.channelId!);
    } else {
      socket.leaveDm(scope.dmChannelId!);
    }
    super.dispose();
  }
}

final messagesControllerProvider =
    StateNotifierProvider.autoDispose.family<MessagesController, MessagesState, MessageScope>((ref, scope) {
  final currentUser = ref.watch(authControllerProvider).user;
  return MessagesController(
    scope: scope,
    repository: ref.watch(messagesRepositoryProvider),
    socket: ref.watch(socketServiceProvider),
    currentUserId: currentUser?.id ?? '',
    currentUsername: currentUser?.username ?? '',
  );
});
