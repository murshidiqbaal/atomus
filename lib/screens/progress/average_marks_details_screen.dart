import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../models/dummy_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/stock_chart.dart';
import '../../widgets/shimmer.dart';

class AverageMarksDetailsScreen extends StatefulWidget {
  const AverageMarksDetailsScreen({super.key});

  @override
  State<AverageMarksDetailsScreen> createState() =>
      _AverageMarksDetailsScreenState();
}

class _AverageMarksDetailsScreenState extends State<AverageMarksDetailsScreen> {
  String _selectedFilter = 'All'; // 'All', 'Regular', 'Daily'

  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      try {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            return DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } else {
            return DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        }
      } catch (_) {}
      return DateTime(2000);
    }
  }

  double _calculateExamPercentage(ExamSession exam) {
    double obtained = 0;
    double total = 0;
    for (var sub in exam.subjects) {
      obtained += sub.marksObtained;
      total += sub.totalMarks;
    }
    return total > 0 ? (obtained / total) * 100 : 0.0;
  }

  String _calculateGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    return 'F';
  }

  Widget _buildFilterButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Exam Marks Analytics'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<StudentBloc, StudentState>(
          builder: (context, state) {
            if (state.status == StudentStatus.loading) {
              return GlassBackground(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Shimmer.statsHeaderSkeleton(),
                      const SizedBox(height: 32),
                      Shimmer.chartSkeleton(height: 180),
                      const SizedBox(height: 48),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Shimmer(width: 160, height: 18),
                          Shimmer(width: 80, height: 12),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(3, (_) => Shimmer.cardSkeleton()),
                    ],
                  ),
                ),
              );
            }

            final student = state.studentInfo;
            if (student == null) return const SizedBox();

            final exams = state.exams;
            if (exams.isEmpty) {
              return const GlassBackground(
                child: Center(
                  child: Text(
                    'No academic evaluations found.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            // 1. Sort exams chronologically (oldest to newest) for chart and stats calculations
            final sortedExams = List<ExamSession>.from(
              exams,
            )..sort((a, b) => _parseDate(a.date).compareTo(_parseDate(b.date)));

            // 2. Filter exams based on tab selection
            final filteredSortedExams = sortedExams.where((exam) {
              if (_selectedFilter == 'Regular') return !exam.isDaily;
              if (_selectedFilter == 'Daily') return exam.isDaily;
              return true;
            }).toList();

            // 3. Compute stats
            double overallTotalObtained = 0;
            double overallTotalPossible = 0;
            double peakScore = 0;
            double lowestScore = 100;

            for (final exam in filteredSortedExams) {
              double examObtained = 0;
              double examPossible = 0;
              for (final sub in exam.subjects) {
                examObtained += sub.marksObtained;
                examPossible += sub.totalMarks;
              }
              if (examPossible > 0) {
                final percentage = (examObtained / examPossible) * 100;
                overallTotalObtained += examObtained;
                overallTotalPossible += examPossible;
                if (percentage > peakScore) peakScore = percentage;
                if (percentage < lowestScore) lowestScore = percentage;
              }
            }

            final performance = state.performance;
            final double avgScore = performance != null
                ? performance.marksPercentage
                : (overallTotalPossible > 0
                    ? (overallTotalObtained / overallTotalPossible) * 100
                    : 0.0);
            if (lowestScore > 100) lowestScore = 0.0;

            // Trend (hike/decrease) relative to oldest exam in selection
            double trendPctDiff = 0.0;
            bool isUpTrend = true;
            if (filteredSortedExams.isNotEmpty) {
              final firstPct = _calculateExamPercentage(
                filteredSortedExams.first,
              );
              final lastPct = _calculateExamPercentage(
                filteredSortedExams.last,
              );
              trendPctDiff = lastPct - firstPct;
              isUpTrend = trendPctDiff >= 0;
            }

            final trendColor = isUpTrend ? AppColors.success : AppColors.error;
            final trendText =
                '${isUpTrend ? '▲' : '▼'} ${trendPctDiff.abs().toStringAsFixed(1)}% ${isUpTrend ? 'Hike' : 'Decrease'}';

            // Generate graph data points
            final chartPoints = filteredSortedExams
                .map((e) => _calculateExamPercentage(e))
                .toList();
            final chartLabels = filteredSortedExams.map((e) {
              try {
                final date = _parseDate(e.date);
                return DateFormat('d MMM').format(date);
              } catch (_) {
                return e.date;
              }
            }).toList();
            final chartExamNames = filteredSortedExams
                .map((e) => e.title)
                .toList();

            // 4. Create display lists (Newest to Oldest)
            final displayExams = List<ExamSession>.from(
              filteredSortedExams,
            ).reversed.toList();

            return GlassBackground(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Stock Header Card ───────────────────────────────────
                    CustomCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AVERAGE EXAM PERFORMANCE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                avgScore.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  letterSpacing: -1,
                                ),
                              ),
                              const Text(
                                '%',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              if (filteredSortedExams.length > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: trendColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: trendColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    trendText.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: trendColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const NeuDivider(),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'PEAK',
                                '${peakScore.toStringAsFixed(1)}%',
                                AppColors.success,
                              ),
                              _buildStatItem(
                                'LOWEST',
                                '${lowestScore.toStringAsFixed(1)}%',
                                AppColors.error,
                              ),
                              _buildStatItem(
                                'TOTAL EXAMS',
                                '${filteredSortedExams.length}',
                                AppColors.info,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Trading Stock Graph ────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // const Text(
                        //   'Performance Trajectory',
                        //   style: TextStyle(
                        //     fontSize: 18,
                        //     fontWeight: FontWeight.bold,
                        //     color: AppColors.primary,
                        //   ),
                        // ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _buildFilterButton(
                                'All',
                                _selectedFilter == 'All',
                              ),
                              _buildFilterButton(
                                'Regular',
                                _selectedFilter == 'Regular',
                              ),
                              _buildFilterButton(
                                'Daily',
                                _selectedFilter == 'Daily',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    CustomCard(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                      child: chartPoints.isEmpty
                          ? const SizedBox(
                              height: 180,
                              child: Center(
                                child: Text(
                                  'No evaluation data found in this range.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          : StockChart(
                              dataPoints: chartPoints,
                              labels: chartLabels,
                              examNames: chartExamNames,
                              height: 180,
                            ),
                    ),
                    const SizedBox(height: 48),

                    // ─── Detailed Exams List ────────────────────────────────
                    const Text(
                      'Exam Statistics & Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (displayExams.isEmpty)
                      const Center(
                        child: Text(
                          'No detailed statistics available.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...displayExams.map((exam) {
                        // Find chronological index in sortedExams to compute trend relative to previous exam
                        final chronologicalIndex = sortedExams.indexOf(exam);
                        double examPct = _calculateExamPercentage(exam);
                        String grade = _calculateGrade(examPct);

                        // Calculate relative trend compared to previous exam in sorted list
                        IconData trendIcon = LucideIcons.minus;
                        Color relativeTrendColor = AppColors.textSecondary;
                        String relativeTrendText = 'Flat';

                        if (chronologicalIndex > 0) {
                          final prevExam = sortedExams[chronologicalIndex - 1];
                          final prevExamPct = _calculateExamPercentage(
                            prevExam,
                          );
                          final diff = examPct - prevExamPct;
                          if (diff > 0.1) {
                            trendIcon = LucideIcons.trendingUp;
                            relativeTrendColor = AppColors.success;
                            relativeTrendText = '+${diff.toStringAsFixed(1)}%';
                          } else if (diff < -0.1) {
                            trendIcon = LucideIcons.trendingDown;
                            relativeTrendColor = AppColors.error;
                            relativeTrendText = '${diff.toStringAsFixed(1)}%';
                          }
                        }

                        String formattedDate = exam.date;
                        try {
                          final parsedDate = DateTime.tryParse(exam.date);
                          if (parsedDate != null) {
                            formattedDate = DateFormat(
                              'MMMM d, yyyy',
                            ).format(parsedDate);
                          }
                        } catch (_) {}

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: CustomCard(
                            padding: EdgeInsets.zero,
                            child: ExpansionTile(
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              collapsedShape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              iconColor: AppColors.accent,
                              collapsedIconColor: AppColors.primary,
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              title: Text(
                                exam.title.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  exam.isDaily
                                      ? 'DAILY ASSESSMENT • $formattedDate'
                                      : 'EXAM CONCLUDED • $formattedDate',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Relative Trend arrow indicator
                                  if (chronologicalIndex > 0) ...[
                                    Icon(
                                      trendIcon,
                                      size: 14,
                                      color: relativeTrendColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      relativeTrendText,
                                      style: TextStyle(
                                        color: relativeTrendColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                  ],
                                  // Score badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(
                                        0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${examPct.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Grade badge
                                  NeuBox(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    borderRadius: 10,
                                    isPressed: true,
                                    child: Text(
                                      grade,
                                      style: const TextStyle(
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                              childrenPadding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                24,
                              ),
                              children: [
                                const NeuDivider(),
                                const SizedBox(height: 20),
                                ...exam.subjects.map((subject) {
                                  double subPct = subject.totalMarks > 0
                                      ? (subject.marksObtained /
                                                subject.totalMarks) *
                                            100
                                      : 0.0;
                                  Color subColor = AppColors.primary;
                                  if (subPct >= 80) {
                                    subColor = AppColors.success;
                                  } else if (subPct >= 60) {
                                    subColor = AppColors.accent;
                                  } else if (subPct >= 40) {
                                    subColor = AppColors.warning;
                                  } else {
                                    subColor = AppColors.error;
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subject.subject,
                                            style: const TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${subject.marksObtained}/${subject.totalMarks}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: subColor.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: subColor.withOpacity(0.15),
                                            ),
                                          ),
                                          child: Text(
                                            subject.grade,
                                            style: TextStyle(
                                              color: subColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }),
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

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
