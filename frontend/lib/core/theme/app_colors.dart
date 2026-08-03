import 'package:flutter/material.dart';

/// `docs/brand.md` içindeki tasarım token'larının Flutter karşılığı.
/// Bu dosya SADECE renk sabitlerini içerir; bileşik `ThemeData` için
/// [app_theme.dart] dosyasına bakın.
abstract final class AppColors {
  // --- Zeminler ---
  static const Color backgroundPrimary = Color(0xFF0A0A14);
  static const Color backgroundSecondary = Color(0xFF12121F);
  static const Color backgroundElevated = Color(0xFF1A1A2C);

  // --- Marka gradyanı (mor → indigo) ---
  static const Color brandGradientStart = Color(0xFF9F7AEA);
  static const Color brandGradientEnd = Color(0xFF4C5FD5);
  static const Color brandAccent = Color(0xFFE9E4FF);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandGradientStart, brandGradientEnd],
  );

  // --- Metin ---
  static const Color textPrimary = Color(0xFFF5F5FA);
  static const Color textSecondary = Color(0xFF9B9BB0);

  // --- Durum göstergeleri ---
  static const Color statusOnline = Color(0xFF4ADE80);
  static const Color statusIdle = Color(0xFFFBBF24);
  static const Color statusDnd = Color(0xFFF87171);
  static const Color statusOffline = Color(0xFF5B5B6E);

  // --- Glassmorphism ---
  static const Color glassBorder = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const Color glassOverlay = Color(0x12FFFFFF); // ~%7 beyaz overlay
  static const Color glassShadow = Color(0x264F46E5); // rgba(79,70,229,0.15)

  // --- Yardımcı: durum -> renk eşlemesi ---
  static Color forPresence(String status) {
    switch (status) {
      case 'ONLINE':
        return statusOnline;
      case 'IDLE':
      case 'BUSY':
        return statusIdle;
      case 'DND':
        return statusDnd;
      default:
        return statusOffline;
    }
  }
}
