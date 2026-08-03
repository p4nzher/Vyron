import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/invite.dart';
import '../domain/server.dart';

/// `/servers/:serverId/invites` (yönetim) ve `/invites/:code` (önizleme/katılma)
/// uç noktalarını sarmalar (bkz. `invites.controller.ts`).
class InvitesRepository {
  InvitesRepository(this._client);

  final ApiClient _client;

  Future<Invite> create(String serverId, {int? maxUses, int? expiresInSeconds}) {
    return _client.guard(
      () => _client.dio.post(
        ApiConstants.serverInvites(serverId),
        data: {
          if (maxUses != null) 'maxUses': maxUses,
          if (expiresInSeconds != null) 'expiresInSeconds': expiresInSeconds,
        },
      ),
      (data) => Invite.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<List<Invite>> listForServer(String serverId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.serverInvites(serverId)),
      (data) => (data as List<dynamic>).map((i) => Invite.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> revoke(String serverId, String inviteId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.serverInvite(serverId, inviteId)),
      (_) => null,
    );
  }

  Future<InvitePreview> preview(String code) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.invitePreview(code)),
      (data) => InvitePreview.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Server> join(String code) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.inviteJoin(code)),
      (data) => Server.fromJson((data as Map<String, dynamic>)['server'] as Map<String, dynamic>),
    );
  }
}
