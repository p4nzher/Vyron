/// Backend uç noktalarının merkezi tanımı.
///
/// NOT: Android emin (emulator) üzerinden yerel backend'e erişim için
/// `localhost` yerine `10.0.2.2` kullanılmalıdır; iOS simülatörde `localhost`
/// çalışır. Gerçek cihazda bilgisayarınızın yerel ağ IP'sini kullanın.
/// Üretimde bu değer `--dart-define=API_BASE_URL=...` ile ezilmelidir.
abstract final class ApiConstants {
  static const String _defaultBaseUrl = 'http://localhost:3000/api/v1';
  static const String _defaultSocketUrl = 'http://localhost:3000';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_BASE_URL',
    defaultValue: _defaultSocketUrl,
  );

  static const String realtimeNamespace = '/realtime';

  // --- Auth ---
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String twoFactorGenerate = '/auth/2fa/generate';
  static const String twoFactorEnable = '/auth/2fa/enable';
  static const String twoFactorDisable = '/auth/2fa/disable';

  // --- Users ---
  static const String me = '/users/me';
  static const String meStatus = '/users/me/status';

  // --- Storage ---
  static const String presignedUpload = '/storage/presigned-upload';

  // --- Servers / Channels (bkz. Faz 6.3 ana kabuk) ---
  static const String servers = '/servers';
  static String server(String serverId) => '/servers/$serverId';
  static String serverLeave(String serverId) => '/servers/$serverId/leave';
  static String serverMembers(String serverId) => '/servers/$serverId/members';
  static String serverMember(String serverId, String memberId) => '/servers/$serverId/members/$memberId';
  static String serverChannels(String serverId) => '/servers/$serverId/channels';

  // --- Kanal CRUD (Faz 6.6, `channels.controller.ts`) ---
  static String serverChannel(String serverId, String channelId) => '/servers/$serverId/channels/$channelId';
  static String serverChannelsReorder(String serverId) => '/servers/$serverId/channels/reorder';

  // --- Roller (Faz 6.6, `roles.controller.ts`) ---
  static String serverRoles(String serverId) => '/servers/$serverId/roles';
  static String serverRole(String serverId, String roleId) => '/servers/$serverId/roles/$roleId';
  static String serverRoleAssign(String serverId, String memberId, String roleId) =>
      '/servers/$serverId/roles/members/$memberId/$roleId';

  // --- Davetler (Faz 6.6, `invites.controller.ts`) ---
  static String serverInvites(String serverId) => '/servers/$serverId/invites';
  static String serverInvite(String serverId, String inviteId) => '/servers/$serverId/invites/$inviteId';
  static String invitePreview(String code) => '/invites/$code';
  static String inviteJoin(String code) => '/invites/$code/join';

  // --- Moderasyon (Faz 6.6, `moderation.controller.ts`) ---
  static String moderationKick(String serverId, String userId) => '/servers/$serverId/moderation/members/$userId/kick';
  static String moderationBan(String serverId, String userId) => '/servers/$serverId/moderation/members/$userId/ban';
  static String moderationUnban(String serverId, String userId) => '/servers/$serverId/moderation/bans/$userId';
  static String moderationBans(String serverId) => '/servers/$serverId/moderation/bans';
  static String moderationTimeout(String serverId, String userId) =>
      '/servers/$serverId/moderation/members/$userId/timeout';
  static String moderationWarn(String serverId, String userId) => '/servers/$serverId/moderation/members/$userId/warn';
  static String moderationHistory(String serverId, String userId) =>
      '/servers/$serverId/moderation/members/$userId/history';

  // --- Denetim Kaydı (Faz 6.6, `audit-log.controller.ts`) ---
  static String serverAuditLog(String serverId) => '/servers/$serverId/audit-log';

  // --- Direkt Mesajlar (bkz. Faz 6.3 ana kabuk) ---
  static const String dmChannels = '/dm-channels';
  static String dmChannel(String dmChannelId) => '/dm-channels/$dmChannelId';

  // --- Arkadaşlar (Faz 6.7, `friends.controller.ts`) ---
  static const String friends = '/friends';
  static const String friendRequestsIncoming = '/friends/requests/incoming';
  static const String friendRequestsOutgoing = '/friends/requests/outgoing';
  static const String friendRequests = '/friends/requests';
  static const String friendRequestAccept = '/friends/requests/accept';
  static const String friendRequestReject = '/friends/requests/reject';
  static String friendRequestCancel(String friendshipId) => '/friends/requests/$friendshipId';
  static String friend(String userId) => '/friends/$userId';
  static const String friendsBlocked = '/friends/blocked';
  static String friendBlock(String userId) => '/friends/blocked/$userId';

  // --- Mesajlar — Kanal kapsamı (bkz. Faz 6.4, `messages.controller.ts`) ---
  static String channelMessages(String channelId) => '/channels/$channelId/messages';
  static String channelMessage(String channelId, String messageId) =>
      '/channels/$channelId/messages/$messageId';
  static String channelMessagePin(String channelId, String messageId) =>
      '/channels/$channelId/messages/$messageId/pin';
  static String channelMessageReactions(String channelId, String messageId) =>
      '/channels/$channelId/messages/$messageId/reactions';
  static String channelMessageReaction(String channelId, String messageId, String emoji) =>
      '/channels/$channelId/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}';

  // --- Mesajlar — DM kapsamı (bkz. Faz 6.4, `dm.controller.ts`) ---
  static String dmMessages(String dmChannelId) => '/dm-channels/$dmChannelId/messages';
  static String dmMessage(String dmChannelId, String messageId) =>
      '/dm-channels/$dmChannelId/messages/$messageId';
  static String dmMessageReactions(String dmChannelId, String messageId) =>
      '/dm-channels/$dmChannelId/messages/$messageId/reactions';
  static String dmMessageReaction(String dmChannelId, String messageId, String emoji) =>
      '/dm-channels/$dmChannelId/messages/$messageId/reactions/${Uri.encodeComponent(emoji)}';

  // --- Sesli/Görüntülü Görüşme (bkz. Faz 6.5, `voice.controller.ts`) ---
  static String voiceJoin(String channelId) => '/channels/$channelId/voice/join';
  static String voiceLeave(String channelId) => '/channels/$channelId/voice/leave';
  static String voiceState(String channelId) => '/channels/$channelId/voice/state';
  static String voiceParticipants(String channelId) => '/channels/$channelId/voice/participants';
  static String voiceMemberMute(String channelId, String userId) =>
      '/channels/$channelId/voice/members/$userId/mute';
  static String voiceMemberDeafen(String channelId, String userId) =>
      '/channels/$channelId/voice/members/$userId/deafen';
  static String voiceMemberMove(String channelId, String userId) =>
      '/channels/$channelId/voice/members/$userId/move';
  static String voiceMemberDisconnect(String channelId, String userId) =>
      '/channels/$channelId/voice/members/$userId';
}
