import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/audit_log_repository.dart';
import '../../data/channels_repository.dart';
import '../../data/invites_repository.dart';
import '../../data/moderation_repository.dart';
import '../../data/roles_repository.dart';
import '../../data/servers_repository.dart';
import '../../domain/audit_log_entry.dart';
import '../../domain/invite.dart';
import '../../domain/server.dart';
import '../../domain/server_ban.dart';
import '../../domain/server_member.dart';
import '../../domain/server_permissions.dart';

final serversRepositoryProvider = Provider<ServersRepository>((ref) {
  return ServersRepository(ref.watch(apiClientProvider));
});

final channelsRepositoryProvider = Provider<ChannelsRepository>((ref) {
  return ChannelsRepository(ref.watch(apiClientProvider));
});

final rolesRepositoryProvider = Provider<RolesRepository>((ref) {
  return RolesRepository(ref.watch(apiClientProvider));
});

final invitesRepositoryProvider = Provider<InvitesRepository>((ref) {
  return InvitesRepository(ref.watch(apiClientProvider));
});

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(apiClientProvider));
});

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  return AuditLogRepository(ref.watch(apiClientProvider));
});

/// Sol raydaki sunucu listesi. Sunucu oluşturma/katılma/silme/ayrılma sonrası
/// `ref.invalidate(serverListProvider)` ile tazelenmesi beklenir.
final serverListProvider = FutureProvider<List<Server>>((ref) {
  return ref.watch(serversRepositoryProvider).listMine();
});

/// Seçili sunucunun kanal + rol listesi + bilgisi. `family` ile `serverId`'ye
/// göre önbelleklenir; kanal/rol CRUD'u sonrası bu provider invalidate edilir.
final serverDetailProvider = FutureProvider.family<ServerDetail, String>((ref, serverId) {
  return ref.watch(serversRepositoryProvider).getDetail(serverId);
});

/// Sunucu üyeleri (rolleriyle birlikte) — moderasyon paneli ve rol atama
/// ekranları için. Rol ata/kaldır, kick/ban/timeout sonrası invalidate edilir.
final serverMembersProvider = FutureProvider.family<List<ServerMember>, String>((ref, serverId) {
  return ref.watch(serversRepositoryProvider).listMembers(serverId);
});

final serverInvitesProvider = FutureProvider.family<List<Invite>, String>((ref, serverId) {
  return ref.watch(invitesRepositoryProvider).listForServer(serverId);
});

final serverBansProvider = FutureProvider.family<List<ServerBan>, String>((ref, serverId) {
  return ref.watch(moderationRepositoryProvider).listBans(serverId);
});

final serverAuditLogProvider = FutureProvider.family<List<AuditLogEntry>, String>((ref, serverId) {
  return ref.watch(auditLogRepositoryProvider).listForServer(serverId);
});

/// Giriş yapmış kullanıcının bir sunucudaki etkin yetkilerini hesaplar
/// (bkz. `MemberPermissions` — `permissions.util.ts`'nin istemci karşılığı).
/// UI'da yönetim ekranlarını/menülerini göstermek-gizlemek için kullanılır;
/// nihai yetkilendirme her zaman backend'de yapılır.
final myServerPermissionsProvider = Provider.family<MemberPermissions, String>((ref, serverId) {
  final detail = ref.watch(serverDetailProvider(serverId)).valueOrNull;
  final members = ref.watch(serverMembersProvider(serverId)).valueOrNull;
  final currentUserId = ref.watch(authControllerProvider).user?.id;
  if (detail == null || members == null || currentUserId == null) {
    return MemberPermissions.empty;
  }
  final isOwner = detail.server.ownerId == currentUserId;
  final me = members.where((m) => m.user.id == currentUserId).toList();
  return MemberPermissions(isOwner: isOwner, roles: me.isNotEmpty ? me.first.roles : const []);
});
