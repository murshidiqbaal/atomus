import 'package:flutter/material.dart';

class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (!isDarkMode) return child;

    return Stack(
      children: [
        // Background Glows for Glassmorphism
        Positioned(
          top: -100,
          right: -50,
          child: _GlowBlob(
            color: const Color(0xFF1A2B4A).withOpacity(0.5), // Deep Navy
            size: 300,
          ),
        ),
        Positioned(
          bottom: 100,
          left: -100,
          child: _GlowBlob(
            color: const Color(0xFFC9A84C).withOpacity(0.15), // Gold Glow
            size: 400,
          ),
        ),
        Positioned(
          top: 300,
          left: 150,
          child: _GlowBlob(color: Colors.blue.withOpacity(0.05), size: 200),
        ),
        // The actual content
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size / 2, spreadRadius: size / 4),
        ],
      ),
    );
  }
}
