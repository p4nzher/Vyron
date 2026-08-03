/// Backend `Channel` modeli (bkz. `prisma/schema.prisma`) ile birebir
/// eşleşen istemci taraflı model. `ChannelType`: 'TEXT' | 'VOICE' |
/// 'ANNOUNCEMENT' | 'STAGE' | 'CATEGORY'.
class Channel {
  const Channel({
    required this.id,
    required this.serverId,
    required this.name,
    required this.type,
    required this.position,
    this.topic,
    this.parentId,
  });

  final String id;
  final String serverId;
  final String name;
  final String type;
  final int position;
  final String? topic;
  final String? parentId;

  bool get isVoice => type == 'VOICE' || type == 'STAGE';
  bool get isCategory => type == 'CATEGORY';

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      serverId: json['serverId'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'TEXT',
      position: json['position'] as int? ?? 0,
      topic: json['topic'] as String?,
      parentId: json['parentId'] as String?,
    );
  }
}
