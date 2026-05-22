import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProgressChart extends StatelessWidget {
  final List<double> dataPoints;
  final List<String> labels;
  final double height;

  const ProgressChart({
    super.key,
    required this.dataPoints,
    required this.labels,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ChartPainter(
              dataPoints: dataPoints,
              isDarkMode: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map(
                (label) => Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.0,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final bool isDarkMode;

  _ChartPainter({required this.dataPoints, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double widthBetweenPoints = size.width / (dataPoints.length - 1);
    final Path path = Path();
    final Path areaPath = Path();

    // Line Paint
    final Paint linePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Gradient Paint for Area
    final Paint areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.accent.withOpacity(0.3),
          AppColors.accent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    // Points
    final List<Offset> points = [];
    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * widthBetweenPoints;
      final double y = size.height * (1 - dataPoints[i]);
      points.add(Offset(x, y));
    }

    // Draw Smooth Line
    path.moveTo(points[0].dx, points[0].dy);
    areaPath.moveTo(points[0].dx, size.height);
    areaPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final double xControl = (points[i].dx + points[i + 1].dx) / 2;
      path.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        xControl,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      areaPath.quadraticBezierTo(
        points[i].dx,
        points[i].dy,
        xControl,
        (points[i].dy + points[i + 1].dy) / 2,
      );
    }

    path.lineTo(points.last.dx, points.last.dy);
    areaPath.lineTo(points.last.dx, points.last.dy);
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();

    // Draw Area
    canvas.drawPath(areaPath, areaPaint);

    // Draw Line
    canvas.drawPath(path, linePaint);

    // Draw Points
    final Paint pointPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;

    final Paint pointOutlinePaint = Paint()
      ..color = isDarkMode ? const Color(0xFF020617) : AppColors.neuBase
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 6, pointOutlinePaint);
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
