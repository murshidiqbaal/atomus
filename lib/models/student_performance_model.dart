import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SubjectPerformance {
  final String subjectId;
  final String subjectName;
  final double attendancePercentage; // 0.0 to 100.0
  final double marksPercentage; // 0.0 to 100.0
  final double combinedScore; // 0.0 to 100.0
  final String status; // 'Excellent', 'Good', 'Average', etc.

  const SubjectPerformance({
    required this.subjectId,
    required this.subjectName,
    required this.attendancePercentage,
    required this.marksPercentage,
    required this.combinedScore,
    required this.status,
  });
}

class StudentPerformanceModel {
  final double attendancePercentage; // 0.0 to 100.0
  final double marksPercentage; // 0.0 to 100.0
  final double
  academicPerformanceScore; // 0.0 to 100.0 (overall composite scoring)
  final String
  progressStatus; // 'Excellent', 'Good', 'Average', 'Needs Improvement', 'At Risk'
  final int performanceRank; // Class / Course / Batch rank
  final List<SubjectPerformance> subjectWisePerformance;

  // Backward compatibility getter:
  double get academicPerformance => academicPerformanceScore;

  const StudentPerformanceModel({
    required this.attendancePercentage,
    required this.marksPercentage,
    double? academicPerformance,
    double? academicPerformanceScore,
    required this.progressStatus,
    this.performanceRank = 1,
    required this.subjectWisePerformance,
  }) : academicPerformanceScore =
           academicPerformanceScore ?? academicPerformance ?? 0.0;

  Color get progressColor {
    if (academicPerformanceScore >= 90.0) return AppColors.success;
    if (academicPerformanceScore >= 75.0) return AppColors.primary;
    if (academicPerformanceScore >= 60.0) return AppColors.accent;
    if (academicPerformanceScore >= 40.0) return AppColors.info;
    return Colors.redAccent;
  }

  static String getStatusLabel(double score) {
    if (score >= 90.0) return 'Excellent';
    if (score >= 75.0) return 'Good';
    if (score >= 60.0) return 'Average';
    if (score >= 40.0) return 'Needs Improvement';
    return 'At Risk';
  }
}

typedef StudentAcademicPerformanceModel = StudentPerformanceModel;
