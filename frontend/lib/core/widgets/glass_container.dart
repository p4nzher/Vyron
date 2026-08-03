import 'dart:ui';
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// `docs/brand.md` "Glassmorphism Kuralları" bölümünün doğrudan uygulaması:
/// blur 20–24px, %6–10 beyaz overlay, 1px yarı saydam kenarlık, yumuşak
/// mor-tonlu gölge. Uygulama genelindeki tüm "cam kart" görünümleri
/// (mesaj paneli, modal, ayarlar kartı vb.) bu widget üzerine kurulmalıdır.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.blurSigma = 22,
    this.withShadow = true,
    this.width,
    this.height,
    super.key,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final bool withShadow;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      width: width,
      height: height,
      decoration: withShadow
          ? BoxDecoration(
              borderRadius: radius,
              boxShadow: const [
                BoxShadow(
                  color: AppColors.glassShadow,
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: Offset(0, 12),
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundElevated.withOpacity(0.72),
              borderRadius: radius,
              border: Border.all(color: AppColors.glassBorder, width: 1),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.glassOverlay,
                  Colors.white.withOpacity(0.02),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
