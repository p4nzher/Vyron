import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Access/refresh token'ları platformun güvenli deposunda (Keychain/Keystore)
/// saklar. Asla `SharedPreferences` gibi düz metin depolama kullanılmaz —
/// bu, JWT'lerin cihaz ele geçirilse dahi kolayca okunmasını engeller.
class SecureStorageService {
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'vyron.access_token';
  static const _refreshTokenKey = 'vyron.refresh_token';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<bool> get hasSession async => (await accessToken) != null;
}
