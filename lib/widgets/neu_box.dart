import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_colors.dart';

/// A hybrid container that provides Neumorphism (Light Mode) 
/// and Glassmorphism (Dark Mode).
class NeuBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isPressed;
  final bool isFlat;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Color? color;
  final List<BoxShadow>? customShadows;

  const NeuBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 20,
    this.isPressed = false,
    this.isFlat = false,
    this.onTap,
    this.width,
    this.height,
    this.color,
    this.customShadows,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isDarkMode) {
      return _buildGlassBox(context);
    }

    // Neumorphic Light Mode
    final bg = color ?? AppColors.neuBase;
    List<BoxShadow> shadows;
    if (isFlat) {
      shadows = [];
    } else if (isPressed) {
      shadows = AppColors.neuPressedShadow(isDarkMode: false);
    } else {
      shadows = customShadows ?? AppColors.neuRaisedShadow(isDarkMode: false);
    }

    final container = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: shadows,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return container;
    return GestureDetector(onTap: onTap, child: container);
  }

  Widget _buildGlassBox(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: AppColors.glassBase,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.glassHighlight.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Inset / pressed variation — glassmorphic pocket in dark mode.
class NeuInset extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const NeuInset({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (isDarkMode) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: AppColors.glassBorder.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.neuBase,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppColors.neuPressedShadow(isDarkMode: false),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class NeuDivider extends StatelessWidget {
  const NeuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            isDarkMode ? AppColors.accent.withOpacity(0.5) : AppColors.accent,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
