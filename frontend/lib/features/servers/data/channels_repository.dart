import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/channel.dart';

/// `/servers/:serverId/channels` uç noktalarını sarmalar
/// (bkz. `channels.controller.ts`) — kanal oluşturma/düzenleme/silme/sıralama.
class ChannelsRepository {
  ChannelsRepository(this._client);

  final ApiClient _client;

  Future<Channel> create(
    String serverId, {
    required String name,
    required String type,
    String? parentId,
    String? topic,
  }) {
    return _client.guard(
      () => _client.dio.post(
        ApiConstants.serverChannels(serverId),
        data: {
          'name': name,
          'type': type,
          if (parentId != null) 'parentId': parentId,
          if (topic != null && topic.isNotEmpty) 'topic': topic,
        },
      ),
      (data) => Channel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Channel> update(
    String serverId,
    String channelId, {
    String? name,
    String? topic,
    bool? isNsfw,
    int? rateLimitPerUser,
    int? bitrate,
    int? userLimit,
  }) {
    return _client.guard(
      () => _client.dio.patch(
        ApiConstants.serverChannel(serverId, channelId),
        data: {
          if (name != null) 'name': name,
          if (topic != null) 'topic': topic,
          if (isNsfw != null) 'isNsfw': isNsfw,
          if (rateLimitPerUser != null) 'rateLimitPerUser': rateLimitPerUser,
          if (bitrate != null) 'bitrate': bitrate,
          if (userLimit != null) 'userLimit': userLimit,
        },
      ),
      (data) => Channel.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> remove(String serverId, String channelId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.serverChannel(serverId, channelId)),
      (_) => null,
    );
  }

  /// `items`: `{id, position, parentId}` üçlülerinin listesi — kanal listesi
  /// yeniden sıralandığında (yukarı/aşağı taşıma) topluca gönderilir.
  Future<void> reorder(String serverId, List<Map<String, dynamic>> items) {
    return _client.guard(
      () => _client.dio.put(
        ApiConstants.serverChannelsReorder(serverId),
        data: {'channels': items},
      ),
      (_) => null,
    );
  }
}
