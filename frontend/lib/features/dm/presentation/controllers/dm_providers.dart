import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/dm_repository.dart';
import '../../domain/dm_channel.dart';

final dmRepositoryProvider = Provider<DmRepository>((ref) {
  return DmRepository(ref.watch(apiClientProvider));
});

/// Orta sütundaki DM listesi (en son mesaja göre azalan sırada — backend
/// zaten bu sırayla döner, bkz. `DmService.listMine`).
final dmListProvider = FutureProvider<List<DmChannel>>((ref) {
  return ref.watch(dmRepositoryProvider).listMine();
});
