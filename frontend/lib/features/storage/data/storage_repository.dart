import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Backend `UploadContext` enum'ıyla birebir eşleşir (bkz.
/// `backend/src/modules/storage/dto/storage.dto.ts`).
abstract final class UploadContext {
  static const String avatar = 'AVATAR';
  static const String banner = 'BANNER';
  static const String serverIcon = 'SERVER_ICON';
  static const String serverBanner = 'SERVER_BANNER';
  static const String messageAttachment = 'MESSAGE_ATTACHMENT';
  static const String voiceNote = 'VOICE_NOTE';
  static const String customEmoji = 'CUSTOM_EMOJI';
  static const String sticker = 'STICKER';
}

/// `POST /storage/presigned-upload` yanıtı.
class PresignedUpload {
  const PresignedUpload({
    required this.uploadUrl,
    required this.key,
    required this.publicUrl,
    required this.expiresInSeconds,
  });

  /// Dosyanın PUT edileceği kısa ömürlü, imzalı S3/R2 URL'i.
  final String uploadUrl;
  final String key;

  /// Yükleme tamamlandıktan sonra dosyaya erişmek için kullanılacak kalıcı URL
  /// — `updateProfile(avatarUrl: ...)` gibi çağrılara bu değer verilir.
  final String publicUrl;
  final int expiresInSeconds;

  factory PresignedUpload.fromJson(Map<String, dynamic> json) {
    return PresignedUpload(
      uploadUrl: json['uploadUrl'] as String,
      key: json['key'] as String,
      publicUrl: json['publicUrl'] as String,
      expiresInSeconds: json['expiresInSeconds'] as int,
    );
  }
}

/// S3/R2 uyumlu depolamaya doğrudan (backend bypass) dosya yükleme akışını
/// sarmalar: (1) backend'den presigned URL iste, (2) dosyayı doğrudan o
/// URL'e PUT et. Bkz. Faz 6.2 avatar yükleme, ileride sunucu ikonu/emoji vb.
class StorageRepository {
  StorageRepository(this._client);

  final ApiClient _client;

  Future<PresignedUpload> requestUpload({
    required String fileName,
    required String mimeType,
    required int fileSizeBytes,
    required String context,
  }) {
    return _client.guard(
      () => _client.dio.post(ApiConstants.presignedUpload, data: {
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSizeBytes': fileSizeBytes,
        'context': context,
      }),
      (data) => PresignedUpload.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Presigned URL'e ham dosya baytlarını yükler. Bilerek `_client.dio`
  /// KULLANILMAZ: o istemci her isteğe otomatik `Authorization: Bearer ...`
  /// ekler, ancak S3/R2 imzalı URL'leri fazladan/beklenmeyen başlıklara karşı
  /// hassas olabilir — bu yüzden burada çıplak bir `Dio` örneği kullanılır.
  Future<void> uploadBytes({
    required String uploadUrl,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final rawDio = Dio();
    try {
      await rawDio.put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': mimeType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Tek adımda: presigned URL al + yükle. Yüklenen dosyanın kalıcı erişim
  /// URL'ini döner.
  Future<String> uploadFile({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required String context,
  }) async {
    final presigned = await requestUpload(
      fileName: fileName,
      mimeType: mimeType,
      fileSizeBytes: bytes.length,
      context: context,
    );
    await uploadBytes(uploadUrl: presigned.uploadUrl, bytes: bytes, mimeType: mimeType);
    return presigned.publicUrl;
  }
}
