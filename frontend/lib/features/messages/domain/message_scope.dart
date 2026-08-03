/// Backend'deki `MessageScope` (bkz. `messages.service.ts`) tam karşılığı:
/// bir mesaj dizisinin bir SUNUCU KANALI'na mı yoksa bir ÖZEL MESAJ (DM)
/// kanalına mı ait olduğunu tarif eder. `MessagesRepository`, `SocketService`
/// oda adları ve `MessagesController` bu tek tipi kullanarak kanal/DM
/// arasındaki farkı tek bir yerde (repository) izole eder.
class MessageScope {
  const MessageScope._({this.channelId, this.dmChannelId});

  factory MessageScope.channel(String channelId) => MessageScope._(channelId: channelId);
  factory MessageScope.dm(String dmChannelId) => MessageScope._(dmChannelId: dmChannelId);

  final String? channelId;
  final String? dmChannelId;

  bool get isChannel => channelId != null;

  /// `Riverpod` `family` anahtarı ve socket oda eşleşmesi için kararlı kimlik.
  String get key => isChannel ? 'channel:$channelId' : 'dm:$dmChannelId';

  @override
  bool operator ==(Object other) => other is MessageScope && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'MessageScope($key)';
}
