import 'channel.dart';
import 'role.dart';

/// `GET /servers` yanıtındaki her öge — sol raydaki sunucu ikonları için
/// yeterli, minimal alan seti (bkz. `ServersService.findMyServers`).
class Server {
  const Server({
    required this.id,
    required this.name,
    required this.ownerId,
    this.description,
    this.iconUrl,
    this.bannerUrl,
  });

  final String id;
  final String name;
  final String ownerId;
  final String? description;
  final String? iconUrl;
  final String? bannerUrl;

  /// Rayda ikon yoksa gösterilecek baş harfler — çok kelimeliyse ilk
  /// harfler, tek kelimeliyse ilk iki harf.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['ownerId'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
    );
  }
}

/// `GET /servers/:serverId` yanıtı — sunucu bilgisi + kanal listesi + roller
/// (bkz. Faz 6.6 — `ServersService.getDetail`, roller hiyerarşi sırasında
/// azalan `position` ile döner, yani ilk eleman en yetkili roldür).
class ServerDetail {
  const ServerDetail({required this.server, required this.channels, this.roles = const []});

  final Server server;
  final List<Channel> channels;
  final List<Role> roles;

  factory ServerDetail.fromJson(Map<String, dynamic> json) {
    final channelsJson = (json['channels'] as List<dynamic>? ?? []);
    final rolesJson = (json['roles'] as List<dynamic>? ?? []);
    return ServerDetail(
      server: Server.fromJson(json),
      channels: channelsJson
          .map((c) => Channel.fromJson(c as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position)),
      roles: rolesJson.map((r) => Role.fromJson(r as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.position.compareTo(a.position)),
    );
  }
}
