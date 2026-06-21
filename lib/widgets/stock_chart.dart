import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_colors.dart';
import 'neu_box.dart';

class StockChart extends StatefulWidget {
  final List<double> dataPoints; // Values as percentages (0.0 to 100.0)
  final List<String> labels; // Date labels for the x-axis
  final List<String> examNames; // Exam names for the tooltip
  final double height;

  const StockChart({
    super.key,
    required this.dataPoints,
    required this.labels,
    required this.examNames,
    this.height = 220,
  });

  @override
  State<StockChart> createState() => _StockChartState();
}

class _StockChartState extends State<StockChart> {
  int? _selectedIndex;
  Offset? _touchPosition;

  @override
  Widget build(BuildContext context) {
    final hasData = widget.dataPoints.isNotEmpty;
    if (!hasData) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'No data available',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    // Determine trend color
    // Green (success) if last >= first, else Red (error)
    final double first = widget.dataPoints.first;
    final double last = widget.dataPoints.last;
    final isUpTrend = last >= first;
    final trendColor = isUpTrend ? AppColors.success : AppColors.error;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        final double widthBetweenPoints = widget.dataPoints.length > 1
            ? chartWidth / (widget.dataPoints.length - 1)
            : chartWidth;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Dotted Background Grid & Line Chart
            GestureDetector(
              onPanStart: (details) => _updateSelectedIndex(details.localPosition, widthBetweenPoints),
              onPanUpdate: (details) => _updateSelectedIndex(details.localPosition, widthBetweenPoints),
              onPanEnd: (_) => _clearSelectedIndex(),
              onPanCancel: () => _clearSelectedIndex(),
              onTapDown: (details) => _updateSelectedIndex(details.localPosition, widthBetweenPoints),
              onTapUp: (_) => _clearSelectedIndex(),
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _StockChartPainter(
                    dataPoints: widget.dataPoints,
                    trendColor: trendColor,
                    selectedIndex: _selectedIndex,
                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ),

            // Tooltip UI
            if (_selectedIndex != null && _selectedIndex! < widget.dataPoints.length) ...[
              Positioned(
                left: (_selectedIndex! * widthBetweenPoints - 75).clamp(
                  0.0,
                  chartWidth - 150,
                ),
                top: _calculateTooltipY(_selectedIndex!, widget.height) - 75,
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xE01E293B) // Dark Slate
                        : const Color(0xF0FFFFFF), // Light White
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: trendColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.examNames[_selectedIndex!],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.labels[_selectedIndex!],
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.dataPoints[_selectedIndex!].toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: trendColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // X-Axis Labels (dates) at the bottom
            Positioned(
              bottom: -24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _buildXAxisLabels(),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateSelectedIndex(Offset localPosition, double widthBetweenPoints) {
    setState(() {
      _touchPosition = localPosition;
      int idx = (localPosition.dx / widthBetweenPoints).round();
      _selectedIndex = idx.clamp(0, widget.dataPoints.length - 1);
    });
  }

  void _clearSelectedIndex() {
    // Keep showing the tooltip for 1 second or clear instantly?
    // Let's clear after a brief delay so users can read it comfortably, or instantly on lift.
    // Trading apps clear instantly, let's follow that but with a tiny delay to prevent flickering.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _selectedIndex = null;
          _touchPosition = null;
        });
      }
    });
  }

  double _calculateTooltipY(int index, double chartHeight) {
    final value = widget.dataPoints[index] / 100.0;
    // Map value (0 to 1) to y coordinates: 1 means y=20 (top padding), 0 means y=chartHeight-20 (bottom padding)
    final double usableHeight = chartHeight - 40;
    final double y = chartHeight - 20 - (value * usableHeight);
    return y;
  }

  List<Widget> _buildXAxisLabels() {
    if (widget.labels.isEmpty) return [];
    if (widget.labels.length <= 4) {
      return widget.labels.map((l) => _xAxisLabel(l)).toList();
    }
    // If there are many labels, show first, mid-left, mid-right, and last to prevent overlap
    final int len = widget.labels.length;
    return [
      _xAxisLabel(widget.labels.first),
      _xAxisLabel(widget.labels[(len * 0.33).toInt()]),
      _xAxisLabel(widget.labels[(len * 0.66).toInt()]),
      _xAxisLabel(widget.labels.last),
    ];
  }

  Widget _xAxisLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StockChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color trendColor;
  final int? selectedIndex;
  final bool isDarkMode;

  _StockChartPainter({
    required this.dataPoints,
    required this.trendColor,
    this.selectedIndex,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double usableHeight = size.height - 40;
    final double widthBetweenPoints = dataPoints.length > 1
        ? size.width / (dataPoints.length - 1)
        : size.width;

    // ─── 1. Draw Grid Lines ──────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)
      ..strokeWidth = 1.0;

    // Draw horizontal guidelines (25%, 50%, 75%, 100%)
    final gridLevels = [0.25, 0.5, 0.75, 1.0];
    for (final level in gridLevels) {
      final y = size.height - 20 - (level * usableHeight);
      _drawDashedLine(canvas, y, size.width, gridPaint);
    }

    // ─── 2. Prepare Data Offsets ─────────────────────────────────────────────
    final List<Offset> points = [];
    for (int i = 0; i < dataPoints.length; i++) {
      final double x = i * widthBetweenPoints;
      final double normalizedValue = dataPoints[i] / 100.0;
      final double y = size.height - 20 - (normalizedValue * usableHeight);
      points.add(Offset(x, y));
    }

    // ─── 3. Draw Gradient Fill Area ──────────────────────────────────────────
    final Path areaPath = Path();
    areaPath.moveTo(points.first.dx, size.height);
    areaPath.lineTo(points.first.dx, points.first.dy);

    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        final double xControl = (points[i].dx + points[i + 1].dx) / 2;
        areaPath.quadraticBezierTo(
          points[i].dx,
          points[i].dy,
          xControl,
          (points[i].dy + points[i + 1].dy) / 2,
        );
      }
      areaPath.lineTo(points.last.dx, points.last.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();

    final Paint areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          trendColor.withOpacity(0.25),
          trendColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, areaPaint);

    // ─── 4. Draw Glow Shadow Line ────────────────────────────────────────────
    final Path linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);

    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        final double xControl = (points[i].dx + points[i + 1].dx) / 2;
        linePath.quadraticBezierTo(
          points[i].dx,
          points[i].dy,
          xControl,
          (points[i].dy + points[i + 1].dy) / 2,
        );
      }
      linePath.lineTo(points.last.dx, points.last.dy);
    }

    // Glowing effect
    final Paint glowPaint = Paint()
      ..color = trendColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, glowPaint);

    // Main line
    final Paint mainLinePaint = Paint()
      ..color = trendColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, mainLinePaint);

    // ─── 5. Draw Selected Crosshair / Interactive Indicators ────────────────
    if (selectedIndex != null && selectedIndex! < points.length) {
      final selectedPoint = points[selectedIndex!];

      // Vertical crosshair dashed line
      final crosshairPaint = Paint()
        ..color = trendColor.withOpacity(0.5)
        ..strokeWidth = 1.2;
      _drawVerticalDashedLine(canvas, selectedPoint.dx, size.height, crosshairPaint);

      // Selected point pulse/glow circles
      final Paint pulsePaint = Paint()
        ..color = trendColor.withOpacity(0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedPoint, 15, pulsePaint);

      final Paint pointOutlinePaint = Paint()
        ..color = isDarkMode ? const Color(0xFF0F172A) : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedPoint, 7, pointOutlinePaint);

      final Paint pointPaint = Paint()
        ..color = trendColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selectedPoint, 4.5, pointPaint);
    } else {
      // Draw small dots at each data point by default
      final Paint pointOutlinePaint = Paint()
        ..color = isDarkMode ? const Color(0xFF0F172A) : Colors.white
        ..style = PaintingStyle.fill;
      final Paint pointPaint = Paint()
        ..color = trendColor.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      for (final point in points) {
        canvas.drawCircle(point, 4, pointOutlinePaint);
        canvas.drawCircle(point, 2.5, pointPaint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, double y, double width, Paint paint) {
    double startX = 0;
    const double dashWidth = 5;
    const double dashSpace = 5;
    while (startX < width) {
      canvas.drawLine(Offset(startX, y), Offset(startX + dashWidth, y), paint);
      startX += dashWidth + dashSpace;
    }
  }

  void _drawVerticalDashedLine(Canvas canvas, double x, double height, Paint paint) {
    double startY = 0;
    const double dashHeight = 5;
    const double dashSpace = 4;
    while (startY < height) {
      canvas.drawLine(Offset(x, startY), Offset(x, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _StockChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.trendColor != trendColor ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
