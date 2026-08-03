import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

enum _Step { loading, scanQr, backupCodes, error }

/// Faz 6.2 — Authenticator uygulamasıyla 2FA kurulumu:
/// 1) `generate2fa()` ile secret/QR üretilir,
/// 2) kullanıcı 6 haneli kodu girip `enable2fa()` ile doğrular,
/// 3) tek seferlik gösterilen yedek kodlar sunulur.
class TwoFactorSetupScreen extends ConsumerStatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  ConsumerState<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends ConsumerState<TwoFactorSetupScreen> {
  late final AuthRepository _authRepository = AuthRepository(sl<ApiClient>());
  final _codeController = TextEditingController();

  _Step _step = _Step.loading;
  TwoFactorSecret? _secret;
  List<String> _backupCodes = const [];
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadSecret();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadSecret() async {
    setState(() {
      _step = _Step.loading;
      _errorText = null;
    });
    try {
      final secret = await _authRepository.generate2fa();
      if (!mounted) return;
      setState(() {
        _secret = secret;
        _step = _Step.scanQr;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
        _step = _Step.error;
      });
    }
  }

  Future<void> _confirmCode() async {
    if (_codeController.text.trim().length != 6) {
      setState(() => _errorText = 'Lütfen 6 haneli kodu tam gir.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      final codes = await _authRepository.enable2fa(_codeController.text.trim());
      final user = ref.read(authControllerProvider).user;
      if (user != null) {
        ref.read(authControllerProvider.notifier).updateUser(user.copyWith(twoFactorEnabled: true));
      }
      if (!mounted) return;
      setState(() {
        _backupCodes = codes;
        _step = _Step.backupCodes;
      });
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('İki Faktörlü Doğrulama', style: AppTextStyles.title),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (_step) {
                _Step.loading => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                _Step.error => _ErrorView(message: _errorText ?? 'Bir hata oluştu.', onRetry: _loadSecret),
                _Step.scanQr => _buildScanQr(),
                _Step.backupCodes => _buildBackupCodes(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanQr() {
    final secret = _secret!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Google Authenticator, Authy gibi bir uygulamayla aşağıdaki kodu tara.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 20),
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: QrImageView(
              data: secret.otpAuthUrl,
              size: 200,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('QR taranamıyorsa kodu elle gir:', style: AppTextStyles.caption),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: secret.secret));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Secret kopyalandı.')),
            );
          },
          child: Row(
            children: [
              Expanded(child: SelectableText(secret.secret, style: AppTextStyles.mono())),
              const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
            ],
          ),
        ),
        const SizedBox(height: 28),
        AppTextField(
          label: 'DOĞRULAMA KODU',
          controller: _codeController,
          hint: '123456',
          keyboardType: TextInputType.number,
          maxLength: 6,
          prefixIcon: Icons.security_rounded,
          onSubmitted: (_) => _confirmCode(),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!, style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
        ],
        const SizedBox(height: 16),
        GradientButton(label: 'Etkinleştir', isLoading: _isSubmitting, onPressed: _confirmCode),
      ],
    );
  }

  Widget _buildBackupCodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_user_rounded, color: AppColors.statusOnline, size: 40),
        const SizedBox(height: 12),
        Text('2FA etkinleştirildi 🎉', style: AppTextStyles.heading(size: 22)),
        const SizedBox(height: 8),
        Text(
          'Aşağıdaki yedek kodları güvenli bir yere kaydet. Authenticator '
          'uygulamana erişemediğinde bu kodlardan birini kullanabilirsin. '
          'Bu kodlar SADECE bu ekranda gösterilir.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 20),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _backupCodes
                .map((code) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SelectableText(code, style: AppTextStyles.mono(size: 15)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: 'Tamamla',
          icon: Icons.check_rounded,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: AppTextStyles.body.copyWith(color: AppColors.statusDnd)),
        const SizedBox(height: 16),
        GradientButton(label: 'Tekrar dene', onPressed: onRetry),
      ],
    );
  }
}
