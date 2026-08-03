import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';

/// Uygulama genelinde kullanılan tek Dio istemcisi.
///
/// Sorumlulukları:
///  1) Her isteğe otomatik olarak `Authorization: Bearer <accessToken>` ekler.
///  2) Bir istek 401 ile dönerse: (a) zaten devam eden bir refresh varsa ona
///     "kuyruğa girer", yoksa yeni bir refresh başlatır, (b) refresh başarılı
///     olursa orijinal isteği yeni token ile SESSİZCE tekrar dener, (c) refresh
///     de başarısız olursa oturumu temizler ve [onSessionExpired] çağrılır
///     (örn. giriş ekranına yönlendirmek için — bkz. Faz 6.2 `AuthController`).
///  3) Eş zamanlı birden fazla isteğin aynı anda birden fazla refresh
///     çağrısı tetiklemesini (thundering herd) `_refreshCompleter` ile önler.
class ApiClient {
  ApiClient({required this.storage}) {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Refresh çağrısı İÇİN AYRI, interceptor'sız bir Dio örneği — aksi halde
    // refresh isteğinin kendisi 401 dönerse sonsuz döngüye girilir.
    _refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

    dio.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          final isAuthEndpoint = error.requestOptions.path.contains('/auth/');
          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            try {
              final newAccessToken = await _refreshAccessToken();
              final retryOptions = error.requestOptions;
              retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              final response = await dio.fetch(retryOptions);
              return handler.resolve(response);
            } catch (_) {
              await storage.clear();
              onSessionExpired?.call();
            }
          }
          handler.next(error);
        },
      ),
      if (const bool.fromEnvironment('dart.vm.product') == false)
        PrettyDioLogger(requestBody: true, responseBody: true, error: true, compact: true),
    ]);
  }

  late final Dio dio;
  late final Dio _refreshDio;
  final SecureStorageService storage;

  /// Refresh token da geçersizse (kullanıcı başka bir yerden çıkış yapmış,
  /// token iptal edilmiş vb.) çağrılır. `main.dart`/router seviyesinde
  /// kullanıcıyı giriş ekranına yönlendirmek için dinlenmelidir.
  void Function()? onSessionExpired;

  Future<void>? _refreshCompleter;

  Future<String> _refreshAccessToken() async {
    // Zaten devam eden bir refresh varsa onu bekle, yeni bir tane başlatma.
    if (_refreshCompleter != null) {
      await _refreshCompleter;
      final token = await storage.accessToken;
      if (token == null) throw ApiException(statusCode: 401, message: 'Oturum yenilenemedi.');
      return token;
    }

    final completer = _doRefresh();
    _refreshCompleter = completer;
    try {
      await completer;
    } finally {
      _refreshCompleter = null;
    }
    final token = await storage.accessToken;
    if (token == null) throw ApiException(statusCode: 401, message: 'Oturum yenilenemedi.');
    return token;
  }

  Future<void> _doRefresh() async {
    final refreshToken = await storage.refreshToken;
    if (refreshToken == null) {
      throw ApiException(statusCode: 401, message: 'Yenileme token’ı bulunamadı.');
    }
    final response = await _refreshDio.post<Map<String, dynamic>>(
      ApiConstants.refresh,
      data: {'refreshToken': refreshToken},
    );
    final data = response.data!;
    await storage.saveTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  /// GET/POST/PATCH/DELETE çağrılarını `ApiException` ile sarmalayan yardımcı.
  Future<T> guard<T>(Future<Response<dynamic>> Function() request, T Function(dynamic data) parse) async {
    try {
      final response = await request();
      return parse(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
