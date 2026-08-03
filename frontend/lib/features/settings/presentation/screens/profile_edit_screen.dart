import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../auth/data/user_repository.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../storage/data/storage_repository.dart';

const _statusOptions = <String, String>{
  'ONLINE': 'Çevrimiçi',
  'IDLE': 'Boşta',
  'DND': 'Rahatsız Etmeyin',
  'INVISIBLE': 'Görünmez',
};

/// Faz 6.2 — profil düzenleme: görünen ad, bio, avatar (presigned S3/R2
/// yüklemesiyle) ve çevrimiçi durumu günceller. Kaydedildikten sonra
/// `AuthController.updateUser` ile global oturum önbelleği tazelenir —
/// böylece uygulamanın başka hiçbir yeri tekrar `GET /users/me` yapmak
/// zorunda kalmaz.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final UserRepository _userRepository = UserRepository(sl<ApiClient>());
  late final StorageRepository _storageRepository = StorageRepository(sl<ApiClient>());
  final _picker = ImagePicker();

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  String? _pendingAvatarUrl;
  Uint8List? _pendingAvatarBytes;
  late String _selectedStatus;

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _errorText;

  AppUser get _user => ref.read(authControllerProvider).user!;

  @override
  void initState() {
    super.initState();
    final user = _user;
    _displayNameController = TextEditingController(text: user.displayName ?? '');
    _bioController = TextEditingController(text: user.bio ?? '');
    _selectedStatus = user.status;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked == null) return;

    setState(() {
      _isUploadingAvatar = true;
      _errorText = null;
    });
    try {
      final bytes = await picked.readAsBytes();
      final publicUrl = await _storageRepository.uploadFile(
        fileName: picked.name,
        mimeType: picked.mimeType ?? 'image/jpeg',
        bytes: bytes,
        context: UploadContext.avatar,
      );
      if (!mounted) return;
      setState(() {
        _pendingAvatarBytes = bytes;
        _pendingAvatarUrl = publicUrl;
      });
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      final displayName = _displayNameController.text.trim();
      final bio = _bioController.text.trim();

      await _userRepository.updateProfile(
        displayName: displayName,
        bio: bio,
        avatarUrl: _pendingAvatarUrl,
      );
      if (_selectedStatus != _user.status) {
        await _userRepository.updateStatus(_selectedStatus);
      }

      ref.read(authControllerProvider.notifier).updateUser(
            _user.copyWith(
              displayName: displayName,
              bio: bio,
              avatarUrl: _pendingAvatarUrl,
              status: _selectedStatus,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      // Oturum beklenmedik şekilde kapandıysa (ör. refresh token iptal oldu)
      // router zaten /login'e yönlendirecektir; burada sadece çökmeyi önleriz.
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Profili Düzenle', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _isUploadingAvatar ? null : _pickAvatar,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _AvatarPreview(
                            bytes: _pendingAvatarBytes,
                            avatarUrl: _pendingAvatarUrl ?? user.avatarUrl,
                            initials: user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                          ),
                          if (_isUploadingAvatar)
                            const CircularProgressIndicator(strokeWidth: 2)
                          else
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: Text(user.tag, style: AppTextStyles.caption)),
                  const SizedBox(height: 28),
                  AppTextField(
                    label: 'GÖRÜNEN AD',
                    controller: _displayNameController,
                    hint: user.username,
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'HAKKIMDA',
                    controller: _bioController,
                    hint: 'Kendinden kısaca bahset...',
                    maxLines: 3,
                    maxLength: 190,
                  ),
                  const SizedBox(height: 16),
                  Text('DURUM', style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  GlassContainer(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: _statusOptions.entries.map((entry) {
                        final isSelected = _selectedStatus == entry.key;
                        return RadioListTile<String>(
                          value: entry.key,
                          groupValue: _selectedStatus,
                          onChanged: (value) => setState(() => _selectedStatus = value!),
                          activeColor: AppColors.brandGradientStart,
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.forPresence(entry.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                entry.value,
                                style: isSelected ? AppTextStyles.bodyMedium : AppTextStyles.body,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorText!, style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(
                    label: 'Kaydet',
                    isLoading: _isSaving,
                    onPressed: _isUploadingAvatar ? null : _save,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.bytes, required this.avatarUrl, required this.initials});

  final Uint8List? bytes;
  final String? avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    if (bytes != null) {
      return CircleAvatar(radius: size / 2, backgroundImage: MemoryImage(bytes!));
    }
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(radius: size / 2, backgroundImage: NetworkImage(avatarUrl!));
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.backgroundElevated,
      child: Text(initials, style: AppTextStyles.heading(size: 32)),
    );
  }
}
