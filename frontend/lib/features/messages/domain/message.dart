import 'attachment.dart';

/// `Message.author` seçimiyle birebir eşleşen küçük yazar modeli
/// (`AUTHOR_PUBLIC_SELECT` — bkz. `messages.service.ts`).
class MessageAuthor {
  const MessageAuthor({
    required this.id,
    required this.username,
    required this.discriminator,
    this.displayName,
    this.avatarUrl,
    this.status = 'OFFLINE',
  });

  final String id;
  final String username;
  final String discriminator;
  final String? displayName;
  final String? avatarUrl;
  final String status;

  String get name => displayName ?? username;

  factory MessageAuthor.fromJson(Map<String, dynamic> json) {
    return MessageAuthor(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      discriminator: json['discriminator'] as String? ?? '0000',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      status: json['status'] as String? ?? 'OFFLINE',
    );
  }
}

/// Tek bir emoji tepkisi satırı (`MessageReaction` — bkz. Prisma şeması).
/// Bubble arayüzü bunları emoji'ye göre gruplar (bkz. [Message.groupedReactions]).
class RawReaction {
  const RawReaction({required this.userId, required this.emoji});

  final String userId;
  final String emoji;

  factory RawReaction.fromJson(Map<String, dynamic> json) {
    return RawReaction(userId: json['userId'] as String, emoji: json['emoji'] as String);
  }
}

/// Emoji'ye göre gruplanmış tepki — mesaj balonu altında tek bir "chip"
/// olarak gösterilir (bkz. `reaction_row.dart`).
class GroupedReaction {
  const GroupedReaction({required this.emoji, required this.userIds});

  final String emoji;
  final List<String> userIds;

  int get count => userIds.length;
  bool reactedByMe(String userId) => userIds.contains(userId);
}

/// Yanıtlanan mesajın önizlemesi — sonsuz döngüyü önlemek için `replyTo`
/// kendi `replyTo`'sunu TAŞIMAZ (backend include'u da tek seviyeyle sınırlı,
/// bkz. `MESSAGE_INCLUDE`).
class ReplyPreview {
  const ReplyPreview({required this.id, required this.author, this.content, required this.isDeleted});

  final String id;
  final MessageAuthor author;
  final String? content;
  final bool isDeleted;

  factory ReplyPreview.fromJson(Map<String, dynamic> json) {
    return ReplyPreview(
      id: json['id'] as String,
      author: MessageAuthor.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}

/// Backend `Message` modeliyle (bkz. `MESSAGE_INCLUDE`) birebir eşleşen
/// istemci taraflı model. `type`: 'DEFAULT' | 'SYSTEM' | 'REPLY' |
/// 'JOIN_SERVER' | 'CALL'.
///
/// [localStatus] SADECE istemci tarafında tutulur — REST çağrısı devam
/// ederken iyimser (optimistic) mesajı işaretlemek için kullanılır (bkz.
/// `MessagesController.sendMessage`). Sunucudan gelen hiçbir mesajda
/// [MessageLocalStatus.sent] dışında bir değer olmaz.
enum MessageLocalStatus { sending, sent, failed }

class Message {
  const Message({
    required this.id,
    required this.authorId,
    required this.author,
    this.content,
    required this.type,
    this.replyToId,
    this.replyTo,
    required this.isEdited,
    required this.isPinned,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    required this.attachments,
    required this.reactions,
    this.localStatus = MessageLocalStatus.sent,
  });

  final String id;
  final String authorId;
  final MessageAuthor author;
  final String? content;
  final String type;
  final String? replyToId;
  final ReplyPreview? replyTo;
  final bool isEdited;
  final bool isPinned;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Attachment> attachments;
  final List<RawReaction> reactions;
  final MessageLocalStatus localStatus;

  bool get isReply => type == 'REPLY' && replyTo != null;
  bool get isSystem => type == 'SYSTEM' || type == 'JOIN_SERVER' || type == 'CALL';

  List<GroupedReaction> get groupedReactions {
    final byEmoji = <String, List<String>>{};
    for (final r in reactions) {
      byEmoji.putIfAbsent(r.emoji, () => []).add(r.userId);
    }
    return byEmoji.entries.map((e) => GroupedReaction(emoji: e.key, userIds: e.value)).toList();
  }

  Message copyWith({
    String? content,
    bool? isEdited,
    bool? isPinned,
    bool? isDeleted,
    List<RawReaction>? reactions,
    MessageLocalStatus? localStatus,
    DateTime? updatedAt,
  }) {
    return Message(
      id: id,
      authorId: authorId,
      author: author,
      content: content ?? this.content,
      type: type,
      replyToId: replyToId,
      replyTo: replyTo,
      isEdited: isEdited ?? this.isEdited,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments,
      reactions: reactions ?? this.reactions,
      localStatus: localStatus ?? this.localStatus,
    );
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    final attachmentsJson = json['attachments'] as List<dynamic>? ?? [];
    final reactionsJson = json['reactions'] as List<dynamic>? ?? [];
    final replyToJson = json['replyTo'] as Map<String, dynamic>?;
    return Message(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      author: MessageAuthor.fromJson(json['author'] as Map<String, dynamic>),
      content: json['content'] as String?,
      type: json['type'] as String? ?? 'DEFAULT',
      replyToId: json['replyToId'] as String?,
      replyTo: replyToJson != null ? ReplyPreview.fromJson(replyToJson) : null,
      isEdited: json['isEdited'] as bool? ?? false,
      isPinned: json['isPinned'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? json['createdAt'] as String).toLocal(),
      attachments: attachmentsJson.map((a) => Attachment.fromJson(a as Map<String, dynamic>)).toList(),
      reactions: reactionsJson.map((r) => RawReaction.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }
}
