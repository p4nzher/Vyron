import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/role.dart';

/// `/servers/:serverId/roles` uç noktalarını sarmalar (bkz. `roles.controller.ts`).
class RolesRepository {
  RolesRepository(this._client);

  final ApiClient _client;

  Future<List<Role>> list(String serverId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.serverRoles(serverId)),
      (data) => (data as List<dynamic>).map((r) => Role.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }

  Future<Role> create(
    String serverId, {
    required String name,
    String? color,
    Map<String, bool>? permissions,
    bool? isHoisted,
    bool? isMentionable,
  }) {
    return _client.guard(
      () => _client.dio.post(
        ApiConstants.serverRoles(serverId),
        data: {
          'name': name,
          if (color != null) 'color': color,
          if (permissions != null) 'permissions': permissions,
          if (isHoisted != null) 'isHoisted': isHoisted,
          if (isMentionable != null) 'isMentionable': isMentionable,
        },
      ),
      (data) => Role.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Role> update(
    String serverId,
    String roleId, {
    String? name,
    String? color,
    Map<String, bool>? permissions,
    bool? isHoisted,
    bool? isMentionable,
    int? position,
  }) {
    return _client.guard(
      () => _client.dio.patch(
        ApiConstants.serverRole(serverId, roleId),
        data: {
          if (name != null) 'name': name,
          if (color != null) 'color': color,
          if (permissions != null) 'permissions': permissions,
          if (isHoisted != null) 'isHoisted': isHoisted,
          if (isMentionable != null) 'isMentionable': isMentionable,
          if (position != null) 'position': position,
        },
      ),
      (data) => Role.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<void> remove(String serverId, String roleId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.serverRole(serverId, roleId)),
      (_) => null,
    );
  }

  Future<void> assignToMember(String serverId, String memberId, String roleId) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.serverRoleAssign(serverId, memberId, roleId)),
      (_) => null,
    );
  }

  Future<void> removeFromMember(String serverId, String memberId, String roleId) {
    return _client.guard(
      () => _client.dio.delete(ApiConstants.serverRoleAssign(serverId, memberId, roleId)),
      (_) => null,
    );
  }
}
