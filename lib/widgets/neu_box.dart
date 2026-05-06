import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A neumorphic container — the single building block for the luxury UI.
/// Set [isPressed] to true for the inset (concave) look.
/// Set [isFlat] to true for a zero-shadow version (e.g. inside pressed states).
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
    final bg = color ?? AppColors.neuBase;

    List<BoxShadow> shadows;
    if (isFlat) {
      shadows = [];
    } else if (isPressed) {
      shadows = AppColors.neuPressedShadow();
    } else {
      shadows = customShadows ?? AppColors.neuRaisedShadow();
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

    return GestureDetector(
      onTap: onTap,
      child: container,
    );
  }
}

/// Inset / pressed variation — looks like a pocket in the surface.
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neuBase,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: AppColors.neuPressedShadow(),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Gold accent separator / divider line.
class NeuDivider extends StatelessWidget {
  const NeuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.accent,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
