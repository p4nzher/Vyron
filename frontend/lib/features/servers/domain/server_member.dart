import 'role.dart';

/// `GET /servers/:serverId/members` yanıtındaki her öge
/// (bkz. `ServersService.MEMBER_PUBLIC_SELECT`).
class ServerMemberUser {
  const ServerMemberUser({
    required this.id,
    required this.username,
    required this.discriminator,
    this.displayName,
    this.avatarUrl,
    this.status,
  });

  final String id;
  final String username;
  final String discriminator;
  final String? displayName;
  final String? avatarUrl;
  final String? status;

  String get tag => '$username#$discriminator';

  factory ServerMemberUser.fromJson(Map<String, dynamic> json) {
    return ServerMemberUser(
      id: json['id'] as String,
      username: json['username'] as String,
      discriminator: json['discriminator'] as String? ?? '0000',
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      status: json['status'] as String?,
    );
  }
}

class ServerMember {
  const ServerMember({
    required this.id,
    required this.user,
    required this.roles,
    this.nickname,
    this.timeoutUntil,
    this.isMuted = false,
    this.isDeafened = false,
  });

  final String id;
  final ServerMemberUser user;
  final List<Role> roles;
  final String? nickname;
  final DateTime? timeoutUntil;
  final bool isMuted;
  final bool isDeafened;

  String get displayName => nickname ?? user.displayName ?? user.username;

  bool get isTimedOut => timeoutUntil != null && timeoutUntil!.isAfter(DateTime.now());

  factory ServerMember.fromJson(Map<String, dynamic> json) {
    final rolesJson = (json['roles'] as List<dynamic>? ?? []);
    return ServerMember(
      id: json['id'] as String,
      user: ServerMemberUser.fromJson(json['user'] as Map<String, dynamic>),
      // Backend `MemberRole` ara tablosunu `{ role: {...} }` şeklinde include
      // eder — burada düzleştirilir.
      roles: rolesJson
          .map((r) => Role.fromJson((r as Map<String, dynamic>)['role'] as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.position.compareTo(a.position)),
      nickname: json['nickname'] as String?,
      timeoutUntil: json['timeoutUntil'] != null ? DateTime.tryParse(json['timeoutUntil'] as String) : null,
      isMuted: json['isMuted'] as bool? ?? false,
      isDeafened: json['isDeafened'] as bool? ?? false,
    );
  }
}
