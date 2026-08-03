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

/// Faz 6.2 — şifre sıfırlamanın ikinci adımı. `prefilledToken`, ileride
/// gerçek deep-link desteği eklendiğinde `/reset-password?token=...`
/// bağlantısından otomatik doldurulur; şimdilik kullanıcı e-postadaki kodu
/// elle de yapıştırabilir.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({this.prefilledToken, super.key});

  final String? prefilledToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final AuthRepository _authRepository = AuthRepository(sl<ApiClient>());
  late final _tokenController = TextEditingController(text: widget.prefilledToken ?? '');
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _isDone = false;
  String? _errorText;

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tokenController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorText = 'Kod ve yeni şifre zorunludur.');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _errorText = 'Şifreler eşleşmiyor.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authRepository.resetPassword(
        token: _tokenController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (mounted) setState(() => _isDone = true);
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
                  Text('Yeni şifre belirle', style: AppTextStyles.heading(size: 26)),
                  const SizedBox(height: 8),
                  Text(
                    _isDone
                        ? 'Şifren güncellendi. Tüm cihazlardaki eski oturumların sonlandırıldı — '
                            'yeni şifrenle tekrar giriş yapabilirsin.'
                        : 'E-postana gelen sıfırlama kodunu ve yeni şifreni gir.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: 32),
                  if (!_isDone) ...[
                    AppTextField(
                      label: 'SIFIRLAMA KODU',
                      controller: _tokenController,
                      hint: 'E-postadaki kodu yapıştır',
                      prefixIcon: Icons.vpn_key_outlined,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'YENİ ŞİFRE',
                      controller: _passwordController,
                      hint: 'En az 8 karakter, büyük/küçük harf + rakam',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'YENİ ŞİFRE (TEKRAR)',
                      controller: _confirmController,
                      hint: '••••••••',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorText!, style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
                    ],
                    const SizedBox(height: 24),
                    GradientButton(label: 'Şifreyi Güncelle', isLoading: _isLoading, onPressed: _submit),
                  ] else ...[
                    GradientButton(
                      label: 'Giriş ekranına dön',
                      icon: Icons.login_rounded,
                      onPressed: () => context.go(AppRoutes.login),
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
