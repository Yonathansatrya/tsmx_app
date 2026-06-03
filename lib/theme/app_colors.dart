import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF135E39);
  static const Color primaryDark = Color(0xFF0F2618);
  static const Color primaryLight = Color(0xFF2E7D57);
  static const Color softGreen = Color(0xFFE8F3E6);
  static const Color accentYellow = Color(0xFFFDE047);
  static const Color tertiary = Color(0xFF8AC33E);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color slate = Color(0xFF64748B);
  static const Color navy = Color(0xFF1F2937);
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF16A34A);
  static const Color white = Colors.white;

  static List<BoxShadow> get cardShadow {
    return [
      BoxShadow(
        color: primaryDark.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }
}
