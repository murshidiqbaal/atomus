import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/geofence/geofence_cubit.dart';
import '../../blocs/geofence/geofence_state.dart';
import '../../blocs/teacher_attendance/teacher_attendance_cubit.dart';
import '../../blocs/teacher_attendance/teacher_attendance_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../models/teacher_attendance_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import 'student_attendance_screen.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  Timer? _sessionTimer;
  Duration _elapsed = Duration.zero;

  String? _selectedSubjectId;
  String? _selectedCourseId;
  String? _selectedBatchId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;
    await context.read<TeacherAttendanceCubit>().loadTodaySession(teacher.id);
    if (mounted) _tryStartTimer();
  }

  void _tryStartTimer() {
    final session = context.read<TeacherAttendanceCubit>().state.activeSession;
    if (session?.startTime != null) {
      _elapsed = DateTime.now().difference(session!.startTime!);
      _sessionTimer?.cancel();
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    }
  }

  void _stopTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _elapsed = Duration.zero;
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('My Attendance',
              style: TextStyle(fontWeight: FontWeight.w800)),
          centerTitle: true,
        ),
        body: BlocConsumer<TeacherAttendanceCubit, TeacherAttendanceState>(
          listener: _attendanceListener,
          builder: (ctx, attState) {
            return BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
              builder: (ctx2, dashState) {
                return RefreshIndicator(
                  onRefresh: () async {
                    final t = dashState.teacher;
                    if (t != null) {
                      await ctx.read<TeacherAttendanceCubit>()
                          .loadTodaySession(t.id);
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      _buildDateHeader(),
                      const SizedBox(height: 12),
                      _buildBody(ctx, attState, dashState),
                      const SizedBox(height: 20),
                      _buildHistorySection(attState),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _attendanceListener(BuildContext ctx, TeacherAttendanceState state) {
    if (state.status == TeacherAttendanceLoadStatus.success) {
      if (state.hasActiveSession) {
        _tryStartTimer();
      } else {
        _stopTimer();
      }
    }
    if (state.status == TeacherAttendanceLoadStatus.failure) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(state.errorMessage ?? 'An error occurred'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // ── Date header ────────────────────────────────────────────────────────────

  Widget _buildDateHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.calendar,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Main body dispatcher ───────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext ctx,
    TeacherAttendanceState attState,
    TeacherDashboardState dashState,
  ) {
    // Phase 1: Active class session
    if (attState.hasActiveSession) {
      return _buildActiveSessionCard(
          ctx, attState.activeSession!, attState.status);
    }

    // Phase 2: Class completed today
    if (attState.completedSession != null) {
      return Column(
        children: [
          _buildCompletedCard(attState.completedSession!),
          const SizedBox(height: 12),
          _buildStartNewSessionCard(ctx, attState, dashState.teacher),
        ],
      );
    }

    // Phase 3: No session yet — verify location + start class
    return _buildCheckInCard(ctx, attState, dashState.teacher);
  }

  // ── Phase 3: Check-in card ─────────────────────────────────────────────────

  Widget _buildCheckInCard(
    BuildContext ctx,
    TeacherAttendanceState attState,
    dynamic teacher,
  ) {
    final isLoading = attState.status == TeacherAttendanceLoadStatus.loading;
    return Column(
      children: [
        _buildLocationCard(teacher),
        const SizedBox(height: 12),
        _buildSubjectAndStartCard(ctx, attState, teacher, isLoading),
      ],
    );
  }

  // ── Location verification card ─────────────────────────────────────────────

  Widget _buildLocationCard(dynamic teacher) {
    if (teacher == null || !teacher.hasCampusCoordinates) {
      return _buildNoLocationConfigCard();
    }
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (ctx, geo) {
        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  const Icon(LucideIcons.mapPin,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  const Text('CAMPUS VERIFICATION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      )),
                ],
              ),
              const SizedBox(height: 12),
              // Status indicator
              _buildGeofenceStatus(geo),
              const SizedBox(height: 14),
              // Action button
              SizedBox(
                width: double.infinity,
                child: _buildVerifyButton(ctx, geo, teacher),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoLocationConfigCard() {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(LucideIcons.info, color: AppColors.info, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Campus Location Set',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                SizedBox(height: 2),
                Text('Location validation is not required.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceStatus(GeofenceState geo) {
    late Color color;
    late IconData icon;
    late String title;
    late String subtitle;

    switch (geo.status) {
      case GeofenceStatus.unknown:
        color    = AppColors.textSecondary;
        icon     = LucideIcons.mapPin;
        title    = 'Location Not Verified';
        subtitle = 'Tap "Verify Location" to check if you are on campus.';
        break;
      case GeofenceStatus.checking:
        color    = AppColors.info;
        icon     = LucideIcons.loader;
        title    = 'Checking Location…';
        subtitle = 'Fetching your GPS position.';
        break;
      case GeofenceStatus.inside:
        color    = AppColors.success;
        icon     = LucideIcons.checkCircle;
        title    = 'Inside Campus';
        subtitle = 'Distance: ${geo.distanceMeters.toInt()}m — You\'re good to go!';
        break;
      case GeofenceStatus.outside:
        color    = AppColors.error;
        icon     = LucideIcons.xCircle;
        title    = 'Outside Campus';
        subtitle = 'You are ${geo.distanceMeters.toInt()}m away. Move closer to campus.';
        break;
      case GeofenceStatus.permissionDenied:
        color    = AppColors.error;
        icon     = LucideIcons.shieldOff;
        title    = 'Permission Denied';
        subtitle = 'Please allow location access in device settings.';
        break;
      case GeofenceStatus.serviceDisabled:
        color    = AppColors.error;
        icon     = LucideIcons.wifi;
        title    = 'GPS Disabled';
        subtitle = 'Please enable location services and try again.';
        break;
      case GeofenceStatus.error:
        color    = AppColors.error;
        icon     = LucideIcons.alertCircle;
        title    = 'Location Error';
        subtitle = geo.errorMessage ?? 'Could not determine your location.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          geo.status == GeofenceStatus.checking
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              : Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyButton(
    BuildContext ctx,
    GeofenceState geo,
    dynamic teacher,
  ) {
    final isChecking = geo.status == GeofenceStatus.checking;
    final isVerified = geo.status == GeofenceStatus.inside;

    if (isVerified) {
      return OutlinedButton.icon(
        icon: const Icon(LucideIcons.refreshCw, size: 16),
        label: const Text('Re-verify Location'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => _verifyLocation(ctx, teacher),
      );
    }

    return ElevatedButton.icon(
      icon: isChecking
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(LucideIcons.locateFixed, size: 18),
      label: Text(isChecking ? 'Locating…' : 'Verify Location'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: isChecking ? null : () => _verifyLocation(ctx, teacher),
    );
  }

  // ── Subject selector + Start Class card ───────────────────────────────────

  Widget _buildSubjectAndStartCard(
    BuildContext ctx,
    TeacherAttendanceState attState,
    dynamic teacher,
    bool isLoading,
  ) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.bookOpen,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text('START CLASS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  )),
            ],
          ),
          const SizedBox(height: 14),
          _buildSubjectSelector(teacher),
          const SizedBox(height: 16),
          BlocBuilder<GeofenceCubit, GeofenceState>(
            builder: (geoCtx, geo) {
              final noCampus = teacher?.campusLatitude == null;
              final canStart = noCampus || geo.status == GeofenceStatus.inside;
              return Column(
                children: [
                  if (!canStart && geo.status != GeofenceStatus.unknown)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(LucideIcons.alertTriangle,
                              size: 14, color: AppColors.error),
                          const SizedBox(width: 6),
                          const Text(
                            'Verify location first to enable check-in.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.playCircle, size: 18),
                      label: Text(
                        canStart
                            ? 'Start Class'
                            : 'Verify Location First',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canStart
                            ? AppColors.success
                            : AppColors.textSecondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (canStart && !isLoading)
                          ? () => _startSession(ctx, teacher, geo)
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector(dynamic teacher) {
    final subjects = (teacher?.subjects as List?) ?? [];
    if (subjects.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.inbox, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Text('No subjects assigned.',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    if (_selectedSubjectId == null) {
      final s = subjects.first;
      _selectedSubjectId = s.subjectId as String?;
      _selectedCourseId  = s.courseId  as String?;
      _selectedBatchId   = s.batchId   as String?;
    }
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Subject / Class',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSubjectId,
          isExpanded: true,
          items: subjects.map<DropdownMenuItem<String>>((s) {
            return DropdownMenuItem<String>(
              value: s.subjectId as String,
              child: Text(
                '${s.subjectName}${s.batchName != null ? " · ${s.batchName}" : ""}',
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            final s = subjects.firstWhere((x) => x.subjectId == val);
            setState(() {
              _selectedSubjectId = s.subjectId as String?;
              _selectedCourseId  = s.courseId  as String?;
              _selectedBatchId   = s.batchId   as String?;
            });
          },
        ),
      ),
    );
  }

  // ── Phase 1: Active session card ──────────────────────────────────────────

  Widget _buildActiveSessionCard(
    BuildContext ctx,
    TeacherAttendanceModel session,
    TeacherAttendanceLoadStatus loadStatus,
  ) {
    final isLoading = loadStatus == TeacherAttendanceLoadStatus.loading;
    final hours   = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Live badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('CLASS IN SESSION',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AppColors.success,
                      letterSpacing: 1.2,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Subject name
          Text(
            session.subjectName ?? 'Active Class',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Started at ${session.startTime != null ? DateFormat('hh:mm a').format(session.startTime!) : '--'}',
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timerSegment(hours.toString().padLeft(2, '0'), 'HRS'),
              _timerSeparator(),
              _timerSegment(minutes.toString().padLeft(2, '0'), 'MIN'),
              _timerSeparator(),
              _timerSegment(seconds.toString().padLeft(2, '0'), 'SEC'),
            ],
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.users, size: 16),
                  label: const Text('Take Attendance'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _goToStudentAttendance(ctx, session),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LucideIcons.stopCircle, size: 16),
                  label: const Text('End Class'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isLoading
                      ? null
                      : () => _confirmEndSession(ctx),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Phase 2: Completed session summary card ────────────────────────────────

  Widget _buildCompletedCard(TeacherAttendanceModel session) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Completion badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.checkCircle,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 6),
                const Text('CLASS COMPLETED',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AppColors.success,
                      letterSpacing: 1.2,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            session.subjectName ?? 'Class',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.clock,
                  label: 'Check-In',
                  value: session.startTime != null
                      ? DateFormat('hh:mm a').format(session.startTime!)
                      : '--',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.logOut,
                  label: 'Check-Out',
                  value: session.endTime != null
                      ? DateFormat('hh:mm a').format(session.endTime!)
                      : '--',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.timer,
                  label: 'Duration',
                  value: session.durationLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
        ],
      ),
    );
  }

  // ── Start new session card (shown below completed card) ────────────────────

  Widget _buildStartNewSessionCard(
    BuildContext ctx,
    TeacherAttendanceState attState,
    dynamic teacher,
  ) {
    return _buildCheckInCard(ctx, attState, teacher);
  }

  // ── History section ────────────────────────────────────────────────────────

  Widget _buildHistorySection(TeacherAttendanceState state) {
    if (state.history.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('THIS MONTH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            )),
        const SizedBox(height: 10),
        ...state.history.map((r) => _buildHistoryTile(r)),
      ],
    );
  }

  Widget _buildHistoryTile(TeacherAttendanceModel record) {
    final Color color =
        record.isCompleted ? AppColors.success : AppColors.error;
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                record.isCompleted
                    ? LucideIcons.checkCircle
                    : LucideIcons.xCircle,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.subjectName ??
                        DateFormat('EEEE').format(record.attendanceDate),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  Text(
                    DateFormat('d MMM yyyy').format(record.attendanceDate),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    record.status.value,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ),
                if (record.durationLabel != '--')
                  Text(
                    record.durationLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Timer widgets ──────────────────────────────────────────────────────────

  Widget _timerSegment(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
        Text(label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            )),
      ],
    );
  }

  Widget _timerSeparator() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(' : ',
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.accent)),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _verifyLocation(BuildContext ctx, dynamic teacher) async {
    if (teacher == null || !teacher.hasCampusCoordinates) return;
    await ctx.read<GeofenceCubit>().checkGeofence(
          campusLatitude:  teacher.campusLatitude as double,
          campusLongitude: teacher.campusLongitude as double,
          radiusMeters:    teacher.geofenceRadiusMeters as int,
        );
  }

  Future<void> _startSession(
      BuildContext ctx, dynamic teacher, GeofenceState geo) async {
    if (teacher == null) return;
    await ctx.read<TeacherAttendanceCubit>().startSession(
          teacherId: teacher.id as String,
          campusId:  teacher.campusId as String?,
          subjectId: _selectedSubjectId,
          courseId:  _selectedCourseId,
          batchId:   _selectedBatchId,
          latitude:  geo.position?.latitude,
          longitude: geo.position?.longitude,
        );
  }

  void _confirmEndSession(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('End Class?'),
        content: const Text(
            'This will mark your attendance as completed for today.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ctx.read<TeacherAttendanceCubit>().endSession();
            },
            child: const Text('End Class',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _goToStudentAttendance(
      BuildContext ctx, TeacherAttendanceModel session) {
    if (session.subjectId == null || session.batchId == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('No batch assigned to this session.')),
      );
      return;
    }
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => StudentAttendanceScreen(
        subjectId:   session.subjectId!,
        subjectName: session.subjectName ?? 'Subject',
        batchId:     session.batchId!,
        courseId:    session.courseId,
      ),
    ));
  }
}
