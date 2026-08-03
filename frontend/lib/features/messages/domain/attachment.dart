/// Backend `Attachment` modeli ile birebir eşleşir (bkz.
/// `backend/prisma/schema.prisma`). `type`: 'IMAGE' | 'VIDEO' | 'AUDIO' |
/// 'FILE' | 'VOICE_NOTE' | 'STICKER' | 'GIF'.
class Attachment {
  const Attachment({
    required this.id,
    required this.type,
    required this.url,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    this.width,
    this.height,
    this.durationMs,
  });

  final String id;
  final String type;
  final String url;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  final int? width;
  final int? height;
  final int? durationMs;

  bool get isImage => type == 'IMAGE' || type == 'STICKER' || type == 'GIF';
  bool get isVideo => type == 'VIDEO';
  bool get isAudio => type == 'AUDIO' || type == 'VOICE_NOTE';
  bool get isVoiceNote => type == 'VOICE_NOTE';

  String get humanSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory Attachment.fromJson(Map<String, dynamic> json) {
    return Attachment(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'FILE',
      url: json['url'] as String,
      fileName: json['fileName'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      width: json['width'] as int?,
      height: json['height'] as int?,
      durationMs: json['durationMs'] as int?,
    );
  }

  /// `POST /storage/presigned-upload` sonrası yüklenen dosyayı
  /// `CreateMessageDto.attachments` gövdesine dönüştürür (bkz.
  /// `messages.dto.ts` — `AttachmentInputDto`, `type` alanı BİLEREK yok,
  /// sunucu `mimeType`'tan yeniden hesaplar).
  static Map<String, dynamic> toCreateInput({
    required String url,
    required String fileName,
    required int fileSizeBytes,
    required String mimeType,
    int? width,
    int? height,
    int? durationMs,
    bool isVoiceNote = false,
  }) {
    return {
      'url': url,
      'fileName': fileName,
      'fileSizeBytes': fileSizeBytes,
      'mimeType': mimeType,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'durationMs': durationMs,
      if (isVoiceNote) 'isVoiceNote': true,
    };
  }
}
