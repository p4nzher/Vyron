import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// `docs/brand.md`: Başlıklar için Manrope, gövde metni için Inter,
/// kod/ID'ler için JetBrains Mono.
abstract final class AppTextStyles {
  static TextStyle _base(double size, FontWeight weight, {Color? color, double? height}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      height: height,
    );
  }

  static TextStyle heading({double size = 24, Color? color}) => GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColors.textPrimary,
        letterSpacing: -0.2,
      );

  static TextStyle title = _base(18, FontWeight.w600);
  static TextStyle body = _base(15, FontWeight.w400, height: 1.4);
  static TextStyle bodyMedium = _base(15, FontWeight.w500);
  static TextStyle caption = _base(13, FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle small = _base(12, FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle button = _base(15, FontWeight.w600, color: Colors.white);

  static TextStyle mono({double size = 13, Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
      );
}
