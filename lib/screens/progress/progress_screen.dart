import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../models/student_performance_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/progress_chart.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Performance Analytics')),
        body: BlocBuilder<StudentBloc, StudentState>(
          builder: (context, state) {
            if (state.status == StudentStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final student = state.studentInfo;
            if (student == null) return const SizedBox();

            final performance = state.performance;
            final double academicPerformance = performance != null
                ? performance.academicPerformance / 100.0
                : _computeAcademicPerformance(state);
            final double attendancePercentage = performance != null
                ? performance.attendancePercentage
                : student.attendancePercentage;
            final double marksPercentage = performance != null
                ? performance.marksPercentage
                : academicPerformance * 100.0;

            // Generate Trajectory Chart data dynamically
            final chartDataPoints = <double>[];
            final chartLabels = <String>[];

            if (state.exams.isNotEmpty) {
              final orderedExams = state.exams.reversed.toList();
              for (final session in orderedExams.take(6)) {
                double sessionObtained = 0;
                double sessionTotal = 0;
                for (final sub in session.subjects) {
                  sessionObtained += sub.marksObtained;
                  sessionTotal += sub.totalMarks;
                }
                if (sessionTotal > 0) {
                  chartDataPoints.add(sessionObtained / sessionTotal);
                  final title = session.title;
                  chartLabels.add(
                    title.length > 5
                        ? title.substring(0, 5).toUpperCase()
                        : title.toUpperCase(),
                  );
                }
              }
            }

            // Fallback for chart if no exams
            if (chartDataPoints.isEmpty) {
              chartDataPoints.addAll([0.72, 0.78, 0.75, 0.88, 0.85, 0.92]);
              chartLabels.addAll(['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN']);
            }

            // Compute statistics
            double peakScore = 0;
            if (performance != null && performance.subjectWisePerformance.isNotEmpty) {
              peakScore = performance.subjectWisePerformance
                  .map((p) => p.combinedScore)
                  .reduce((a, b) => a > b ? a : b);
            } else {
              peakScore = marksPercentage > 0 ? marksPercentage : 94.0;
            }

            final double avgScore = academicPerformance * 100;
            final double trendScore = peakScore - avgScore;
            final String trendSign = trendScore >= 0 ? '+' : '';

            return GlassBackground(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Academic Trajectory',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          ProgressChart(
                            dataPoints: chartDataPoints,
                            labels: chartLabels,
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('PEAK', '${peakScore.toInt()}%', AppColors.success),
                              _buildStatItem('AVG', '${avgScore.toInt()}%', AppColors.accent),
                              _buildStatItem('TREND', '$trendSign${trendScore.toInt()}%', AppColors.info),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    const Text(
                      'Composite Scoring Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnalyticalBreakdown(
                      context,
                      marksPercentage: marksPercentage,
                      attendancePercentage: attendancePercentage,
                    ),

                    const SizedBox(height: 40),
                    const Text(
                      'Subject Proficiency',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._buildProficiencyList(context, performance),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double _computeAcademicPerformance(StudentState state) {
    if (state.exams.isEmpty) return 0.75;
    double totalObtained = 0.0;
    double totalMax = 0.0;
    for (var exam in state.exams) {
      for (var sub in exam.subjects) {
        totalObtained += sub.marksObtained;
        totalMax += sub.totalMarks;
      }
    }
    return totalMax > 0 ? (totalObtained / totalMax) : 0.75;
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticalBreakdown(
    BuildContext context, {
    required double marksPercentage,
    required double attendancePercentage,
  }) {
    final components = [
      {
        'label': 'ACADEMIC PERFORMANCE',
        'weight': '70%',
        'score': '${marksPercentage.toInt()}%',
        'value': marksPercentage / 100.0,
        'color': AppColors.primary,
      },
      {
        'label': 'ATTENDANCE CONSISTENCY',
        'weight': '30%',
        'score': '${attendancePercentage.toInt()}%',
        'value': attendancePercentage / 100.0,
        'color': AppColors.success,
      },
    ];

    return Column(
      children: components
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: NeuBox(
                padding: const EdgeInsets.all(20),
                borderRadius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c['label'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          c['weight'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: c['value'] as double,
                              minHeight: 6,
                              backgroundColor: AppColors.neuDark.withOpacity(
                                0.2,
                              ),
                              color: c['color'] as Color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          c['score'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<Widget> _buildProficiencyList(
    BuildContext context,
    StudentPerformanceModel? performance,
  ) {
    if (performance == null || performance.subjectWisePerformance.isEmpty) {
      // Return a refined template list if performance object isn't fully ready
      final proficiencies = [
        {'subject': 'MATHEMATICS', 'value': 0.85, 'color': AppColors.primary},
        {'subject': 'PHYSICAL SCIENCES', 'value': 0.80, 'color': AppColors.accent},
        {'subject': 'LITERATURE & ARTS', 'value': 0.88, 'color': AppColors.info},
        {'subject': 'SOCIAL STUDIES', 'value': 0.82, 'color': AppColors.success},
      ];

      return proficiencies
          .map((p) => _buildProficiencyRow(context, p['subject'] as String, p['value'] as double, p['color'] as Color))
          .toList();
    }

    return performance.subjectWisePerformance.map((p) {
      Color scoreColor = AppColors.primary;
      if (p.combinedScore >= 80) {
        scoreColor = AppColors.success;
      } else if (p.combinedScore >= 60) {
        scoreColor = AppColors.accent;
      } else if (p.combinedScore >= 40) {
        scoreColor = AppColors.warning;
      } else {
        scoreColor = AppColors.error;
      }

      return _buildProficiencyRow(
        context,
        p.subjectName.toUpperCase(),
        p.combinedScore / 100.0,
        scoreColor,
      );
    }).toList();
  }

  Widget _buildProficiencyRow(
    BuildContext context,
    String subject,
    double value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subject,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${(value * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          NeuInset(
            padding: EdgeInsets.zero,
            borderRadius: 10,
            child: Container(
              height: 12,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(seconds: 1),
                width: MediaQuery.of(context).size.width * value * 0.75,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.7),
                      color,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
