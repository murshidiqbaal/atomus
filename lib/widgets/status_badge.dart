import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'neu_box.dart';

enum BadgeStatus {
  excellent(AppColors.success, 'Excellent'),
  good(AppColors.info, 'Good'),
  average(AppColors.warning, 'Average'),
  needsImprovement(AppColors.error, 'Needs Improvement');

  final Color color;
  final String label;

  const BadgeStatus(this.color, this.label);

  static BadgeStatus fromProgress(double progress) {
    if (progress >= 0.85) return BadgeStatus.excellent;
    if (progress >= 0.70) return BadgeStatus.good;
    if (progress >= 0.50) return BadgeStatus.average;
    return BadgeStatus.needsImprovement;
  }
}

class StatusBadge extends StatelessWidget {
  final BadgeStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return NeuBox(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      borderRadius: 12,
      isPressed: true,
      color: AppColors.neuBase,
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
