import 'package:flutter/material.dart';

/// Backend `Role` modeli (bkz. `prisma/schema.prisma`) ile birebir eşleşir.
/// `permissions`, backend'de olduğu gibi anahtarı yetki adı, değeri
/// boolean olan düz bir JSON obje (bkz. `ServerPermission`).
class Role {
  const Role({
    required this.id,
    required this.serverId,
    required this.name,
    required this.color,
    required this.position,
    required this.isHoisted,
    required this.isMentionable,
    required this.permissions,
  });

  final String id;
  final String serverId;
  final String name;
  final String color;
  final int position;
  final bool isHoisted;
  final bool isMentionable;
  final Map<String, bool> permissions;

  bool get isEveryone => name == '@everyone';

  Color get displayColor {
    final hex = color.replaceFirst('#', '');
    if (hex.length != 6) return const Color(0xFF99AAB5);
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory Role.fromJson(Map<String, dynamic> json) {
    final rawPerms = json['permissions'];
    return Role(
      id: json['id'] as String,
      serverId: json['serverId'] as String? ?? '',
      name: json['name'] as String,
      color: json['color'] as String? ?? '#99AAB5',
      position: json['position'] as int? ?? 0,
      isHoisted: json['isHoisted'] as bool? ?? false,
      isMentionable: json['isMentionable'] as bool? ?? true,
      permissions: rawPerms is Map
          ? rawPerms.map((key, value) => MapEntry(key as String, value == true))
          : <String, bool>{},
    );
  }
}
