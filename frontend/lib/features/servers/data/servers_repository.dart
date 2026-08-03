import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/server.dart';
import '../domain/server_member.dart';

/// `/servers` uç noktalarını sarmalar: okuma (Faz 6.3) + oluşturma, ayarları
/// güncelleme, silme, üye listeleme/güncelleme, sunucudan ayrılma (Faz 6.6).
class ServersRepository {
  ServersRepository(this._client);

  final ApiClient _client;

  Future<List<Server>> listMine() {
    return _client.guard(
      () => _client.dio.get(ApiConstants.servers),
      (data) => (data as List<dynamic>)
          .map((s) => Server.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ServerDetail> getDetail(String serverId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.server(serverId)),
      (data) => ServerDetail.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Server> create({required String name, String? description, String? iconUrl}) {
    return _client.guard(
      () => _client.dio.post(
        ApiConstants.servers,
        data: {
          'name': name,
          if (description != null && description.isNotEmpty) 'description': description,
          if (iconUrl != null && iconUrl.isNotEmpty) 'iconUrl': iconUrl,
        },
      ),
      (data) => Server.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Server> update(
    String serverId, {
    String? name,
    String? description,
    String? iconUrl,
    String? bannerUrl,
    bool? isPublic,
  }) {
    return _client.guard(
      () => _client.dio.patch(
        ApiConstants.server(serverId),
        data: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (iconUrl != null) 'iconUrl': iconUrl,
          if (bannerUrl != null) 'bannerUrl': bannerUrl,
          if (isPublic != null) 'isPublic': isPublic,
        },
      ),
      (data) => Server.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> delete(String serverId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.server(serverId)),
      (_) => null,
    );
  }

  Future<void> leave(String serverId) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.serverLeave(serverId)),
      (_) => null,
    );
  }

  Future<List<ServerMember>> listMembers(String serverId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.serverMembers(serverId)),
      (data) => (data as List<dynamic>)
          .map((m) => ServerMember.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ServerMember> updateMemberNickname(String serverId, String memberId, String? nickname) {
    return _client.guard(
      () => _client.dio.patch(
        ApiConstants.serverMember(serverId, memberId),
        data: {'nickname': nickname},
      ),
      (data) => ServerMember.fromJson(data as Map<String, dynamic>),
    );
  }
}
