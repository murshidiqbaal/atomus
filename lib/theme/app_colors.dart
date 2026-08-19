import 'package:flutter/material.dart';

class AppColors {
  // ─── Neumorphic Base (Light Mode - Atom Crystal Ice) ──────────────────────
  static const Color neuBase = Color(0xFFEEF5FC);
  static const Color neuLight = Color(0xFFFFFFFF); // highlight
  static const Color neuDark = Color(0xFFCFDCED); // soft shadow

  // ─── Neumorphic Base (Dark Mode - Quantum Cosmic Space) ────────────────────
  static const Color neuBaseDark = Color(0xFF0A1224); // Quantum Cosmic Deep Space
  static const Color neuLightDark = Color(0xFF14223D); // Highlight tint
  static const Color neuDarkDark = Color(0xFF040814); // Deep space shadow

  // ─── Glassmorphism (Dark Mode - Cyan & Gold Tinted) ─────────────────────────
  static const Color glassBase = Color(0x1A0072FF); // Translucent Quantum Cyan-Blue
  static const Color glassBorder = Color(0x3300C3FF); // Glowing Atom Cyan border
  static const Color glassHighlight = Color(0x4D00C3FF); // Shimmer highlight

  // ─── Brand (Atom Logo Palette) ──────────────────────────────────────────────
  static const Color primary = Color(0xFF0072FF); // Electric Atom Blue
  static const Color primaryCyan = Color(0xFF00C3FF); // Atom Nucleus Cyan Core
  static const Color primaryDark = Color(0xFFE2E8F0); // Light text on dark bg
  static const Color accent = Color(0xFFFFB800); // Orbit Metallic Gold
  static const Color accentLight = Color(0xFFFEF3C7); // Amber gold tint
  static const Color accentGlow = Color(0xFFFBBF24); // Bright gold glow

  // ─── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A); // Deep Slate 900
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textOnDark = Color(0xFFF8FAFC);

  // ─── Status ─────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981); // Emerald (Present)
  static const Color warning = Color(0xFFFFB800); // Orbit Amber Gold (Late/Leave)
  static const Color error = Color(0xFFF43F5E); // Rose (Absent)
  static const Color info = Color(0xFF00C3FF); // Atom Cyan Info

  // ─── Neumorphic BoxShadow helpers ────────────────────────────────────────────
  static List<BoxShadow> neuRaisedShadow({
    required bool isDarkMode,
    double blur = 18,
    double spread = 0,
    Offset offset = const Offset(6, 6),
  }) {
    if (isDarkMode) {
      return []; // Glassmorphism doesn't use standard neumorphic shadows
    }

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
