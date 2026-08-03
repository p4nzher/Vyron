import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      // Başarılı olursa `AuthController` durumu `authenticated`'e geçirir;
      // yönlendirme `routerProvider`'ın `redirect` mantığı üzerinden otomatik
      // gerçekleşir (bkz. `login_screen.dart` ile aynı desen).
      await ref.read(authControllerProvider.notifier).register(
            email: _emailController.text.trim(),
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
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
                  Text('Hesap oluştur', style: AppTextStyles.heading(size: 28)),
                  const SizedBox(height: 8),
                  Text('Topluluğuna katılmak için bir hesap aç.', style: AppTextStyles.caption),
                  const SizedBox(height: 32),
                  AppTextField(
                    label: 'KULLANICI ADI',
                    controller: _usernameController,
                    hint: '3-32 karakter, harf/rakam/._',
                    prefixIcon: Icons.alternate_email_rounded,
                  ),
                  const SizedBox(height: 16),
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
                    hint: 'En az 8 karakter, büyük/küçük harf + rakam',
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorText!, style: AppTextStyles.small.copyWith(color: AppColors.statusDnd)),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(label: 'Kayıt Ol', isLoading: _isLoading, onPressed: _submit),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Zaten hesabın var mı?', style: AppTextStyles.caption),
                      TextButton(
                        onPressed: _isLoading ? null : () => context.pop(),
                        child: const Text('Giriş yap'),
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
