import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/marks/marks_cubit.dart';
import '../../blocs/marks/marks_state.dart';
import '../../blocs/teacher_attendance/teacher_attendance_cubit.dart';
import '../../blocs/teacher_attendance/teacher_attendance_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({super.key});

  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher != null) {
      context
          .read<TeacherAttendanceCubit>()
          .loadHistory(teacher.id);
      final subjectIds = teacher.subjects.map((s) => s.subjectId).toList();
      if (subjectIds.isNotEmpty) {
        context.read<MarksCubit>().loadExams(subjectIds: subjectIds);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Analytics',
              style: TextStyle(fontWeight: FontWeight.w800)),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAttendanceAnalytics(context),
            const SizedBox(height: 16),
            _buildExamSummary(context),
            const SizedBox(height: 16),
            _buildSubjectBreakdown(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceAnalytics(BuildContext context) {
    return BlocBuilder<TeacherAttendanceCubit, TeacherAttendanceState>(
      builder: (ctx, state) {
        final history   = state.history;
        final completed = history.where((r) => r.isCompleted).length;
        final total     = history.length;
        final pct       = total > 0 ? (completed / total * 100) : 0.0;
        final avgMins   = completed > 0
            ? history
                    .where((r) => r.totalDurationMinutes != null)
                    .fold<int>(0, (s, r) => s + (r.totalDurationMinutes ?? 0)) /
                completed
            : 0.0;

        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.calendarCheck,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text('MY ATTENDANCE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _statBlock(
                        '${pct.toInt()}%', 'Attendance Rate',
                        _pctColor(pct)),
                  ),
                  Expanded(
                    child: _statBlock(
                        '$completed/$total', 'Sessions Done', AppColors.info),
                  ),
                  Expanded(
                    child: _statBlock(
                        '${avgMins.toInt()}m', 'Avg Duration',
                        AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: _pctColor(pct).withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(_pctColor(pct)),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExamSummary(BuildContext context) {
    return BlocBuilder<MarksCubit, MarksState>(
      builder: (ctx, state) {
        final exams      = state.exams;
        final done       = exams.where((e) => e.isMarksEntered).length;
        final pending    = exams.length - done;

        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.fileText,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  const Text('EXAMS SUMMARY',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _statBlock(
                        '${exams.length}', 'Total Exams', AppColors.info),
                  ),
                  Expanded(
                    child: _statBlock(
                        '$done', 'Marks Entered', AppColors.success),
                  ),
                  Expanded(
                    child: _statBlock(
                        '$pending', 'Pending',
                        pending > 0 ? AppColors.warning : AppColors.success),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubjectBreakdown(BuildContext context) {
    return BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
      builder: (ctx, state) {
        final subjects = state.teacher?.subjects ?? [];
        if (subjects.isEmpty) return const SizedBox.shrink();

        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ASSIGNED SUBJECTS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5)),
              const SizedBox(height: 12),
              ...subjects.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(LucideIcons.bookOpen,
                              color: AppColors.primary, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.subjectName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              if (s.batchName != null)
                                Text(s.batchName!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        if (s.courseName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(s.courseName!,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _statBlock(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ],
    );
  }

  Color _pctColor(double pct) {
    if (pct >= 80) return AppColors.success;
    if (pct >= 60) return AppColors.warning;
    return AppColors.error;
  }
}
