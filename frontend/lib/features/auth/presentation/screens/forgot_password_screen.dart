import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../data/auth_repository.dart';

/// Faz 6.2 — şifre sıfırlama akışının ilk adımı: kullanıcı e-postasını girer,
/// backend (kayıtlıysa) bir sıfırlama token'ı e-postayla gönderir. Kullanıcı
/// var/yok bilgisi sızdırılmadığı için UI her zaman aynı başarı mesajını
/// gösterir (bkz. `AuthService.forgotPassword`).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final AuthRepository _authRepository = AuthRepository(sl<ApiClient>());
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _isSent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorText = 'E-posta zorunludur.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authRepository.forgotPassword(_emailController.text.trim());
      if (mounted) setState(() => _isSent = true);
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
                  ),
                  Text('Şifreni mi unuttun?', style: AppTextStyles.heading(size: 26)),
                  const SizedBox(height: 8),
                  Text(
                    _isSent
                        ? 'Eğer bu e-posta kayıtlıysa, sıfırlama bağlantısı gönderildi. Gelen '
                            'kutunu kontrol et ve koddan devam et.'
                        : 'Hesabına kayıtlı e-postayı gir, sana bir sıfırlama bağlantısı gönderelim.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 32),
                  if (!_isSent) ...[
                    AppTextField(
                      label: 'E-POSTA',
                      controller: _emailController,
                      hint: 'ornek@eposta.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorText!, style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
                    ],
                    const SizedBox(height: 24),
                    GradientButton(label: 'Bağlantı Gönder', isLoading: _isLoading, onPressed: _submit),
                  ] else ...[
                    GradientButton(
                      label: 'Kodum var, devam et',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => context.push(AppRoutes.resetPassword),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
