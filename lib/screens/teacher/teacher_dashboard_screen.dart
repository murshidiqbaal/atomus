import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/teacher_attendance/teacher_attendance_cubit.dart';
import '../../blocs/teacher_attendance/teacher_attendance_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/neu_box.dart';
import 'teacher_attendance_screen.dart';
import 'student_attendance_screen.dart';
import 'marks_entry_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  @override
  void initState() {
    super.initState();
    context.read<TeacherDashboardCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
            builder: (context, state) {
              if (state.status == TeacherDashboardStatus.loading &&
                  state.teacher == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.status == TeacherDashboardStatus.failure) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.alertCircle, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(state.errorMessage ?? 'Failed to load dashboard'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<TeacherDashboardCubit>().load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () => context.read<TeacherDashboardCubit>().refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildHeader(context, state),
                    const SizedBox(height: 16),
                    if (state.activeSession != null) ...[
                      _buildActiveSessionBanner(context, state),
                      const SizedBox(height: 16),
                    ],
                    _buildStatsRow(context, state),
                    const SizedBox(height: 20),
                    _buildQuickActions(context, state),
                    const SizedBox(height: 20),
                    if (state.upcomingExams.isNotEmpty) ...[
                      _buildSectionTitle('Upcoming Exams'),
                      const SizedBox(height: 10),
                      ...state.upcomingExams.map((e) => _buildExamTile(context, e)),
                    ],
                    const SizedBox(height: 20),
                    _buildAttendanceSummaryCard(context, state),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TeacherDashboardState state) {
    final name = state.teacher?.fullName ?? 'Teacher';
    final now  = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                DateFormat('EEEE, d MMM yyyy').format(now),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        NeuBox(
          width: 44,
          height: 44,
          borderRadius: 14,
          padding: EdgeInsets.zero,
          child: const Icon(LucideIcons.bellRing, size: 20, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildActiveSessionBanner(
      BuildContext context, TeacherDashboardState state) {
    final session = state.activeSession!;
    return BlocBuilder<TeacherAttendanceCubit, TeacherAttendanceState>(
      builder: (ctx, attState) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2B4A), Color(0xFF2A4A7F)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.playCircle, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLASS IN SESSION',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      session.subjectName ?? 'Active Class',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Started ${_timeAgo(session.startTime)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: attState.status == TeacherAttendanceLoadStatus.loading
                    ? null
                    : () => ctx.read<TeacherAttendanceCubit>().endSession(),
                child: const Text('End', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow(BuildContext context, TeacherDashboardState state) {
    final stats = state.stats;
    return Row(
      children: [
        _buildStatCard(context,
          icon: LucideIcons.bookOpen,
          label: 'Subjects',
          value: '${stats.todayClassCount}',
          color: AppColors.info,
        ),
        const SizedBox(width: 12),
        _buildStatCard(context,
          icon: LucideIcons.clipboardCheck,
          label: 'Attendance',
          value: '${stats.attendancePercentage.toInt()}%',
          color: AppColors.success,
        ),
        const SizedBox(width: 12),
        _buildStatCard(context,
          icon: LucideIcons.fileText,
          label: 'Pending Marks',
          value: '${stats.pendingMarksCount}',
          color: stats.pendingMarksCount > 0 ? AppColors.warning : AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: CustomCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                )),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, TeacherDashboardState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Quick Actions'),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildActionButton(
              context,
              icon: LucideIcons.mapPin,
              label: 'My\nAttendance',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const TeacherAttendanceScreen(),
              )),
            ),
            const SizedBox(width: 10),
            _buildActionButton(
              context,
              icon: LucideIcons.users,
              label: 'Student\nAttendance',
              color: AppColors.info,
              onTap: () => _openStudentAttendance(context, state),
            ),
            const SizedBox(width: 10),
            _buildActionButton(
              context,
              icon: LucideIcons.clipboardList,
              label: 'Enter\nMarks',
              color: AppColors.accent,
              onTap: () => _openMarksEntry(context, state),
            ),
            const SizedBox(width: 10),
            _buildActionButton(
              context,
              icon: LucideIcons.barChart2,
              label: 'Analytics',
              color: AppColors.success,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: CustomCard(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamTile(BuildContext context, dynamic exam) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CustomCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.fileCheck, color: AppColors.warning, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(
                    '${exam.subjectName}${exam.batchName != null ? " · ${exam.batchName}" : ""}',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (exam.examDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('d MMM').format(exam.examDate!),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSummaryCard(
      BuildContext context, TeacherDashboardState state) {
    final pct = state.stats.attendancePercentage;
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('My Monthly Attendance'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pct.toInt()}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _pctColor(pct),
                      ),
                    ),
                    Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: pct / 100,
                      backgroundColor: _pctColor(pct).withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(_pctColor(pct)),
                      strokeWidth: 7,
                    ),
                    Icon(LucideIcons.checkCircle,
                        color: _pctColor(pct), size: 22),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppColors.textSecondary,
        letterSpacing: 1.5,
      ),
    );
  }

  void _openStudentAttendance(BuildContext context, TeacherDashboardState state) {
    final subjects = state.teacher?.subjects ?? [];
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subjects assigned.')),
      );
      return;
    }
    if (subjects.length == 1) {
      final s = subjects.first;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StudentAttendanceScreen(
          subjectId:   s.subjectId,
          subjectName: s.subjectName,
          batchId:     s.batchId ?? '',
          batchName:   s.batchName,
          courseId:    s.courseId,
        ),
      ));
      return;
    }
    _showSubjectPicker(context, subjects, (s) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StudentAttendanceScreen(
          subjectId:   s.subjectId,
          subjectName: s.subjectName,
          batchId:     s.batchId ?? '',
          batchName:   s.batchName,
          courseId:    s.courseId,
        ),
      ));
    });
  }

  void _openMarksEntry(BuildContext context, TeacherDashboardState state) {
    final subjects = state.teacher?.subjects ?? [];
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subjects assigned.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MarksEntryScreen()),
    );
  }

  void _showSubjectPicker(
    BuildContext context,
    List<dynamic> subjects,
    void Function(dynamic) onSelect,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Select Subject',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...subjects.map((s) => ListTile(
                leading: const Icon(LucideIcons.bookOpen, color: AppColors.primary),
                title: Text(s.subjectName, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: s.batchName != null ? Text(s.batchName!) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onSelect(s);
                },
              )),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String _timeAgo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }

  Color _pctColor(double pct) {
    if (pct >= 80) return AppColors.success;
    if (pct >= 60) return AppColors.warning;
    return AppColors.error;
  }
}
