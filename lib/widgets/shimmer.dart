import 'package:flutter/material.dart';

class Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const Shimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();

  // ─── Preset Skeletons ──────────────────────────────────────────────────────

  /// Renders a skeleton card mimicking the dashboard cards or detailed list tiles.
  static Widget cardSkeleton({double height = 120, double borderRadius = 20}) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Shimmer(width: 40, height: 40, borderRadius: borderRadius - 8),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Shimmer(width: 120, height: 14),
                        const SizedBox(height: 8),
                        Shimmer(width: 80, height: 10, borderRadius: borderRadius - 14),
                      ],
                    ),
                  ),
                  const Shimmer(width: 50, height: 24, borderRadius: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Renders a skeleton that mimics a chart block.
  static Widget chartSkeleton({double height = 200, double borderRadius = 20}) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Shimmer(width: 140, height: 18),
                  Shimmer(width: 100, height: 32, borderRadius: borderRadius - 8),
                ],
              ),
              const SizedBox(height: 24),
              Shimmer(width: double.infinity, height: height - 100, borderRadius: borderRadius - 10),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (_) => const Shimmer(width: 40, height: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Renders a statistical summary header skeleton.
  static Widget statsHeaderSkeleton({double borderRadius = 20}) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.01),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Shimmer(width: 150, height: 11),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: const [
                  Shimmer(width: 90, height: 36),
                  SizedBox(width: 6),
                  Shimmer(width: 20, height: 20),
                  Spacer(),
                  Shimmer(width: 110, height: 28, borderRadius: 14),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  3,
                  (_) => Column(
                    children: const [
                      Shimmer(width: 60, height: 9),
                      SizedBox(height: 6),
                      Shimmer(width: 40, height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1, milliseconds: 500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    final highlightColor = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.09);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.3, 0.5, 0.7],
              transform: _SlidingGradientTransform(slidePercent: _controller.value),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent - 0.5) * 2, 0, 0);
  }
}
