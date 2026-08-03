import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../dm/presentation/controllers/dm_providers.dart';

/// Arkadaş listesinden "Mesaj Gönder"e basıldığında birebir DM'i açar/oluşturur
/// ve doğrudan o konuşmaya yönlendirir. `FriendsScreen` `context.push` ile
/// açıldığı için `context.go` kasıtlı kullanılır — bu, üstteki imperative
/// sayfayı da temizleyip kullanıcıyı doğrudan ana kabuktaki DM ekranına götürür.
mixin StartDmMixin {
  Future<void> startDmWith(BuildContext context, WidgetRef ref, String otherUserId) async {
    try {
      final channel = await ref.read(dmRepositoryProvider).createOrGet([otherUserId]);
      ref.invalidate(dmListProvider);
      if (context.mounted) context.go(AppRoutes.dmPath(channel.id));
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
