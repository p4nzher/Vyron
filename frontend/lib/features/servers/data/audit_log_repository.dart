import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/audit_log_entry.dart';

/// `/servers/:serverId/audit-log` uç noktasını sarmalar (bkz. `audit-log.controller.ts`).
class AuditLogRepository {
  AuditLogRepository(this._client);

  final ApiClient _client;

  Future<List<AuditLogEntry>> listForServer(String serverId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.serverAuditLog(serverId)),
      (data) => (data as List<dynamic>).map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
