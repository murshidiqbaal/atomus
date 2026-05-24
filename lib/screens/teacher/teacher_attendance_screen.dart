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

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  Timer? _geofencePoll;

  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  String? _filterCourseId;
  String? _filterSubjectId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;

    final cubit = context.read<TeacherAttendanceCubit>();
    await cubit.loadTodaySession(teacher.id);
    await cubit.loadHistory(teacher.id, month: _selectedMonth);
    if (!mounted) return;

    _verifyLocation(silent: true);
    _startGeofencePolling();
  }

  void _startGeofencePolling() {
    _geofencePoll?.cancel();
    _geofencePoll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _verifyLocation(silent: true);
    });
  }

  @override
  void dispose() {
    _geofencePoll?.cancel();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _reloadHistory();
  }

  void _nextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    final now = DateTime.now();
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    setState(() => _selectedMonth = next);
    _reloadHistory();
  }

  void _reloadHistory() {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;
    context
        .read<TeacherAttendanceCubit>()
        .loadHistory(teacher.id, month: _selectedMonth);
  }

  // ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'My Attendance',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          centerTitle: true,
          actions: [
            BlocBuilder<GeofenceCubit, GeofenceState>(
              builder: (ctx, geo) {
                return IconButton(
                  tooltip: 'Re-verify location',
                  icon: Icon(
                    LucideIcons.refreshCw,
                    size: 18,
                    color: geo.isChecking
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                  onPressed: geo.isChecking
                      ? null
                      : () => _verifyLocation(silent: false),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<TeacherAttendanceCubit, TeacherAttendanceState>(
          listener: _attendanceListener,
          builder: (ctx, attState) {
            return BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
              builder: (ctx2, dashState) {
                final teacher = dashState.teacher;
                return RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.primary,
                  onRefresh: () async {
                    if (teacher == null) return;
                    final cubit = ctx.read<TeacherAttendanceCubit>();
                    await cubit.loadTodaySession(teacher.id);
                    await cubit.loadHistory(teacher.id,
                        month: _selectedMonth);
                    _verifyLocation(silent: true);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    child: Column(
                      children: [
                        _buildGeofenceBanner(teacher),
                        const SizedBox(height: 12),
                        _buildPunchCard(ctx, attState, teacher),
                        const SizedBox(height: 18),
                        _buildMonthSelector(),
                        const SizedBox(height: 16),
                        _buildSummary(attState),
                        const SizedBox(height: 16),
                        _buildCalendar(attState),
                        const SizedBox(height: 20),
                        _buildSelectedDayCard(attState),
                        const SizedBox(height: 24),
                      ],
                    ),
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
      ctx.read<TeacherDashboardCubit>().load();
    }
    if (state.status == TeacherAttendanceLoadStatus.failure) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(state.errorMessage ?? 'An error occurred'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ----------------------------------------------------------------

  Widget _buildGeofenceBanner(dynamic teacher) {
    final hasGeo = teacher != null && teacher.hasCampusCoordinates;
    if (!hasGeo) {
      return _bannerCard(
        color: AppColors.info,
        icon: LucideIcons.info,
        title: 'No campus location set',
        subtitle: 'Location validation is not required for your account.',
      );
    }

    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (ctx, geo) {
        late Color color;
        late IconData icon;
        late String title;
        late String subtitle;

        switch (geo.status) {
          case GeofenceStatus.unknown:
            color = AppColors.textSecondary;
            icon = LucideIcons.mapPin;
            title = 'Verifying location...';
            subtitle = 'Hang on while we check your campus position.';
            break;
          case GeofenceStatus.checking:
            color = AppColors.info;
            icon = LucideIcons.loader;
            title = 'Checking location...';
            subtitle = 'Fetching your GPS position.';
            break;
          case GeofenceStatus.inside:
            color = AppColors.success;
            icon = LucideIcons.shieldCheck;
            title = 'Inside campus';
            subtitle =
                '${geo.distanceMeters.toInt()}m from campus center - you can punch in.';
            break;
          case GeofenceStatus.outside:
            color = AppColors.error;
            icon = LucideIcons.shieldAlert;
            title = 'Outside campus';
            subtitle =
                'You are ${geo.distanceMeters.toInt()}m away. Move closer to enable punch-in.';
            break;
          case GeofenceStatus.permissionDenied:
            color = AppColors.error;
            icon = LucideIcons.shieldOff;
            title = 'Permission denied';
            subtitle = 'Allow location access in device settings.';
            break;
          case GeofenceStatus.serviceDisabled:
            color = AppColors.error;
            icon = LucideIcons.wifiOff;
            title = 'GPS disabled';
            subtitle = 'Enable location services and try again.';
            break;
          case GeofenceStatus.error:
            color = AppColors.error;
            icon = LucideIcons.alertCircle;
            title = 'Location error';
            subtitle = geo.errorMessage ?? 'Could not determine your location.';
            break;
        }

        return _bannerCard(
          color: color,
          icon: icon,
          title: title,
          subtitle: subtitle,
          isLoading: geo.status == GeofenceStatus.checking,
        );
      },
    );
  }

  Widget _bannerCard({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    bool isLoading = false,
  }) {
    return CustomCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                : Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------

  Widget _buildPunchCard(
    BuildContext ctx,
    TeacherAttendanceState attState,
    dynamic teacher,
  ) {
    final isLoading = attState.status == TeacherAttendanceLoadStatus.loading;
    final now = DateTime.now();

    // Once today's attendance is completed, lock the UI to the completed
    // card. A stale "Active" row coming back from the server on refresh or
    // a geofence poll must not re-expose the STOP button or alter the
    // recorded punch-out time.
    final completed = attState.completedSession;
    if (completed != null && _isSameDay(completed.attendanceDate, now)) {
      return _buildCompletedPunchCard(completed);
    }

    // Also guard against an active row dated to a previous day that hasn't
    // been cleared on the server. Only treat it as active if it's for today.
    final active = attState.activeSession;
    if (attState.hasActiveSession &&
        active != null &&
        _isSameDay(active.attendanceDate, now)) {
      // Already punched out (endTime set on the row): show the completed
      // card and never expose the STOP button again.
      if (active.endTime != null) {
        return _buildCompletedPunchCard(active);
      }
      return _buildActivePunchCard(ctx, active, isLoading);
    }

    return _buildIdlePunchCard(ctx, teacher, isLoading);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildIdlePunchCard(
      BuildContext ctx, dynamic teacher, bool isLoading) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (geoCtx, geo) {
        final noCampus = teacher == null || !teacher.hasCampusCoordinates;
        final insideCampus = noCampus || geo.status == GeofenceStatus.inside;
        final hasFilters =
            _filterCourseId != null && _filterSubjectId != null;
        final canPunch = insideCampus && hasFilters;

        String? disabledHint;
        String label = 'PUNCH IN';
        IconData icon = LucideIcons.play;
        Color color = AppColors.success;
        if (!insideCampus) {
          label = 'OUTSIDE CAMPUS';
          icon = LucideIcons.lock;
          color = AppColors.textSecondary;
          disabledHint = 'You must be inside the campus radius to punch in.';
        } else if (!hasFilters) {
          label = 'SELECT COURSE & SUBJECT';
          icon = LucideIcons.filter;
          color = AppColors.textSecondary;
          disabledHint = 'Pick a course and a subject before punching in.';
        }

        return CustomCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _statusPill(
                  label: 'NOT PUNCHED IN',
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Pick today's class and tap PUNCH IN.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _buildFilters(teacher),
              const SizedBox(height: 16),
              _buildBigPunchButton(
                label: label,
                icon: icon,
                color: color,
                isLoading: isLoading,
                disabledHint: disabledHint,
                onPressed: (canPunch && !isLoading)
                    ? () => _startSession(ctx, teacher, geo)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilters(dynamic teacher) {
    final List assignments =
        (teacher?.subjects as List?) ?? const <dynamic>[];
    if (assignments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.inbox,
                size: 16, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No courses or subjects assigned to your account.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Build distinct course list from teacher assignments.
    final Map<String, String> courses = {};
    for (final a in assignments) {
      final cid = a.courseId as String?;
      if (cid == null) continue;
      courses[cid] = (a.courseName as String?) ?? 'Course';
    }

    // Subjects scoped by the currently selected course (if any).
    final List subjectItems = _filterCourseId == null
        ? assignments
        : assignments.where((a) => a.courseId == _filterCourseId).toList();

    // Self-heal stale selections (e.g., course changed -> subject mismatch).
    if (_filterSubjectId != null &&
        !subjectItems.any((a) => a.subjectId == _filterSubjectId)) {
      _filterSubjectId = null;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _filterDropdown<String>(
            label: 'COURSE',
            value: _filterCourseId,
            hint: 'Select course',
            items: courses.entries
                .map((e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(e.value,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ))
                .toList(),
            onChanged: (val) {
              setState(() {
                _filterCourseId = val;
                _filterSubjectId = null;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterDropdown<String>(
            label: 'SUBJECT',
            value: _filterSubjectId,
            hint: _filterCourseId == null
                ? 'Pick course first'
                : 'Select subject',
            items: subjectItems
                .map<DropdownMenuItem<String>>(
                  (a) => DropdownMenuItem<String>(
                    value: a.subjectId as String,
                    child: Text(
                      '${a.subjectName}${a.batchName != null ? " | ${a.batchName}" : ""}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(),
            onChanged: subjectItems.isEmpty
                ? null
                : (val) => setState(() => _filterSubjectId = val),
          ),
        ),
      ],
    );
  }

  Widget _filterDropdown<T>({
    required String label,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(
                hint,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivePunchCard(
    BuildContext ctx,
    TeacherAttendanceModel session,
    bool isLoading,
  ) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (geoCtx, geo) {
        final teacher = context.read<TeacherDashboardCubit>().state.teacher;
        final noCampus = teacher == null || !teacher.hasCampusCoordinates;
        final canPunchOut = noCampus || geo.status == GeofenceStatus.inside;

        return CustomCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            children: [
              _statusPill(
                label: 'PUNCHED IN',
                color: AppColors.success,
                showDot: true,
              ),
              const SizedBox(height: 16),
              Text(
                'Punched in at ${session.startTime != null ? DateFormat('hh:mm a').format(session.startTime!) : '--'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 18),
              _buildBigPunchButton(
                label: canPunchOut ? 'PUNCH OUT' : 'OUTSIDE CAMPUS',
                icon: canPunchOut ? LucideIcons.square : LucideIcons.lock,
                color: canPunchOut
                    ? AppColors.error
                    : AppColors.textSecondary,
                isLoading: isLoading,
                disabledHint: canPunchOut
                    ? null
                    : 'You must be inside the campus radius to punch out.',
                onPressed: (canPunchOut && !isLoading)
                    ? () => _confirmEndSession(ctx)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedPunchCard(TeacherAttendanceModel session) {
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _statusPill(
            label: 'ATTENDANCE COMPLETED',
            color: AppColors.success,
            icon: LucideIcons.checkCircle,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.logIn,
                  label: 'Punch-In',
                  value: session.startTime != null
                      ? DateFormat('hh:mm a').format(session.startTime!)
                      : '--',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.logOut,
                  label: 'Punch-Out',
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
          const SizedBox(height: 14),
          const Text(
            "You've already marked attendance for today.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _statusPill({
    required String label,
    required Color color,
    bool showDot = false,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (icon != null) Icon(icon, size: 14, color: color),
          if (showDot || icon != null) const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 10,
              color: color,
              letterSpacing: 1.5,
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildBigPunchButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    required VoidCallback? onPressed,
    String? disabledHint,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : Icon(icon, size: 22, color: Colors.white),
            label: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.4,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              disabledBackgroundColor: color.withValues(alpha: 0.55),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onPressed,
          ),
        ),
        if (disabledHint != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertTriangle,
                  size: 12, color: AppColors.error),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  disabledHint,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------------

  Widget _buildMonthSelector() {
    final now = DateTime.now();
    final canGoNext = !(_selectedMonth.year == now.year &&
        _selectedMonth.month == now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'MONTH',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        CustomCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.primary, size: 20),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy')
                        .format(_selectedMonth)
                        .toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.0,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: canGoNext ? _nextMonth : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: canGoNext
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.4),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------

  Widget _buildSummary(TeacherAttendanceState state) {
    int present = 0;
    int absent = 0;
    int totalMinutes = 0;
    final monthRecords = _monthRecords(state);
    for (final r in monthRecords) {
      if (r.isCompleted) {
        present++;
        totalMinutes += r.totalDurationMinutes ?? 0;
      } else {
        absent++;
      }
    }
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final hoursLabel = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Row(
      children: [
        _buildSummaryCard('PRESENT', '$present', AppColors.success),
        const SizedBox(width: 10),
        _buildSummaryCard('MISSED', '$absent', AppColors.error),
        const SizedBox(width: 10),
        _buildSummaryCard('HOURS', hoursLabel, AppColors.primary),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: CustomCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------

  List<TeacherAttendanceModel> _monthRecords(TeacherAttendanceState state) {
    return state.history.where((r) {
      return r.attendanceDate.year == _selectedMonth.year &&
          r.attendanceDate.month == _selectedMonth.month;
    }).toList();
  }

  Widget _buildCalendar(TeacherAttendanceState state) {
    final Map<int, TeacherAttendanceModel> recordMap = {};
    for (final r in _monthRecords(state)) {
      recordMap[r.attendanceDate.day] = r;
    }
    // Also include today's active session in calendar
    final active = state.activeSession;
    if (active != null &&
        active.attendanceDate.year == _selectedMonth.year &&
        active.attendanceDate.month == _selectedMonth.month) {
      recordMap[active.attendanceDate.day] = active;
    }
    final completedToday = state.completedSession;
    if (completedToday != null &&
        completedToday.attendanceDate.year == _selectedMonth.year &&
        completedToday.attendanceDate.month == _selectedMonth.month) {
      recordMap[completedToday.attendanceDate.day] = completedToday;
    }

    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final startOffset =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday - 1;
    final today = DateTime.now();

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 1,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox();
              final day = index - startOffset + 1;
              final record = recordMap[day];
              final date =
                  DateTime(_selectedMonth.year, _selectedMonth.month, day);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isFuture = date
                  .isAfter(DateTime(today.year, today.month, today.day));

              Color? bgColor;
              if (!isFuture && record != null) {
                if (record.isCompleted) {
                  bgColor = AppColors.success;
                } else if (record.isActive) {
                  bgColor = AppColors.warning;
                } else {
                  bgColor = AppColors.error;
                }
              }

              final isSelected = _selectedDate.year == date.year &&
                  _selectedDate.month == date.month &&
                  _selectedDate.day == date.day;

              return GestureDetector(
                onTap: () {
                  if (!isFuture) setState(() => _selectedDate = date);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: bgColor != null
                        ? bgColor.withValues(alpha: isSelected ? 0.8 : 1.0)
                        : isSelected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : (isToday
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.transparent),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: bgColor ?? AppColors.primary,
                            width: 2.0,
                          )
                        : isToday && bgColor == null
                            ? Border.all(
                                color: AppColors.primary, width: 1.5)
                            : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (isToday ||
                                bgColor != null ||
                                isSelected)
                            ? FontWeight.w900
                            : FontWeight.w500,
                        color: isFuture
                            ? AppColors.textSecondary.withValues(alpha: 0.3)
                            : (bgColor != null
                                ? Colors.white
                                : (isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend('Present', AppColors.success),
              const SizedBox(width: 18),
              _buildLegend('Active', AppColors.warning),
              const SizedBox(width: 18),
              _buildLegend('Missed', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------

  Widget _buildSelectedDayCard(TeacherAttendanceState state) {
    TeacherAttendanceModel? record;
    for (final r in _monthRecords(state)) {
      if (r.attendanceDate.day == _selectedDate.day &&
          r.attendanceDate.month == _selectedDate.month &&
          r.attendanceDate.year == _selectedDate.year) {
        record = r;
        break;
      }
    }
    record ??= _matchesDate(state.activeSession, _selectedDate);
    record ??= _matchesDate(state.completedSession, _selectedDate);

    Color color;
    IconData icon;
    String statusLabel;
    if (record == null) {
      color = AppColors.textSecondary;
      icon = LucideIcons.helpCircle;
      statusLabel = 'NOT MARKED';
    } else if (record.isCompleted) {
      color = AppColors.success;
      icon = LucideIcons.checkCircle;
      statusLabel = 'PRESENT';
    } else if (record.isActive) {
      color = AppColors.warning;
      icon = LucideIcons.clock;
      statusLabel = 'IN PROGRESS';
    } else {
      color = AppColors.error;
      icon = LucideIcons.xCircle;
      statusLabel = 'MISSED';
    }

    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'DAILY ATTENDANCE - ${DateFormat('MMM d, yyyy').format(_selectedDate).toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: 1.5,
                    color: color,
                  ),
                ),
                if (record != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatChip(
                          icon: LucideIcons.logIn,
                          label: 'Punch-In',
                          value: record.startTime != null
                              ? DateFormat('hh:mm a')
                                  .format(record.startTime!)
                              : '--',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatChip(
                          icon: LucideIcons.logOut,
                          label: 'Punch-Out',
                          value: record.endTime != null
                              ? DateFormat('hh:mm a')
                                  .format(record.endTime!)
                              : '--',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatChip(
                          icon: LucideIcons.timer,
                          label: 'Duration',
                          value: record.durationLabel,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  const Text(
                    'No attendance marked for this day.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  TeacherAttendanceModel? _matchesDate(
      TeacherAttendanceModel? r, DateTime date) {
    if (r == null) return null;
    if (r.attendanceDate.year == date.year &&
        r.attendanceDate.month == date.month &&
        r.attendanceDate.day == date.day) {
      return r;
    }
    return null;
  }

  // ----------------------------------------------------------------

  Future<void> _verifyLocation({required bool silent}) async {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null || !teacher.hasCampusCoordinates) return;
    await context.read<GeofenceCubit>().checkGeofence(
          campusLatitude: teacher.campusLatitude as double,
          campusLongitude: teacher.campusLongitude as double,
          radiusMeters: teacher.geofenceRadiusMeters as int,
        );
    if (!silent && mounted) {
      final geo = context.read<GeofenceCubit>().state;
      if (geo.status == GeofenceStatus.inside) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Inside campus (${geo.distanceMeters.toInt()}m away)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _startSession(
      BuildContext ctx, dynamic teacher, GeofenceState geo) async {
    if (teacher == null) return;
    if (_filterCourseId == null || _filterSubjectId == null) return;

    // Resolve batch from the chosen subject assignment.
    String? batchId;
    final assignments = (teacher.subjects as List?) ?? const <dynamic>[];
    for (final a in assignments) {
      if (a.subjectId == _filterSubjectId &&
          a.courseId == _filterCourseId) {
        batchId = a.batchId as String?;
        break;
      }
    }

    await ctx.read<TeacherAttendanceCubit>().startSession(
          teacherId: teacher.id as String,
          campusId: teacher.campusId as String?,
          subjectId: _filterSubjectId,
          courseId: _filterCourseId,
          batchId: batchId,
          latitude: geo.position?.latitude,
          longitude: geo.position?.longitude,
        );
  }

  void _confirmEndSession(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Punch out for today?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: const Text(
          "This will record your punch-out time and mark today's attendance as completed. You can only mark attendance once per day.",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              ctx.read<TeacherAttendanceCubit>().endSession();
            },
            child: const Text('Punch Out'),
          ),
        ],
      ),
    );
  }
}
