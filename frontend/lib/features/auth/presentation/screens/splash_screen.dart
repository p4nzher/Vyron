import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Salt sunum amaçlı: oturum doğrulaması artık `AuthController` tarafından
/// uygulama açılışında otomatik başlatılır (bkz.
/// `presentation/controllers/auth_controller.dart`); sonucuna göre
/// yönlendirme `routerProvider`'ın `redirect` mantığında yapılır. Bu ekranın
/// tek işi, o doğrulama sürerken marka logosunu göstermektir.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 44),
            ).animate().scale(
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                ).fadeIn(duration: 400.ms),
            const SizedBox(height: 20),
            Text('Vyron', style: AppTextStyles.heading(size: 28))
                .animate()
                .fadeIn(delay: 150.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
