import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _twoFactorController = TextEditingController();

  bool _isLoading = false;
  bool _needsTwoFactor = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _twoFactorController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorText = 'E-posta ve şifre zorunludur.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      // Başarılı olursa `AuthController` durumu `authenticated`'e geçirir;
      // yönlendirme manuel `context.go` ile değil, `routerProvider`'ın
      // `redirect` mantığı üzerinden otomatik gerçekleşir.
      await ref.read(authControllerProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            twoFactorCode: _needsTwoFactor ? _twoFactorController.text.trim() : null,
          );
    } on ApiException catch (e) {
      if (e.isTwoFactorRequired) {
        setState(() => _needsTwoFactor = true);
      } else {
        setState(() => _errorText = e.message);
      }
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
                  Text('Tekrar hoş geldin', style: AppTextStyles.heading(size: 28)),
                  const SizedBox(height: 8),
                  Text('Devam etmek için giriş yap.', style: AppTextStyles.caption),
                  const SizedBox(height: 32),
                  if (!_needsTwoFactor) ...[
                    AppTextField(
                      label: 'E-POSTA',
                      controller: _emailController,
                      hint: 'ornek@eposta.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'ŞİFRE',
                      controller: _passwordController,
                      hint: '••••••••',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      onSubmitted: (_) => _submit(),
                    ),
                  ] else ...[
                    Text(
                      'Hesabında iki faktörlü doğrulama açık. Uygulamandaki 6 haneli kodu gir.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'DOĞRULAMA KODU',
                      controller: _twoFactorController,
                      hint: '123456',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.security_rounded,
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorText!, style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => context.push(AppRoutes.forgotPassword),
                      child: const Text('Şifremi unuttum'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GradientButton(
                    label: _needsTwoFactor ? 'Doğrula' : 'Giriş Yap',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Hesabın yok mu?', style: AppTextStyles.caption),
                      TextButton(
                        onPressed: _isLoading ? null : () => context.push(AppRoutes.register),
                        child: const Text('Kayıt ol'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
