import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../blocs/student/student_event.dart';
import '../../models/dummy_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/stock_chart.dart';

class AverageAttendanceDetailsScreen extends StatefulWidget {
  const AverageAttendanceDetailsScreen({super.key});

  @override
  State<AverageAttendanceDetailsScreen> createState() =>
      _AverageAttendanceDetailsScreenState();
}

class _AverageAttendanceDetailsScreenState
    extends State<AverageAttendanceDetailsScreen> {
  String _selectedFilter = 'All'; // 'All', 'Present', 'Absent', 'Late/Leave'

  @override
  void initState() {
    super.initState();
    // Load all attendance records for cumulative chart and overall stats
    context.read<StudentBloc>().add(const LoadAttendance());
  }

  @override
  void dispose() {
    // Restore current month attendance filter for dashboard
    final now = DateTime.now();
    context.read<StudentBloc>().add(
      LoadAttendance(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      ),
    );
    super.dispose();
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            fontSize: 10,
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
          title: const Text('Attendance Analytics'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocBuilder<StudentBloc, StudentState>(
          builder: (context, state) {
            // Shimmer Loading Placeholder
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

            final records = state.attendance;
            if (records.isEmpty) {
              return const GlassBackground(
                child: Center(
                  child: Text(
                    'No attendance records found.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            // 1. Sort records chronologically (oldest to newest) for chart calculations
            final sortedRecords = List<AttendanceRecord>.from(records)
              ..sort((a, b) => a.date.compareTo(b.date));

            // 2. Calculate rolling cumulative attendance percentage
            final List<double> chartPoints = [];
            final List<String> chartLabels = [];
            final List<String> chartTooltips = [];

            int presentCount = 0;
            int totalPresent = 0;
            int totalAbsent = 0;
            int totalLate = 0;
            int totalLeave = 0;

            for (int i = 0; i < sortedRecords.length; i++) {
              final rec = sortedRecords[i];

              if (rec.status == 'Present') {
                totalPresent++;
                presentCount++;
              } else if (rec.status == 'Late') {
                totalLate++;
                presentCount++; // Late counts towards attendance presence
              } else if (rec.status == 'Absent') {
                totalAbsent++;
              } else if (rec.status == 'Leave') {
                totalLeave++; // Leave is neutral or non-penalized, but not strictly 'present'
              }

              // Compute rolling cumulative presence rate (Present + Late vs Total)
              final double cumulativeRate = (presentCount / (i + 1)) * 100;
              chartPoints.add(cumulativeRate);
              chartLabels.add(DateFormat('d MMM').format(rec.date));
              chartTooltips.add(
                '${rec.status} (${cumulativeRate.toStringAsFixed(1)}%)',
              );
            }

            // 3. Compute overall statistics
            final performance = state.performance;
            final double currentRate = performance != null
                ? performance.attendancePercentage
                : student.attendancePercentage;

            // Calculate trend based on cumulative rate difference
            double trendDiff = 0.0;
            bool isUpTrend = true;
            if (chartPoints.length > 1) {
              trendDiff = chartPoints.last - chartPoints.first;
              isUpTrend = trendDiff >= 0;
            }

            final trendColor = isUpTrend ? AppColors.success : AppColors.error;
            final trendText =
                '${isUpTrend ? '▲' : '▼'} ${trendDiff.abs().toStringAsFixed(1)}% ${isUpTrend ? 'Hike' : 'Decrease'}';

            // 4. Filter detailed records for list display
            final displayRecords = sortedRecords.reversed.where((rec) {
              if (_selectedFilter == 'Present') return rec.status == 'Present';
              if (_selectedFilter == 'Absent') return rec.status == 'Absent';
              if (_selectedFilter == 'Late/Leave')
                return rec.status == 'Late' || rec.status == 'Leave';
              return true;
            }).toList();

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
                            'OVERALL ATTENDANCE RATE',
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
                                currentRate.toStringAsFixed(1),
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
                              if (chartPoints.length > 1)
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
                                'PRESENT',
                                performance != null
                                    ? performance.presentPeriods.toStringAsFixed(0)
                                    : '$totalPresent',
                                AppColors.success,
                              ),
                              _buildStatItem(
                                'ABSENT',
                                performance != null
                                    ? '${performance.absentPeriods}'
                                    : '$totalAbsent',
                                AppColors.error,
                              ),
                              _buildStatItem(
                                'LATE',
                                performance != null
                                    ? '${performance.latePeriods}'
                                    : '$totalLate',
                                AppColors.warning,
                              ),
                              _buildStatItem(
                                'LEAVE',
                                performance != null
                                    ? '${performance.leavePeriods}'
                                    : '$totalLeave',
                                AppColors.info,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Attendance Stock Graph ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // const Text(
                        //   'Attendance Trajectory',
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
                                'Present',
                                _selectedFilter == 'Present',
                              ),
                              _buildFilterButton(
                                'Absent',
                                _selectedFilter == 'Absent',
                              ),
                              _buildFilterButton(
                                'Late/Leave',
                                _selectedFilter == 'Late/Leave',
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
                                  'No trajectory data available.',
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
                              examNames: chartTooltips,
                              height: 180,
                            ),
                    ),
                    const SizedBox(height: 48),

                    // ─── Detailed Records List ───────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Attendance History',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${displayRecords.length} RECORDS',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textSecondary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (displayRecords.isEmpty)
                      const Center(
                        child: Text(
                          'No attendance history records found for this filter.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...displayRecords.map((rec) {
                        final formattedDate = DateFormat(
                          'EEEE, MMMM d, yyyy',
                        ).format(rec.date);

                        Color badgeColor;
                        switch (rec.status) {
                          case 'Present':
                            badgeColor = AppColors.success;
                            break;
                          case 'Absent':
                            badgeColor = AppColors.error;
                            break;
                          case 'Late':
                            badgeColor = AppColors.warning;
                            break;
                          case 'Leave':
                            badgeColor = AppColors.info;
                            break;
                          default:
                            badgeColor = AppColors.textSecondary;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: CustomCard(
                            padding: const EdgeInsets.all(18),
                            child: Row(
                              children: [
                                // Left Status Icon Cylinder/Box
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    rec.status == 'Present'
                                        ? LucideIcons.checkCircle
                                        : rec.status == 'Absent'
                                        ? LucideIcons.xCircle
                                        : rec.status == 'Late'
                                        ? LucideIcons.clock
                                        : LucideIcons.calendarDays,
                                    color: badgeColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Middle Info Block
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formattedDate.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        rec.subjectName != null &&
                                                rec.subjectName!.isNotEmpty
                                            ? '${rec.subjectName} • Period ${rec.periodNumber ?? 1}'
                                            : 'General School Attendance',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (rec.markerName != null &&
                                          rec.markerName!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Marked by: ${rec.markerName} (${rec.markerRole ?? "Staff"})',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: AppColors.textSecondary
                                                .withOpacity(0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Right Status Tag
                                NeuBox(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  borderRadius: 10,
                                  isPressed: true,
                                  child: Text(
                                    rec.status.toUpperCase(),
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
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
