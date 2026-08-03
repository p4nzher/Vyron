import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Discord'daki gibi avatarın sağ-alt köşesine yerleşen durum noktası.
/// `status`: 'ONLINE' | 'IDLE' | 'DND' | 'OFFLINE' (bkz. Prisma `UserStatus`).
class StatusDot extends StatelessWidget {
  const StatusDot({required this.status, this.size = 14, this.borderColor, super.key});

  final String status;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.forPresence(status),
        shape: BoxShape.circle,
        border: Border.all(color: borderColor ?? AppColors.backgroundPrimary, width: 2.5),
      ),
    );
  }
}

/// Gradyan çerçeveli avatar — çevrimiçi/konuşuyor durumunda kullanılır
/// (bkz. `docs/brand.md` — "avatar çerçevesi, çevrimiçi durumda").
class GradientAvatarRing extends StatelessWidget {
  const GradientAvatarRing({required this.child, this.size = 48, this.isActive = false, super.key});

  final Widget child;
  final double size;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      padding: EdgeInsets.all(isActive ? 2.5 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isActive ? AppColors.brandGradient : null,
      ),
      child: ClipOval(
        child: Container(
          color: AppColors.backgroundElevated,
          child: child,
        ),
      ),
    );
  }
}
