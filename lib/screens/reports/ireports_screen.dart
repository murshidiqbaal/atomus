import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../blocs/daily_report/daily_report_cubit.dart';
import '../../blocs/daily_report/daily_report_state.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../models/daily_report_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/neu_box.dart';

class IReportsScreen extends StatefulWidget {
  const IReportsScreen({super.key});

  @override
  State<IReportsScreen> createState() => _IReportsScreenState();
}

class _IReportsScreenState extends State<IReportsScreen>
    with AutomaticKeepAliveClientMixin {
  String? _lastLoadedStudentId;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    final studentState = context.read<StudentBloc>().state;
    final studentId = studentState.studentInfo?.id;
    if (studentId != null && studentId != _lastLoadedStudentId) {
      _lastLoadedStudentId = studentId;
      context.read<DailyReportCubit>().fetchReportsForCurrentStudent(
        studentId: studentId,
      );
    }
  }

  Future<void> _refresh() async {
    final studentState = context.read<StudentBloc>().state;
    final studentId = studentState.studentInfo?.id;
    if (studentId != null) {
      _lastLoadedStudentId = studentId;
      await context.read<DailyReportCubit>().fetchReportsForCurrentStudent(
        studentId: studentId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AppBackground(
      child: SafeArea(
        child: BlocListener<StudentBloc, StudentState>(
          listenWhen: (previous, current) =>
              previous.studentInfo?.id != current.studentInfo?.id,
          listener: (context, studentState) {
            final studentId = studentState.studentInfo?.id;
            if (studentId != null && studentId != _lastLoadedStudentId) {
              _lastLoadedStudentId = studentId;
              context.read<DailyReportCubit>().fetchReportsForCurrentStudent(
                studentId: studentId,
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: BlocBuilder<DailyReportCubit, DailyReportState>(
                  builder: (context, state) {
                    if (state.status == DailyReportStatus.loading &&
                        state.studentReports.isEmpty) {
                      return _buildLoadingState();
                    }
                    if (state.status == DailyReportStatus.failure) {
                      return _buildErrorState(state.errorMessage);
                    }
                    if (state.studentReports.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _buildReportsList(state.studentReports);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          NeuBox(
            width: 46,
            height: 46,
            borderRadius: 14,
            padding: EdgeInsets.zero,
            child: const Center(
              child: Icon(
                LucideIcons.clipboardList,
                color: AppColors.primary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Reports',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Daily reports from your teachers',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<DailyReportCubit, DailyReportState>(
            builder: (context, state) {
              final isLoading = state.status == DailyReportStatus.loading;
              return NeuBox(
                width: 40,
                height: 40,
                borderRadius: 12,
                padding: EdgeInsets.zero,
                onTap: isLoading ? null : _refresh,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          LucideIcons.refreshCw,
                          color: AppColors.primary,
                          size: 18,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: 5,
      itemBuilder: (_, __) => _buildSkeletonCard(),
    );
  }

  Widget _buildSkeletonCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeuBox(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _shimmer(width: 120, height: 14),
                const Spacer(),
                _shimmer(width: 70, height: 22, radius: 8),
              ],
            ),
            const SizedBox(height: 12),
            _shimmer(width: double.infinity, height: 10),
            const SizedBox(height: 6),
            _shimmer(width: 200, height: 10),
          ],
        ),
      ),
    );
  }

  Widget _shimmer({required double width, double height = 12, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuBox(
              width: 72,
              height: 72,
              borderRadius: 20,
              child: const Icon(
                LucideIcons.alertCircle,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load reports',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message ?? 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            NeuBox(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              borderRadius: 14,
              onTap: _refresh,
              child: Text(
                'Retry',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuBox(
              width: 80,
              height: 80,
              borderRadius: 24,
              child: const Icon(
                LucideIcons.fileText,
                color: AppColors.textSecondary,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Reports Yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your teachers haven\'t added any daily reports yet.\nCheck back later!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsList(List<DailyReportModel> reports) {
    // Group reports by date
    final grouped = <String, List<DailyReportModel>>{};
    for (final report in reports) {
      grouped.putIfAbsent(report.dateStr, () => []).add(report);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          final dateStr = sortedDates[index];
          final dayReports = grouped[dateStr]!;
          return _buildDateGroup(dateStr, dayReports);
        },
      ),
    );
  }

  Widget _buildDateGroup(String dateStr, List<DailyReportModel> reports) {
    final date = DateTime.tryParse(dateStr);
    final displayDate = date != null
        ? DateFormat('EEEE, d MMMM yyyy').format(date)
        : dateStr;
    final isToday = date != null &&
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.textSecondary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isToday ? 'Today' : displayDate,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isToday ? AppColors.primary : AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (!isToday) ...[
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE').format(date ?? DateTime.now()),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...reports.map((report) => _buildReportCard(report)),
      ],
    );
  }

  Widget _buildReportCard(DailyReportModel report) {
    final behaviorColor = _behaviorColor(report.behaviorRating);
    final engagementColor = _engagementColor(report.studyEngagement);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.subjectName ?? 'General Report',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by ${report.teacherName}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildChip(
                  report.behaviorRating,
                  behaviorColor,
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Metrics row
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    icon: LucideIcons.brain,
                    label: 'Engagement',
                    value: report.studyEngagement,
                    color: engagementColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricItem(
                    icon: LucideIcons.bookCheck,
                    label: 'Homework',
                    value: report.homeworkStatus,
                    color: _homeworkColor(report.homeworkStatus),
                  ),
                ),
              ],
            ),

            // Remarks
            if (report.remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.messageSquare,
                      size: 14,
                      color: AppColors.primary.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.remarks,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _behaviorColor(String rating) {
    switch (rating) {
      case 'Excellent':
        return AppColors.success;
      case 'Good':
        return AppColors.info;
      case 'Average':
        return AppColors.warning;
      case 'Needs Improvement':
        return const Color(0xFFFF8C42);
      case 'Poor':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _engagementColor(String engagement) {
    switch (engagement) {
      case 'Active':
        return AppColors.success;
      case 'Passive':
        return AppColors.warning;
      case 'Distracted':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _homeworkColor(String status) {
    switch (status) {
      case 'Completed':
        return AppColors.success;
      case 'Partial':
        return AppColors.warning;
      case 'Not Completed':
        return AppColors.error;
      case 'N/A':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }
}
