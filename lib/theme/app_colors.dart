import 'package:flutter/material.dart';

class AppColors {
  // ─── Neumorphic Base (Light) ────────────────────────────────────────────────
  static const Color neuBase     = Color(0xFFE8E3DC);
  static const Color neuLight    = Color(0xFFFFFFFF); // highlight
  static const Color neuDark     = Color(0xFFC4BFB8); // shadow

  // ─── Neumorphic Base (Dark) ─────────────────────────────────────────────────
  static const Color neuBaseDark  = Color(0xFF0F172A); // Deeper Slate 900
  static const Color neuLightDark = Color(0xFF1E293B); // Slate 800 (highlight)
  static const Color neuDarkDark  = Color(0xFF020617); // Slate 950 (shadow)

  // ─── Glassmorphism (Dark Mode) ──────────────────────────────────────────────
  static const Color glassBase      = Color(0x1AFFFFFF); // Very translucent white
  static const Color glassBorder    = Color(0x33FFFFFF); // Subtle white border
  static const Color glassHighlight = Color(0x4DFFFFFF); // For shimmer/reflection

  // ─── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF1A2B4A); // deep navy
  static const Color primaryDark  = Color(0xFFCBD5E1); // slate 300 for text
  static const Color accent      = Color(0xFFC9A84C); // warm gold
  static const Color accentLight = Color(0xFFEDD98A); // pale gold tint

  // ─── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A2B4A);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF8A8480);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textOnDark    = Color(0xFFF5F2EE);

  // ─── Status ──────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF3DAA6E);
  static const Color warning = Color(0xFFE5A624);
  static const Color error   = Color(0xFFD95F5F);
  static const Color info    = Color(0xFF4A7FBA);

  // ─── Neumorphic BoxShadow helpers ────────────────────────────────────────────
  static List<BoxShadow> neuRaisedShadow({
    required bool isDarkMode,
    double blur = 18,
    double spread = 0,
    Offset offset = const Offset(6, 6),
  }) {
    if (isDarkMode) return []; // Glassmorphism doesn't use standard neumorphic shadows

    return [
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
  }

  static List<BoxShadow> neuPressedShadow({
    required bool isDarkMode,
    double blur = 8,
    double spread = 0,
    Offset offset = const Offset(4, 4),
  }) {
    if (isDarkMode) return [];

    return [
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
  }
}
