import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../blocs/geofence/geofence_cubit.dart';
import '../../blocs/geofence/geofence_state.dart';
import '../../blocs/teacher_attendance/teacher_attendance_cubit.dart';
import '../../blocs/teacher_attendance/teacher_attendance_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../models/teacher_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';
import 'marks_entry_screen.dart';
import 'student_attendance_screen.dart';
import 'teacher_attendance_screen.dart';

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
          child: BlocConsumer<TeacherDashboardCubit, TeacherDashboardState>(
            listener: (ctx, state) {},
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
                      const Icon(
                        LucideIcons.alertCircle,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(state.errorMessage ?? 'Failed to load dashboard'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            context.read<TeacherDashboardCubit>().load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () =>
                    context.read<TeacherDashboardCubit>().refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    _buildHeader(context, state),
                    const SizedBox(height: 12),
                    _buildGeofenceStatusBar(context, state),
                    const SizedBox(height: 12),
                    if (state.activeSession != null) ...[
                      _buildActiveSessionBanner(context, state),
                      const SizedBox(height: 16),
                    ],
                    _buildStatsRow(context, state),
                    const SizedBox(height: 20),
                    _buildAssignedClassesCarousel(context, state),
                    const SizedBox(height: 20),
                    _buildQuickActions(context, state),
                    const SizedBox(height: 20),
                    if (state.upcomingExams.isNotEmpty) ...[
                      _buildSectionTitle('Upcoming Exams'),
                      const SizedBox(height: 10),
                      ...state.upcomingExams.map(
                        (e) => _buildExamTile(context, e),
                      ),
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

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, TeacherDashboardState state) {
    final name = state.teacher?.fullName ?? 'Teacher';
    final now = DateTime.now();
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
          child: const Icon(
            LucideIcons.bellRing,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // ── Geofence / GPS status bar ───────────────────────────────────────────────

  Widget _buildGeofenceStatusBar(
    BuildContext context,
    TeacherDashboardState dashState,
  ) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (ctx, geo) {
        final bool hasCampus = dashState.teacher?.hasCampusCoordinates ?? false;
        final bool hasActiveSession = dashState.activeSession != null;

        Color barColor;
        IconData barIcon;
        String barLabel;

        if (!hasCampus) {
          barColor = AppColors.textSecondary;
          barIcon = LucideIcons.mapPin;
          barLabel = 'No campus location configured';
        } else {
          switch (geo.status) {
            case GeofenceStatus.inside:
              barColor = AppColors.success;
              barIcon = LucideIcons.mapPin;
              barLabel = 'Inside campus · attendance unlocked';
            case GeofenceStatus.outside:
              barColor = AppColors.error;
              barIcon = LucideIcons.mapPinOff;
              barLabel = 'Outside campus · ${geo.distanceMeters.toInt()}m away';
            case GeofenceStatus.checking:
              barColor = AppColors.info;
              barIcon = LucideIcons.loader;
              barLabel = 'Verifying location...';
            case GeofenceStatus.permissionDenied:
              barColor = AppColors.warning;
              barIcon = LucideIcons.shieldOff;
              barLabel = 'Location permission denied';
            case GeofenceStatus.serviceDisabled:
              barColor = AppColors.warning;
              barIcon = LucideIcons.wifiOff;
              barLabel = 'GPS disabled — enable location services';
            case GeofenceStatus.error:
              barColor = AppColors.warning;
              barIcon = LucideIcons.alertTriangle;
              barLabel = 'Location error — tap to retry';
            case GeofenceStatus.unknown:
              barColor = AppColors.textSecondary;
              barIcon = LucideIcons.mapPin;
              barLabel = hasCampus
                  ? 'Tap to verify campus location'
                  : 'Campus location not set';
          }
        }

        return GestureDetector(
          onTap: hasCampus && geo.status != GeofenceStatus.checking
              ? () => ctx.read<GeofenceCubit>().checkGeofence(
                  campusLatitude: dashState.teacher!.campusLatitude!,
                  campusLongitude: dashState.teacher!.campusLongitude!,
                  radiusMeters: dashState.teacher!.geofenceRadiusMeters,
                )
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: barColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                geo.status == GeofenceStatus.checking
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: barColor,
                        ),
                      )
                    : Icon(barIcon, size: 16, color: barColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    barLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                  ),
                ),
                // Attendance lock badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (hasActiveSession ||
                            geo.status == GeofenceStatus.inside)
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (hasActiveSession ||
                                geo.status == GeofenceStatus.inside)
                            ? LucideIcons.unlock
                            : LucideIcons.lock,
                        size: 10,
                        color:
                            (hasActiveSession ||
                                geo.status == GeofenceStatus.inside)
                            ? AppColors.success
                            : AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        (hasActiveSession ||
                                geo.status == GeofenceStatus.inside)
                            ? 'Unlocked'
                            : 'Locked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color:
                              (hasActiveSession ||
                                  geo.status == GeofenceStatus.inside)
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Active session banner ──────────────────────────────────────────────────

  Widget _buildActiveSessionBanner(
    BuildContext context,
    TeacherDashboardState state,
  ) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed:
                    attState.status == TeacherAttendanceLoadStatus.loading
                    ? null
                    : () => ctx.read<TeacherAttendanceCubit>().endSession(),
                child: const Text(
                  'End',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow(BuildContext context, TeacherDashboardState state) {
    final subjects = state.teacher?.subjects ?? [];
    final uniqueBatches = subjects
        .map((s) => s.batchId)
        .toSet()
        .where((id) => id != null)
        .length;
    final pendingAtt = state.stats.todayClassCount > 0 ? 1 : 0;

    return Row(
      children: [
        _buildStatCard(
          context,
          icon: LucideIcons.users,
          label: 'Batches',
          value: '$uniqueBatches',
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          context,
          icon: LucideIcons.bookOpen,
          label: 'Subjects',
          value: '${subjects.length}',
          color: AppColors.accent,
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          context,
          icon: LucideIcons.clock,
          label: 'Pending',
          value: '$pendingAtt',
          color: pendingAtt > 0 ? AppColors.error : AppColors.success,
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
      child: NeuBox(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        borderRadius: 20,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Assigned classes carousel ──────────────────────────────────────────────

  Widget _buildAssignedClassesCarousel(
    BuildContext context,
    TeacherDashboardState state,
  ) {
    final subjects = state.teacher?.subjects ?? [];
    final courses = state.teacher?.courses ?? [];
    final items = [...courses, ...subjects];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Assigned Classes & Courses'),
        const SizedBox(height: 10),
        SizedBox(
          height: 125,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            clipBehavior: Clip.none,
            itemBuilder: (ctx, index) {
              final item = items[index];
              final isCourse = item is TeacherCourseAssignment;

              String title;
              String subtitle;
              String badge;

              if (isCourse) {
                title = item.courseName;
                subtitle = 'Course Level Access';
                badge = 'COURSE';
              } else {
                final s = item as TeacherSubjectAssignment;
                title = s.subjectName;
                subtitle = s.batchName ?? 'All Students';
                badge = s.courseName ?? 'Subject';
              }

              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    if (isCourse) {
                      final c = item;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentAttendanceScreen(
                            subjectId: '',
                            subjectName: c.courseName,
                            batchId: '',
                            batchName: 'All Students in Course',
                            courseId: c.courseId,
                            campusId: state.teacher?.campusId,
                          ),
                        ),
                      );
                    } else {
                      final s = item as TeacherSubjectAssignment;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StudentAttendanceScreen(
                            subjectId: s.subjectId,
                            subjectName: s.subjectName,
                            batchId: s.batchId ?? '',
                            batchName: s.batchName,
                            courseId: s.courseId,
                            campusId: state.teacher?.campusId,
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: index % 2 == 0
                            ? [const Color(0xFF4F46E5), const Color(0xFF6366F1)]
                            : [
                                const Color(0xFF0F172A),
                                const Color(0xFF1E293B),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(
                              LucideIcons.arrowUpRight,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────────

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
              label: 'Check In',
              color: AppColors.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TeacherAttendanceScreen(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildActionButton(
              context,
              icon: LucideIcons.users,
              label: 'Students',
              color: AppColors.info,
              onTap: () => _openStudentAttendance(context, state),
            ),
            const SizedBox(width: 10),
            _buildActionButton(
              context,
              icon: LucideIcons.clipboardList,
              label: 'Marks',
              color: AppColors.accent,
              onTap: () => _openMarksEntry(context, state),
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
        child: NeuBox(
          padding: const EdgeInsets.symmetric(vertical: 14),
          borderRadius: 20,
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Exam tile ──────────────────────────────────────────────────────────────

  Widget _buildExamTile(BuildContext context, dynamic exam) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: NeuBox(
        padding: const EdgeInsets.all(12),
        borderRadius: 20,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.fileCheck,
                color: AppColors.accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exam.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${exam.subjectName}${exam.batchName != null ? " · ${exam.batchName}" : ""}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (exam.examDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('d MMM').format(exam.examDate!),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Attendance summary card ────────────────────────────────────────────────

  Widget _buildAttendanceSummaryCard(
    BuildContext context,
    TeacherDashboardState state,
  ) {
    final pct = state.stats.attendancePercentage;
    final presentPct = pct.clamp(0.0, 100.0);
    final absentPct = (100.0 - presentPct).clamp(0.0, 100.0);

    return NeuBox(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Today's Attendance Summary"),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _dotRow(
                      'Present: ${presentPct.toInt()}%',
                      AppColors.success,
                    ),
                    const SizedBox(height: 10),
                    _dotRow('Absent: ${absentPct.toInt()}%', AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'Aggregated today across all subjects',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: presentPct / 100,
                      backgroundColor: AppColors.success.withValues(
                        alpha: 0.08,
                      ),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.success,
                      ),
                      strokeWidth: 7,
                    ),
                    const Icon(
                      LucideIcons.smile,
                      color: AppColors.success,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dotRow(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  void _openStudentAttendance(
    BuildContext context,
    TeacherDashboardState state,
  ) {
    final subjects = state.teacher?.subjects ?? [];
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No subjects assigned.')));
      return;
    }
    if (subjects.length == 1) {
      final s = subjects.first;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentAttendanceScreen(
            subjectId: s.subjectId,
            subjectName: s.subjectName,
            batchId: s.batchId ?? '',
            batchName: s.batchName,
            courseId: s.courseId,
          ),
        ),
      );
      return;
    }
    _showSubjectPicker(context, subjects, (s) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentAttendanceScreen(
            subjectId: s.subjectId,
            subjectName: s.subjectName,
            batchId: s.batchId ?? '',
            batchName: s.batchName,
            courseId: s.courseId,
          ),
        ),
      );
    });
  }

  void _openMarksEntry(BuildContext context, TeacherDashboardState state) {
    final subjects = state.teacher?.subjects ?? [];
    if (subjects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No subjects assigned.')));
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MarksEntryScreen()));
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
          ...subjects.map(
            (s) => ListTile(
              leading: const Icon(
                LucideIcons.bookOpen,
                color: AppColors.primary,
              ),
              title: Text(
                s.subjectName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: s.batchName != null ? Text(s.batchName!) : null,
              onTap: () {
                Navigator.pop(ctx);
                onSelect(s);
              },
            ),
          ),
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
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ${diff.inMinutes % 60}m ago';
  }
}
