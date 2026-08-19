import 'dart:async';

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
import '../../models/campus_model.dart';
import '../../models/teacher_attendance_model.dart';
import '../../models/teacher_model.dart';
import '../../providers/campus_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/attendance_date_validator.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen>
    with WidgetsBindingObserver {
  Timer? _geofencePoll;
  Timer? _elapsedTimer;

  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  String? _filterCourseId;
  String? _filterSubjectId;
  String? _filterBatchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;

    final cubit = context.read<TeacherAttendanceCubit>();
    await cubit.loadTodayAttendance(teacher.id);
    await cubit.loadHistory(teacher.id, month: _selectedMonth);
    if (!mounted) return;

    _verifyLocation(silent: true);
    _startGeofencePolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final teacher = context.read<TeacherDashboardCubit>().state.teacher;
      if (teacher != null && mounted) {
        context.read<TeacherAttendanceCubit>().loadTodayAttendance(teacher.id);
        _verifyLocation(silent: true);
      }
    }
  }

  void _startGeofencePolling() {
    _geofencePoll?.cancel();
    _geofencePoll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _verifyLocation(silent: true);
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _geofencePoll?.cancel();
    _elapsedTimer?.cancel();
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
    context.read<TeacherAttendanceCubit>().loadHistory(
      teacher.id,
      month: _selectedMonth,
    );
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
            'Teacher Attendance',
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
                final openSession = attState.openSession;

                if (attState.hasOpenSession && openSession != null) {
                  _filterCourseId = openSession.courseId;
                  _filterSubjectId = openSession.subjectId;
                  _filterBatchId = openSession.batchId;
                }

                return RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.primary,
                  onRefresh: () async {
                    if (teacher == null) return;
                    final cubit = ctx.read<TeacherAttendanceCubit>();
                    await cubit.loadTodayAttendance(teacher.id);
                    await cubit.loadHistory(teacher.id, month: _selectedMonth);
                    _verifyLocation(silent: true);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildGeofenceBanner(teacher),
                        const SizedBox(height: 12),
                        _buildPunchCard(ctx, attState, teacher),
                        const SizedBox(height: 18),
                        _buildTodaySessionsSection(attState),
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
      if (state.hasOpenSession) {
        _startElapsedTimer();
      } else {
        _stopElapsedTimer();
      }
    }
    if (state.status == TeacherAttendanceLoadStatus.failure) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage ?? 'An error occurred'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ----------------------------------------------------------------

  Widget _buildGeofenceBanner(dynamic teacher) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (geoCtx, geo) {
        final campusProvider = context.read<CampusProvider>();
        Color color;
        IconData icon;
        String title;
        String subtitle;

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

            Campus? matchedCampus;
            for (final c in campusProvider.assignedCampuses) {
              if (c.id == geo.matchedCampusId) {
                matchedCampus = c;
                break;
              }
            }
            final campusName = matchedCampus?.name ?? 'Campus';

            title = '✓ Inside $campusName';
            subtitle = '';
            break;
          case GeofenceStatus.outside:
            color = AppColors.error;
            icon = LucideIcons.shieldAlert;

            title = '✗ Outside Assigned Campuses';
            subtitle = '';
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
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: color,
                  ),
                ),
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
    if (attState.hasOpenSession && _elapsedTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startElapsedTimer());
    } else if (!attState.hasOpenSession && _elapsedTimer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _stopElapsedTimer());
    }

    final isLoading = attState.status == TeacherAttendanceLoadStatus.loading ||
        attState.isPunchingIn ||
        attState.isPunchingOut;

    final openSession = attState.openSession;

    if (attState.hasOpenSession && openSession != null) {
      return _buildActivePunchCard(ctx, openSession, isLoading);
    }

    return _buildIdlePunchCard(ctx, teacher, isLoading);
  }

  Widget _buildIdlePunchCard(
    BuildContext ctx,
    dynamic teacher,
    bool isLoading,
  ) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (geoCtx, geo) {
        final noCampus = teacher == null || !teacher.hasCampusCoordinates;
        final insideCampus = noCampus || geo.status == GeofenceStatus.inside;
        final hasFilters = _filterCourseId != null && _filterSubjectId != null;
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
          disabledHint = 'Pick a course and subject before punching in.';
        }

        return CustomCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _statusPill(
                  label: 'READY TO PUNCH IN',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Select class details and tap PUNCH IN to start your session.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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

  Widget _buildActivePunchCard(
    BuildContext ctx,
    TeacherAttendanceModel session,
    bool isLoading,
  ) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;

    final elapsedDuration = session.startTime != null
        ? AttendanceDateValidator.getCorrectedLocalTime().difference(
            session.startTime!,
          )
        : Duration.zero;

    final hh = elapsedDuration.inHours.toString().padLeft(2, '0');
    final mm = (elapsedDuration.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (elapsedDuration.inSeconds % 60).toString().padLeft(2, '0');
    final elapsedStr = '$hh:$mm:$ss';

    return CustomCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _statusPill(
              label: 'SESSION IN PROGRESS',
              color: AppColors.warning,
              showDot: true,
            ),
          ),
          const SizedBox(height: 16),
          _buildFilters(teacher, isDisabled: true, activeSession: session),
          const SizedBox(height: 16),

          // Timer display
          Center(
            child: Column(
              children: [
                Text(
                  elapsedStr,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'CURRENT WORK DURATION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: Text(
              'Punched in at ${session.startTime != null ? DateFormat('hh:mm a').format(session.startTime!.toLocal()) : '--'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Punch out button
          _buildBigPunchButton(
            label: 'PUNCH OUT',
            icon: LucideIcons.square,
            color: AppColors.error,
            isLoading: isLoading,
            onPressed: !isLoading ? () => _confirmEndSession(ctx) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySessionsSection(TeacherAttendanceState attState) {
    final todayList = attState.todaySessions;
    int liveSeconds = 0;
    if (attState.hasOpenSession && attState.openSession?.startTime != null) {
      liveSeconds = AttendanceDateValidator.getCorrectedLocalTime()
          .difference(attState.openSession!.startTime!)
          .inSeconds;
    }
    final totalSec = (attState.todayTotalMinutes * 60) + liveSeconds;
    final totalH = totalSec ~/ 3600;
    final totalM = (totalSec % 3600) ~/ 60;
    final totalHoursLabel = totalH > 0 ? '${totalH}h ${totalM}m' : '${totalM}m';

    if (todayList.isEmpty) {
      return CustomCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TODAY'S SESSIONS",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Today Total: $totalHoursLabel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No sessions recorded yet for today.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final latestSession = todayList.last;

    return CustomCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TODAY'S SESSION",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2,
                  color: AppColors.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Today Total: $totalHoursLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Latest / Current Session ──────────────────
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              children: [
                Icon(
                  latestSession.isActive ? LucideIcons.radio : LucideIcons.sparkles,
                  size: 14,
                  color: latestSession.isActive ? AppColors.warning : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  latestSession.isActive ? 'CURRENT ACTIVE SESSION' : 'RECENT SESSION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: latestSession.isActive ? AppColors.warning : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          _buildSessionTile(
            latestSession,
            sessionIndex: todayList.length,
            isLatest: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(
    TeacherAttendanceModel record, {
    required int sessionIndex,
    bool isLatest = false,
  }) {
    final isCompleted = record.isCompleted;
    final color = isCompleted ? AppColors.success : AppColors.warning;
    final statusText = isCompleted ? 'Completed' : 'In Progress';

    return Container(
      padding: EdgeInsets.all(isLatest ? 16 : 12),
      decoration: BoxDecoration(
        color: isLatest
            ? color.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLatest
              ? color.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.15),
          width: isLatest ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Session $sessionIndex',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: isLatest ? 14 : 12,
                  color: AppColors.primary,
                ),
              ),
              if (record.subjectName != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '· ${record.subjectName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${record.startTime != null ? DateFormat('hh:mm a').format(record.startTime!.toLocal()) : '--'} → ${record.endTime != null ? DateFormat('hh:mm a').format(record.endTime!.toLocal()) : 'In Progress'}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isLatest ? 13 : 12,
                ),
              ),
              const Spacer(),
              Text(
                record.durationLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: isLatest ? 13 : 12,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(
    dynamic teacher, {
    bool isDisabled = false,
    TeacherAttendanceModel? activeSession,
  }) {
    final List<dynamic> assignments =
        (teacher?.subjects as List?) ?? const <dynamic>[];
    if (assignments.isEmpty && !isDisabled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.inbox, size: 16, color: AppColors.textSecondary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No courses or subjects assigned to your account.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final Map<String, String> courses = {};
    for (final a in assignments) {
      final cid = a.courseId as String?;
      if (cid == null) continue;
      courses[cid] = (a.courseName as String?) ?? 'Course';
    }

    if (isDisabled && activeSession != null) {
      _filterCourseId = activeSession.courseId;
      _filterSubjectId = activeSession.subjectId;
      _filterBatchId = activeSession.batchId;
      if (_filterCourseId != null && !courses.containsKey(_filterCourseId)) {
        String? cName;
        for (final a in assignments) {
          if (a.courseId == _filterCourseId) {
            cName = a.courseName;
            break;
          }
        }
        courses[_filterCourseId!] = cName ?? 'Course';
      }
    }

    final bool courseStillValid =
        _filterCourseId == null || courses.containsKey(_filterCourseId);
    if (!isDisabled && !courseStillValid) {
      _filterCourseId = null;
      _filterSubjectId = null;
      _filterBatchId = null;
    }

    final List<dynamic> subjectItems = _filterCourseId == null
        ? const []
        : List<dynamic>.from(
            assignments.where((a) => a.courseId == _filterCourseId),
          );

    final Map<String, dynamic> uniqueSubjectMap = {};
    for (final a in subjectItems) {
      final sid = a.subjectId as String?;
      if (sid == null) continue;
      uniqueSubjectMap.putIfAbsent(sid, () => a);
    }
    final List<dynamic> uniqueSubjectItems = uniqueSubjectMap.values.toList();

    bool subjectStillValid = uniqueSubjectItems.any(
      (a) => a.subjectId == _filterSubjectId,
    );

    if (isDisabled && activeSession != null) {
      if (_filterSubjectId != null && !subjectStillValid) {
        uniqueSubjectItems.add(
          TeacherSubjectAssignment(
            id: 'mock_active_assignment',
            courseId: _filterCourseId!,
            subjectId: _filterSubjectId!,
            subjectName: activeSession.subjectName ?? 'Subject',
            batchId: _filterBatchId,
            batchName: activeSession.batchId != null ? 'Active' : null,
          ),
        );
        subjectStillValid = true;
      }
    } else {
      if (_filterSubjectId != null && !subjectStillValid) {
        _filterSubjectId = null;
        _filterBatchId = null;
      }
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
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(
                      e.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: isDisabled
                ? null
                : (val) {
                    setState(() {
                      _filterCourseId = val;
                      _filterSubjectId = null;
                      _filterBatchId = null;
                    });
                  },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _filterDropdown<String>(
            label: 'SUBJECT',
            value: subjectStillValid ? _filterSubjectId : null,
            hint: _filterCourseId == null
                ? 'Pick course first'
                : 'Select subject',
            items: uniqueSubjectItems
                .map<DropdownMenuItem<String>>(
                  (a) => DropdownMenuItem<String>(
                    value: a.subjectId as String,
                    child: Text(
                      a.subjectName as String,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: (isDisabled || uniqueSubjectItems.isEmpty)
                ? null
                : (val) {
                    setState(() {
                      _filterSubjectId = val;
                      _filterBatchId = null;
                      for (final a in assignments) {
                        if (a.subjectId == val &&
                            a.courseId == _filterCourseId) {
                          _filterBatchId = a.batchId as String?;
                          break;
                        }
                      }
                    });
                  },
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
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(
                hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
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
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
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
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: onPressed,
          ),
        ),
        if (disabledHint != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.alertTriangle,
                size: 12,
                color: AppColors.error,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  disabledHint,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
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
    final canGoNext =
        !(_selectedMonth.year == now.year && _selectedMonth.month == now.month);

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
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: _previousMonth,
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat(
                      'MMMM yyyy',
                    ).format(_selectedMonth).toUpperCase(),
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
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
    int presentDays = 0;
    int totalMinutes = 0;
    final monthRecords = _monthRecords(state);
    final Set<String> daysSet = {};

    for (final r in monthRecords) {
      final dStr = DateFormat('yyyy-MM-dd').format(r.attendanceDate);
      if (r.isCompleted) {
        daysSet.add(dStr);
        totalMinutes += r.totalDurationMinutes ?? 0;
      }
    }
    presentDays = daysSet.length;
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final hoursLabel = h > 0 ? '${h}h ${m}m' : '${m}m';

    return Row(
      children: [
        _buildSummaryCard('PRESENT DAYS', '$presentDays', AppColors.success),
        const SizedBox(width: 10),
        _buildSummaryCard('MONTH HOURS', hoursLabel, AppColors.primary),
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
    final Map<int, List<TeacherAttendanceModel>> recordMap = {};
    for (final r in _monthRecords(state)) {
      recordMap.putIfAbsent(r.attendanceDate.day, () => []).add(r);
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
              final dayRecords = recordMap[day];
              final date = DateTime(
                _selectedMonth.year,
                _selectedMonth.month,
                day,
              );
              final isToday =
                  date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isFuture = date.isAfter(
                DateTime(today.year, today.month, today.day),
              );

              Color? bgColor;
              if (!isFuture && dayRecords != null && dayRecords.isNotEmpty) {
                final hasCompleted = dayRecords.any((r) => r.isCompleted);
                final hasActive = dayRecords.any((r) => r.isActive);

                if (hasCompleted) {
                  bgColor = AppColors.success;
                } else if (hasActive) {
                  bgColor = AppColors.warning;
                } else {
                  bgColor = AppColors.error;
                }
              }

              final isSelected =
                  _selectedDate.year == date.year &&
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
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: (isToday || bgColor != null || isSelected)
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
              _buildLegend('No Record', AppColors.error),
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
    final isSelectedToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    final List<TeacherAttendanceModel> matchedRecords = isSelectedToday
        ? state.todaySessions
        : _monthRecords(state)
            .where(
              (r) =>
                  r.attendanceDate.day == _selectedDate.day &&
                  r.attendanceDate.month == _selectedDate.month &&
                  r.attendanceDate.year == _selectedDate.year,
            )
            .toList();

    int dayTotalSec = 0;
    for (final r in matchedRecords) {
      if (r.isCompleted && r.totalDurationMinutes != null) {
        dayTotalSec += r.totalDurationMinutes! * 60;
      } else if (r.isActive && r.startTime != null) {
        dayTotalSec += AttendanceDateValidator.getCorrectedLocalTime()
            .difference(r.startTime!)
            .inSeconds;
      }
    }
    final dh = dayTotalSec ~/ 3600;
    final dm = (dayTotalSec % 3600) ~/ 60;
    final dayHoursLabel = dh > 0 ? '${dh}h ${dm}m' : '${dm}m';

    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'SESSIONS — ${DateFormat('MMM d, yyyy').format(_selectedDate).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (matchedRecords.isNotEmpty)
                Text(
                  'Total: $dayHoursLabel',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (matchedRecords.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
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
              child: const Column(
                children: [
                  Icon(
                    LucideIcons.helpCircle,
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'NO SESSIONS RECORDED',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'No attendance marked for this day.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            // Latest session of selected day
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    matchedRecords.last.isActive ? LucideIcons.radio : LucideIcons.sparkles,
                    size: 14,
                    color: matchedRecords.last.isActive ? AppColors.warning : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    matchedRecords.last.isActive ? 'CURRENT ACTIVE SESSION' : 'LATEST SESSION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: matchedRecords.last.isActive ? AppColors.warning : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            _buildIndividualSessionCard(
              matchedRecords.last,
              sessionIndex: matchedRecords.length,
              isLatest: true,
            ),
            if (matchedRecords.length > 1) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 8),
                child: Row(
                  children: [
                    const Icon(LucideIcons.history, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'COMPLETED SESSIONS (${matchedRecords.length - 1})',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  for (int i = matchedRecords.length - 2; i >= 0; i--) ...[
                    if (i < matchedRecords.length - 2) const SizedBox(height: 8),
                    _buildIndividualSessionCard(
                      matchedRecords[i],
                      sessionIndex: i + 1,
                      isLatest: false,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildIndividualSessionCard(
    TeacherAttendanceModel record, {
    required int sessionIndex,
    bool isLatest = false,
  }) {
    final isCompleted = record.isCompleted;
    final color = isCompleted ? AppColors.success : AppColors.warning;
    final statusText = isCompleted ? 'Completed' : 'In Progress';

    return Container(
      padding: EdgeInsets.all(isLatest ? 16 : 12),
      decoration: BoxDecoration(
        color: isLatest
            ? color.withValues(alpha: 0.08)
            : (Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLatest
              ? color.withValues(alpha: 0.4)
              : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          width: isLatest ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isCompleted ? LucideIcons.checkCircle : LucideIcons.clock,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Session $sessionIndex',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: isLatest ? 14 : 12,
                ),
              ),
              if (record.subjectName != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '· ${record.subjectName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.logIn,
                  label: 'Punch-In',
                  value: record.startTime != null
                      ? DateFormat('hh:mm a').format(record.startTime!.toLocal())
                      : '--',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.logOut,
                  label: 'Punch-Out',
                  value: record.endTime != null
                      ? DateFormat('hh:mm a').format(record.endTime!.toLocal())
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 8,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------

  Future<void> _verifyLocation({required bool silent}) async {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;
    await context.read<GeofenceCubit>().checkGeofence();
    if (!silent && mounted) {
      final geo = context.read<GeofenceCubit>().state;
      if (geo.status == GeofenceStatus.inside) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inside campus (${geo.distanceMeters.toInt()}m away)',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _startSession(
    BuildContext ctx,
    dynamic teacher,
    GeofenceState geo,
  ) async {
    if (teacher == null) return;
    if (_filterCourseId == null || _filterSubjectId == null) return;

    String? batchId = _filterBatchId;

    await ctx.read<TeacherAttendanceCubit>().startSession(
      teacherId: teacher.id as String,
      subjectId: _filterSubjectId,
      courseId: _filterCourseId,
      batchId: batchId,
      campusProvider: ctx.read<CampusProvider>(),
    );
  }

  void _confirmEndSession(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Punch out current session?',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        content: const Text(
          "This will record your punch-out time and complete this session. You can start another attendance session at any time.",
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
