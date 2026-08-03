import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/moderation_action.dart';
import '../domain/server_ban.dart';

/// `/servers/:serverId/moderation` uç noktalarını sarmalar
/// (bkz. `moderation.controller.ts`) — kick/ban/timeout/warn ve geçmiş.
class ModerationRepository {
  ModerationRepository(this._client);

  final ApiClient _client;

  Future<void> kick(String serverId, String userId, {String? reason}) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.moderationKick(serverId, userId), data: {if (reason != null) 'reason': reason}),
      (_) => null,
    );
  }

  Future<void> ban(String serverId, String userId, {String? reason}) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.moderationBan(serverId, userId), data: {if (reason != null) 'reason': reason}),
      (_) => null,
    );
  }

  Future<void> unban(String serverId, String userId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.moderationUnban(serverId, userId)),
      (_) => null,
    );
  }

  Future<List<ServerBan>> listBans(String serverId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.moderationBans(serverId)),
      (data) => (data as List<dynamic>).map((b) => ServerBan.fromJson(b as Map<String, dynamic>)).toList(),
    );
  }

  Future<void> timeout(String serverId, String userId, {required int durationSeconds, String? reason}) {
    return _client.guard(
      () => _client.dio.post(
        ApiConstants.moderationTimeout(serverId, userId),
        data: {'durationSeconds': durationSeconds, if (reason != null) 'reason': reason},
      ),
      (_) => null,
    );
  }

  Future<void> removeTimeout(String serverId, String userId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.moderationTimeout(serverId, userId)),
      (_) => null,
    );
  }

  Future<void> warn(String serverId, String userId, {String? reason}) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.moderationWarn(serverId, userId), data: {if (reason != null) 'reason': reason}),
      (_) => null,
    );
  }

  Future<List<ModerationAction>> history(String serverId, String userId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.moderationHistory(serverId, userId)),
      (data) => (data as List<dynamic>).map((a) => ModerationAction.fromJson(a as Map<String, dynamic>)).toList(),
    );
  }
}
