import 'package:flutter/material.dart';

class AppColors {
  // ─── Neumorphic Base ────────────────────────────────────────────────────────
  /// The main surface/background colour — warm off-white.
  static const Color neuBase     = Color(0xFFE8E3DC);
  static const Color neuLight    = Color(0xFFFFFFFF); // highlight (top-left)
  static const Color neuDark     = Color(0xFFC4BFB8); // shadow  (bottom-right)

  // ─── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF1A2B4A); // deep navy
  static const Color accent      = Color(0xFFC9A84C); // warm gold
  static const Color accentLight = Color(0xFFEDD98A); // pale gold tint

  // ─── Legacy aliases (keep widgets that still ref these compiling) ────────────
  static const Color background     = neuBase;
  static const Color cardBackground = neuBase;

  // ─── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A2B4A);
  static const Color textSecondary = Color(0xFF8A8480);
  static const Color textOnDark    = Color(0xFFF5F2EE);

  // ─── Status ──────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF3DAA6E);
  static const Color warning = Color(0xFFE5A624);
  static const Color error   = Color(0xFFD95F5F);
  static const Color info    = Color(0xFF4A7FBA);

  // ─── Neumorphic BoxShadow helpers ────────────────────────────────────────────
  /// Standard raised shadow (emboss).
  static List<BoxShadow> neuRaisedShadow({
    double blur = 18,
    double spread = 0,
    Offset offset = const Offset(6, 6),
  }) =>
      [
        BoxShadow(
          color: neuLight,
          blurRadius: blur,
          spreadRadius: spread,
          offset: -offset,
        ),
        BoxShadow(
          color: neuDark,
          blurRadius: blur,
          spreadRadius: spread,
          offset: offset,
        ),
      ];

  /// Pressed / inset shadow.
  static List<BoxShadow> neuPressedShadow({
    double blur = 8,
    double spread = 0,
    Offset offset = const Offset(4, 4),
  }) =>
      [
        BoxShadow(
          color: neuDark,
          blurRadius: blur,
          spreadRadius: spread,
          offset: -offset,
        ),
        BoxShadow(
          color: neuLight,
          blurRadius: blur,
          spreadRadius: spread,
          offset: offset,
        ),
      ];

  /// Subtle raised shadow — for smaller elements.
  static List<BoxShadow> neuSubtleShadow() => neuRaisedShadow(
        blur: 10,
        offset: const Offset(4, 4),
      );
}
