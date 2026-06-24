import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_event.dart';
import '../../blocs/student/student_state.dart';
import '../../models/dummy_data.dart';
import '../../models/student_performance_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/progress_chart.dart';
import '../../widgets/shimmer.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isMonthly = false;
  String? _startMonth;
  String? _endMonth;

  Widget _buildMonthDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final List<String> monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    String formatMonthKey(String key) {
      try {
        final parts = key.split('-');
        final monthIdx = int.parse(parts[1]) - 1;
        final year = parts[0];
        return '${monthNames[monthIdx]} $year';
      } catch (_) {
        return key;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.primary,
          ),
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0F172A)
              : Colors.white,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : AppColors.primary,
          ),
          items: items.map((String key) {
            return DropdownMenuItem<String>(
              value: key,
              child: Text(formatMonthKey(key)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    final studentBloc = context.read<StudentBloc>();
    studentBloc.add(LoadStudentData());
    await studentBloc.stream
        .firstWhere((s) => s.status != StudentStatus.loading)
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => studentBloc.state,
        );
  }

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

  Widget _buildToggleButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMonthly = label == 'Monthly';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
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
        appBar: AppBar(title: const Text('Performance Analytics')),
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
            final List<String> sortedAvailableMonths = [];

            if (state.exams.isNotEmpty) {
              final Set<String> availableMonths = {};
              for (final session in state.exams) {
                final date = _parseDate(session.date);
                final monthKey =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}';
                availableMonths.add(monthKey);
              }
              sortedAvailableMonths.addAll(availableMonths.toList()..sort());

              if (sortedAvailableMonths.isNotEmpty) {
                _startMonth ??= sortedAvailableMonths.length > 6
                    ? sortedAvailableMonths[sortedAvailableMonths.length - 6]
                    : sortedAvailableMonths.first;
                _endMonth ??= sortedAvailableMonths.last;
              }

              final sortedExams = List<ExamSession>.from(state.exams)
                ..sort(
                  (a, b) => _parseDate(a.date).compareTo(_parseDate(b.date)),
                );

              if (_isMonthly) {
                // Group exams by month
                final Map<String, List<double>> monthlyPercentages = {};
                final List<String> monthKeys = [];

                for (final session in sortedExams) {
                  double sessionObtained = 0;
                  double sessionTotal = 0;
                  for (final sub in session.subjects) {
                    sessionObtained += sub.marksObtained;
                    sessionTotal += sub.totalMarks;
                  }
                  if (sessionTotal > 0) {
                    final pct = sessionObtained / sessionTotal;
                    final date = _parseDate(session.date);
                    final monthKey =
                        '${date.year}-${date.month.toString().padLeft(2, '0')}';

                    if (!monthlyPercentages.containsKey(monthKey)) {
                      monthlyPercentages[monthKey] = [];
                      monthKeys.add(monthKey);
                    }
                    monthlyPercentages[monthKey]!.add(pct);
                  }
                }

                // Filter keys by range
                final List<String> filteredMonthKeys = monthKeys.where((key) {
                  if (_startMonth != null && key.compareTo(_startMonth!) < 0) {
                    return false;
                  }
                  if (_endMonth != null && key.compareTo(_endMonth!) > 0) {
                    return false;
                  }
                  return true;
                }).toList();

                final List<String> monthNames = [
                  'JAN',
                  'FEB',
                  'MAR',
                  'APR',
                  'MAY',
                  'JUN',
                  'JUL',
                  'AUG',
                  'SEP',
                  'OCT',
                  'NOV',
                  'DEC',
                ];

                for (final key in filteredMonthKeys) {
                  final parts = key.split('-');
                  final monthIndex = int.parse(parts[1]) - 1;
                  final year = parts[0].substring(2);

                  final pcts = monthlyPercentages[key]!;
                  final avgPct = pcts.reduce((a, b) => a + b) / pcts.length;

                  chartDataPoints.add(avgPct);
                  chartLabels.add('${monthNames[monthIndex]} \'$year');
                }
              } else {
                // Daily View: Take last 6 sorted exams
                final recentExams = sortedExams.length > 6
                    ? sortedExams.sublist(sortedExams.length - 6)
                    : sortedExams;

                for (final session in recentExams) {
                  double sessionObtained = 0;
                  double sessionTotal = 0;
                  for (final sub in session.subjects) {
                    sessionObtained += sub.marksObtained;
                    sessionTotal += sub.totalMarks;
                  }
                  if (sessionTotal > 0) {
                    chartDataPoints.add(sessionObtained / sessionTotal);
                    // Do NOT show dates like 25/5, 10/6 etc in Daily View.
                    chartLabels.add('');
                  }
                }
              }
            }

            // Compute statistics
            double peakScore = 0;
            if (performance != null &&
                performance.subjectWisePerformance.isNotEmpty) {
              peakScore = performance.subjectWisePerformance
                  .map((p) => p.combinedScore)
                  .reduce((a, b) => a > b ? a : b);
            } else {
              peakScore = marksPercentage > 0 ? marksPercentage : 0.0;
            }

            final double avgScore = academicPerformance * 100;
            final double trendScore = peakScore - avgScore;
            final String trendSign = trendScore >= 0 ? '+' : '';
            final String statusLabel = performance != null
                ? performance.progressStatus
                : StudentPerformanceModel.getStatusLabel(
                    academicPerformance * 100.0,
                  );

            return GlassBackground(
              child: RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.primary,
                onRefresh: _handleRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Overall Summary Card
                      CustomCard(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              height: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: CircularProgressIndicator(
                                      value: academicPerformance,
                                      strokeWidth: 8,
                                      backgroundColor: AppColors.primary
                                          .withOpacity(0.1),
                                      color:
                                          performance?.progressColor ??
                                          AppColors.primary,
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                  Text(
                                    '${avgScore.toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Class Rank: #${performance?.performanceRank ?? 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: AppColors.primary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (performance?.progressColor ??
                                                  AppColors.primary)
                                              .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      statusLabel.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color:
                                            performance?.progressColor ??
                                            AppColors.primary,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Academic Trajectory',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                _buildToggleButton('Daily', !_isMonthly),
                                _buildToggleButton('Monthly', _isMonthly),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      CustomCard(
                        padding: const EdgeInsets.all(24),
                        child: chartDataPoints.isEmpty
                            ? const SizedBox(
                                height: 160,
                                child: Center(
                                  child: Text(
                                    'No academic trajectory data available.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  if (_isMonthly &&
                                      sortedAvailableMonths.length > 1) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildMonthDropdown(
                                            label: 'Start Month',
                                            value: _startMonth,
                                            items: sortedAvailableMonths,
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _startMonth = val;
                                                  if (_endMonth != null &&
                                                      val.compareTo(
                                                            _endMonth!,
                                                          ) >
                                                          0) {
                                                    _endMonth = val;
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildMonthDropdown(
                                            label: 'End Month',
                                            value: _endMonth,
                                            items: sortedAvailableMonths,
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _endMonth = val;
                                                  if (_startMonth != null &&
                                                      val.compareTo(
                                                            _startMonth!,
                                                          ) <
                                                          0) {
                                                    _startMonth = val;
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  ProgressChart(
                                    dataPoints: chartDataPoints,
                                    labels: chartLabels,
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildStatItem(
                                        'PEAK',
                                        '${peakScore.toInt()}%',
                                        AppColors.success,
                                      ),
                                      _buildStatItem(
                                        'AVG',
                                        '${avgScore.toInt()}%',
                                        AppColors.accent,
                                      ),
                                      _buildStatItem(
                                        'TREND',
                                        '$trendSign${trendScore.toInt()}%',
                                        AppColors.info,
                                      ),
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
                        'Detailed Statistics',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      CustomCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetricDetail(
                                    'TOTAL EXAM',
                                    '${performance?.totalExams ?? state.exams.length}',
                                    Icons.assignment_rounded,
                                    AppColors.info,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildMetricDetail(
                                    'TOTAL PERIOD',
                                    '${performance?.totalPeriods ?? state.attendance.length}',
                                    Icons.calendar_month_rounded,
                                    AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const NeuDivider(),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatDetailItem(
                                  'Present',
                                  '${performance?.presentPeriods.toStringAsFixed(1) ?? state.attendance.where((r) => r.status == 'Present').length}',
                                  AppColors.success,
                                ),
                                _buildStatDetailItem(
                                  'Absent',
                                  '${performance?.absentPeriods ?? state.attendance.where((r) => r.status == 'Absent').length}',
                                  AppColors.error,
                                ),
                                _buildStatDetailItem(
                                  'Late',
                                  '${performance?.latePeriods ?? state.attendance.where((r) => r.status == 'Late').length}',
                                  AppColors.warning,
                                ),
                                // _buildStatDetailItem(
                                //   'Leave',
                                //   '${performance?.leavePeriods ?? state.attendance.where((r) => r.status == 'Leave').length}',
                                //   AppColors.accent,
                                // ),
                              ],
                            ),
                          ],
                        ),
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
              ),
            );
          },
        ),
      ),
    );
  }

  double _computeAcademicPerformance(StudentState state) {
    if (state.exams.isEmpty) return 0.0;
    double totalObtained = 0.0;
    double totalMax = 0.0;
    for (var exam in state.exams) {
      for (var sub in exam.subjects) {
        totalObtained += sub.marksObtained;
        totalMax += sub.totalMarks;
      }
    }
    return totalMax > 0 ? (totalObtained / totalMax) : 0.0;
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
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Center(
            child: Text(
              'No subject proficiency data available.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ),
        ),
      ];
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

  Widget _buildMetricDetail(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDetailItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
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
                    colors: [color.withOpacity(0.7), color],
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
