import 'package:flutter/animation.dart';

/// `docs/brand.md`: Geçişler 200–280ms, `easeOutCubic`; sayfa geçişlerinde
/// hafif scale (0.96→1.0) + fade tercih edilir.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 280);

  static const Curve curve = Curves.easeOutCubic;

  static const double pageScaleFrom = 0.96;
  static const double pageScaleTo = 1.0;
}
