import 'package:dio/dio.dart';

/// Backend'in standart hata gövdesini ({message, code?, statusCode}) sarmalayan
/// tip-güvenli istisna. UI katmanı, ham `DioException` yerine bunu yakalar.
class ApiException implements Exception {
  ApiException({required this.statusCode, required this.message, this.code});

  final int? statusCode;
  final String message;
  final String? code;

  factory ApiException.fromDioException(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final rawMessage = data['message'];
      final message = rawMessage is List ? rawMessage.join(', ') : (rawMessage?.toString() ?? e.message);
      return ApiException(
        statusCode: e.response?.statusCode,
        message: message ?? 'Bilinmeyen bir hata oluştu.',
        code: data['code'] as String?,
      );
    }
    return ApiException(
      statusCode: e.response?.statusCode,
      message: e.message ?? 'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
    );
  }

  bool get isTwoFactorRequired => code == 'TWO_FACTOR_REQUIRED';

  @override
  String toString() => message;
}
