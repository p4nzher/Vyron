import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/dm_channel.dart';

/// `GET /dm-channels` ve `GET /dm-channels/:id` uç noktalarını sarmalar.
/// Yeni DM başlatma (`POST /dm-channels`) Faz 6.7'de eklendi — arkadaş
/// listesinden "Mesaj Gönder" (bkz. `friends/presentation/screens/friends_screen.dart`).
class DmRepository {
  DmRepository(this._client);

  final ApiClient _client;

  Future<List<DmChannel>> listMine() {
    return _client.guard(
      () => _client.dio.get(ApiConstants.dmChannels),
      (data) => (data as List<dynamic>)
          .map((c) => DmChannel.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<DmChannel> getOne(String dmChannelId) {
    return _client.guard(
      () => _client.dio.get(ApiConstants.dmChannel(dmChannelId)),
      (data) => DmChannel.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Birebir ya da grup DM oluşturur — backend zaten var olan birebir DM'i
  /// varsa onu döner (`DmService.createOrGet`), yani bu her zaman güvenle
  /// "aç ya da oluştur" gibi çağrılabilir.
  Future<DmChannel> createOrGet(List<String> participantIds, {bool isGroup = false, String? name}) {
    return _client.guard(
      () => _client.dio.post(
        ApiConstants.dmChannels,
        data: {
          'participantIds': participantIds,
          if (isGroup) 'isGroup': isGroup,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      ),
      (data) => DmChannel.fromJson(data as Map<String, dynamic>),
    );
  }
}
