import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../storage/data/storage_repository.dart';
import '../../domain/attachment.dart';
import '../../domain/message_scope.dart';
import '../controllers/messages_providers.dart';
import 'emoji_picker_sheet.dart';

/// Faz 6.4: `MessageInput` içindeki ek (attachment) yükleme akışı için.
/// `apiClientProvider` üzerinden aynı tekil `Dio` istemcisini paylaşır (bkz.
/// `auth_controller.dart` — GetIt köprüsü).
final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return StorageRepository(ref.watch(apiClientProvider));
});

/// Bir bekleyen (henüz gönderilmemiş) ek. Seçildiği an yüklenmeye başlar;
/// [uploadedInput] dolana kadar gönder butonu bu eki bekletir.
class _PendingAttachment {
  _PendingAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    this.isVoiceNote = false,
    this.uploading = true,
    this.uploadedInput,
    this.width,
    this.height,
    this.durationMs,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final bool isVoiceNote;
  bool uploading;
  Map<String, dynamic>? uploadedInput;
  int? width;
  int? height;
  int? durationMs;

  bool get isImage => mimeType.startsWith('image/');
  bool get isAudio => mimeType.startsWith('audio/');
}

class MessageInput extends ConsumerStatefulWidget {
  const MessageInput({required this.scope, super.key});

  final MessageScope scope;

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _pending = <_PendingAttachment>[];
  final _recorder = AudioRecorder();

  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  String? _recordingPath;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    super.dispose();
  }

  MessagesController get _controller => ref.read(messagesControllerProvider(widget.scope).notifier);

  void _onTextChanged(String value) {
    if (value.trim().isNotEmpty) {
      _controller.notifyTyping();
    } else {
      _controller.stopTyping();
    }
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    final readyAttachments = _pending.where((a) => a.uploadedInput != null).map((a) => a.uploadedInput!).toList();
    final stillUploading = _pending.any((a) => a.uploading);

    if (stillUploading) return; // Yüklemeler bitmeden gönderime izin verme.
    if (text.isEmpty && readyAttachments.isEmpty) return;

    final editing = ref.read(messagesControllerProvider(widget.scope)).editingMessage;
    if (editing != null) {
      await _controller.submitEdit(text);
    } else {
      await _controller.send(content: text.isEmpty ? null : text, attachments: readyAttachments);
    }

    _textController.clear();
    setState(() => _pending.clear());
    _controller.stopTyping();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await _uploadAndStage(
      fileName: file.name,
      mimeType: _guessMimeType(file.name, fallback: 'image/jpeg'),
      bytes: bytes,
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    await _uploadAndStage(
      fileName: file.name,
      mimeType: _guessMimeType(file.name, fallback: 'application/octet-stream'),
      bytes: bytes,
    );
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path == null) return;
      final bytes = await File(path).readAsBytes();
      await _uploadAndStage(
        fileName: 'sesli-not.m4a',
        mimeType: 'audio/mp4',
        bytes: bytes,
        isVoiceNote: true,
        durationMs: _recordDuration.inMilliseconds,
      );
      _recordDuration = Duration.zero;
      return;
    }

    if (kIsWeb) return; // Web'de dosya sistemi yolu gerektiren kayıt Faz 6.5+'ta ele alınacak.

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final path = '${Directory.systemTemp.path}/vyron-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordingPath = path;
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    _tickRecording();
  }

  void _tickRecording() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_isRecording) return;
      setState(() => _recordDuration += const Duration(seconds: 1));
      _tickRecording();
    });
  }

  Future<void> _uploadAndStage({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    bool isVoiceNote = false,
    int? durationMs,
  }) async {
    final id = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = _PendingAttachment(
      id: id,
      fileName: fileName,
      mimeType: mimeType,
      isVoiceNote: isVoiceNote,
      durationMs: durationMs,
    );
    setState(() => _pending.add(pending));

    try {
      final storage = ref.read(storageRepositoryProvider);
      final publicUrl = await storage.uploadFile(
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
        context: isVoiceNote ? UploadContext.voiceNote : UploadContext.messageAttachment,
      );
      pending.uploadedInput = Attachment.toCreateInput(
        url: publicUrl,
        fileName: fileName,
        fileSizeBytes: bytes.length,
        mimeType: mimeType,
        durationMs: durationMs,
        isVoiceNote: isVoiceNote,
      );
      pending.uploading = false;
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _pending.removeWhere((a) => a.id == id));
    }
  }

  String _guessMimeType(String fileName, {required String fallback}) {
    final ext = fileName.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'wav': 'audio/wav',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'zip': 'application/zip',
    };
    return map[ext] ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesControllerProvider(widget.scope));

    ref.listen(messagesControllerProvider(widget.scope), (previous, next) {
      if (previous?.editingMessage?.id != next.editingMessage?.id && next.editingMessage != null) {
        _textController.text = next.editingMessage!.content ?? '';
        _textController.selection = TextSelection.collapsed(offset: _textController.text.length);
        _focusNode.requestFocus();
      }
    });

    final isEditing = state.editingMessage != null;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.replyingTo != null) _ReplyBar(name: state.replyingTo!.author.name, onCancel: _controller.cancelReplying),
          if (isEditing) _EditBar(onCancel: () {
            _controller.cancelEditing();
            _textController.clear();
          }),
          if (_pending.isNotEmpty) _PendingAttachmentsRow(pending: _pending, onRemove: (id) {
            setState(() => _pending.removeWhere((a) => a.id == id));
          }),
          if (_isRecording) _RecordingBar(duration: _recordDuration, onStop: _toggleVoiceRecording),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                tooltip: 'Görsel ekle',
              ),
              IconButton(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary),
                tooltip: 'Dosya ekle',
              ),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    style: AppTextStyles.body,
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: 'Bir mesaj yaz…',
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => showEmojiPickerSheet(
                  context,
                  onSelected: (emoji) {
                    _textController.text += emoji;
                    _onTextChanged(_textController.text);
                  },
                ),
                icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.textSecondary),
                tooltip: 'Emoji',
              ),
              IconButton(
                onPressed: _toggleVoiceRecording,
                icon: Icon(
                  _isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                  color: _isRecording ? AppColors.statusDnd : AppColors.textSecondary,
                ),
                tooltip: 'Sesli not',
              ),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: _send,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.name, required this.onCancel});

  final String name;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text('$name kullanıcısına yanıt veriliyor', style: AppTextStyles.caption)),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 18,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EditBar extends StatelessWidget {
  const _EditBar({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text('Mesaj düzenleniyor', style: AppTextStyles.caption)),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 18,
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.duration, required this.onStop});

  final Duration duration;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record_rounded, size: 14, color: AppColors.statusDnd),
          const SizedBox(width: 6),
          Text('Kaydediliyor · ${duration.inMinutes}:$seconds', style: AppTextStyles.caption),
          const Spacer(),
          TextButton(onPressed: onStop, child: const Text('Bitir')),
        ],
      ),
    );
  }
}

class _PendingAttachmentsRow extends StatelessWidget {
  const _PendingAttachmentsRow({required this.pending, required this.onRemove});

  final List<_PendingAttachment> pending;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: pending.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = pending[index];
            return Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    item.isImage
                        ? Icons.image_outlined
                        : item.isAudio
                            ? Icons.mic_none_rounded
                            : Icons.insert_drive_file_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.fileName,
                      style: AppTextStyles.small,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.uploading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  else
                    InkWell(
                      onTap: () => onRemove(item.id),
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
