import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.neuBase,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.neuBase,
        error: AppColors.error,
      ),
      // Playfair Display for headings, Inter for body
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.playfairDisplay(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(
            color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(
            color: AppColors.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge:
            GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 16),
        bodyMedium:
            GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
        bodySmall: GoogleFonts.inter(
            color: AppColors.textSecondary, fontSize: 12),
        labelLarge: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.neuBase,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.primary),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.playfairDisplay(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      // Buttons rely on NeuButton widget; these are fallbacks
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.neuBase,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      dividerColor: AppColors.neuDark.withOpacity(0.5),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
    );
  }
}
