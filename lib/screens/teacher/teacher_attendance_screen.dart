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

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  Timer? _geofencePoll;

  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  String? _filterCourseId;
  String? _filterSubjectId;
  String? _filterBatchId;
  late String _sessionType;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _sessionType = DateTime.now().hour >= 12 ? 'afternoon' : 'forenoon';
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;

    final cubit = context.read<TeacherAttendanceCubit>();
    await cubit.loadTodaySession(teacher.id, sessionType: _sessionType);
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
                final active = attState.activeSession;
                if (attState.hasActiveSession && active != null) {
                  _filterCourseId = active.courseId;
                  _filterSubjectId = active.subjectId;
                  _filterBatchId = active.batchId;
                }
                return RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.primary,
                  onRefresh: () async {
                    if (teacher == null) return;
                    final cubit = ctx.read<TeacherAttendanceCubit>();
                    await cubit.loadTodaySession(
                      teacher.id,
                      sessionType: _sessionType,
                    );
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
                        _buildSessionSelector(attState),
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
      if (mounted) {
        setState(() {
          _sessionType = state.sessionType;
        });
      }
      if (state.hasActiveSession) {
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
            final allowedRadius =
                matchedCampus?.allowedRadiusMeters.toInt() ?? 25;
            final lat = geo.position?.latitude.toStringAsFixed(4) ?? '0.0';
            final lon = geo.position?.longitude.toStringAsFixed(4) ?? '0.0';

            title = '✓ Inside $campusName';
            subtitle = '';
            break;
          // 'GPS: [$lat, $lon] | Dist: ${geo.distanceMeters.toInt()}m | Allowed: ${allowedRadius}m'
          case GeofenceStatus.outside:
            color = AppColors.error;
            icon = LucideIcons.shieldAlert;

            final lat = geo.position?.latitude.toStringAsFixed(4) ?? '0.0';
            final lon = geo.position?.longitude.toStringAsFixed(4) ?? '0.0';

            title = '✗ Outside Assigned Campuses';
            subtitle = '';
            // GPS: [$lat, $lon] | Dist: ${geo.distanceMeters.toInt()}m away from nearest campus
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
                // const SizedBox(height: 2),
                // Text(
                //   subtitle,
                //   style: const TextStyle(
                //     fontSize: 12,
                //     color: AppColors.textSecondary,
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSelector(TeacherAttendanceState state) {
    final isForenoon = _sessionType == 'forenoon';
    return Row(
      children: [
        Expanded(
          child: _sessionButton(
            label: 'FORENOON',
            selected: isForenoon,
            onTap: () {
              if (_sessionType != 'forenoon') {
                setState(() {
                  _sessionType = 'forenoon';
                });
                final teacher = context
                    .read<TeacherDashboardCubit>()
                    .state
                    .teacher;
                if (teacher != null) {
                  context.read<TeacherAttendanceCubit>().loadTodaySession(
                    teacher.id,
                    sessionType: 'forenoon',
                  );
                }
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _sessionButton(
            label: 'AFTERNOON',
            selected: !isForenoon,
            onTap: () {
              if (_sessionType != 'afternoon') {
                setState(() {
                  _sessionType = 'afternoon';
                });
                final teacher = context
                    .read<TeacherDashboardCubit>()
                    .state
                    .teacher;
                if (teacher != null) {
                  context.read<TeacherAttendanceCubit>().loadTodaySession(
                    teacher.id,
                    sessionType: 'afternoon',
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _sessionButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------

  Widget _buildPunchCard(
    BuildContext ctx,
    TeacherAttendanceState attState,
    dynamic teacher,
  ) {
    if (attState.hasActiveSession && _elapsedTimer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startElapsedTimer());
    } else if (!attState.hasActiveSession && _elapsedTimer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _stopElapsedTimer());
    }

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
    BuildContext ctx,
    dynamic teacher,
    bool isLoading,
  ) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (geoCtx, geo) {
        final noCampus = teacher == null || !teacher.hasCampusCoordinates;
        final insideCampus = noCampus || geo.status == GeofenceStatus.inside;
        final hasFilters = _filterCourseId != null && _filterSubjectId != null;
        final nowTime = AttendanceDateValidator.getCorrectedLocalTime();
        final isTimeAllowed =
            (_sessionType == 'forenoon' && nowTime.hour < 12) ||
            (_sessionType == 'afternoon' && nowTime.hour >= 12);
        final canPunch = insideCampus && hasFilters && isTimeAllowed;

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
        } else if (!isTimeAllowed) {
          label = _sessionType == 'forenoon'
              ? 'FORENOON NOT ALLOWED'
              : 'AFTERNOON NOT ALLOWED';
          icon = LucideIcons.lock;
          color = AppColors.textSecondary;
          disabledHint = _sessionType == 'forenoon'
              ? 'Cannot mark attendance for forenoon at this time.'
              : 'Cannot mark attendance for afternoon at this time.';
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

    // Build distinct course list from teacher assignments.
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

    // Self-heal stale course selection
    final bool courseStillValid =
        _filterCourseId == null || courses.containsKey(_filterCourseId);
    if (!isDisabled && !courseStillValid) {
      _filterCourseId = null;
      _filterSubjectId = null;
      _filterBatchId = null;
    }

    // Subjects scoped by the currently selected course (if any).
    final List<dynamic> subjectItems = _filterCourseId == null
        ? const []
        : List<dynamic>.from(
            assignments.where((a) => a.courseId == _filterCourseId),
          );

    // Deduplicate subjectItems by subjectId to show only the course subjects, not batch-wise.
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
      // Self-heal stale selections (e.g., course changed -> subject mismatch).
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
                      // Resolve batch from assignments for the selected subject.
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

  Widget _buildActivePunchCard(
    BuildContext ctx,
    TeacherAttendanceModel session,
    bool isLoading,
  ) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (geoCtx, geo) {
        final teacher = context.read<TeacherDashboardCubit>().state.teacher;
        final noCampus = teacher == null || !teacher.hasCampusCoordinates;

        final elapsedDuration = session.startTime != null
            ? AttendanceDateValidator.getCorrectedLocalTime().difference(
                session.startTime!,
              )
            : Duration.zero;
        final isDurationMet = elapsedDuration.inHours >= 1;

        // Auto-refresh: if more than 4 hours has passed, trigger load to auto-punchout
        if (elapsedDuration.inMinutes > 240) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !isLoading) {
              ctx.read<TeacherAttendanceCubit>().loadTodaySession(
                teacher!.id,
                sessionType: _sessionType,
              );
            }
          });
        }

        final canPunchOut =
            (noCampus || geo.status == GeofenceStatus.inside) && isDurationMet;

        final maxDuration = const Duration(hours: 4);
        final remaining = maxDuration - elapsedDuration;
        final displayDuration = remaining.isNegative
            ? Duration.zero
            : remaining;

        final hh = displayDuration.inHours.toString().padLeft(2, '0');
        final mm = (displayDuration.inMinutes % 60).toString().padLeft(2, '0');
        final ss = (displayDuration.inSeconds % 60).toString().padLeft(2, '0');
        final elapsedStr = '$hh:$mm:$ss';

        return CustomCard(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _statusPill(
                  label: 'PUNCHED IN',
                  color: AppColors.success,
                  showDot: true,
                ),
              ),
              const SizedBox(height: 16),
              _buildFilters(teacher, isDisabled: true, activeSession: session),
              const SizedBox(height: 16),

              // Large timer display
              Center(
                child: Column(
                  children: [
                    Text(
                      elapsedStr,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'REMAINING TIME (4H MAX)',
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

              if (!isDurationMet) ...[
                // Countdown representation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.lock,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PUNCH-OUT LOCKED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.warning,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Minimum session duration is 1 hour. Available in ${(const Duration(hours: 1) - elapsedDuration).inMinutes}m ${(const Duration(hours: 1) - elapsedDuration).inSeconds % 60}s.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Punch out button
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompletedPunchCard(TeacherAttendanceModel session) {
    final isLate = session.isLate;
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _statusPill(
            label: isLate ? 'LATE ATTENDANCE' : 'ATTENDANCE COMPLETED',
            color: isLate ? AppColors.warning : AppColors.success,
            icon: isLate ? LucideIcons.clock : LucideIcons.checkCircle,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.logIn,
                  label: 'Punch-In',
                  value: session.startTime != null
                      ? DateFormat(
                          'hh:mm a',
                        ).format(session.startTime!.toLocal())
                      : '--',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.logOut,
                  label: 'Punch-Out',
                  value: session.endTime != null
                      ? DateFormat('hh:mm a').format(session.endTime!.toLocal())
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
              color: AppColors.primary,
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
    final Map<int, List<TeacherAttendanceModel>> recordMap = {};
    for (final r in _monthRecords(state)) {
      recordMap.putIfAbsent(r.attendanceDate.day, () => []).add(r);
    }
    // Also include today's active session in calendar
    final active = state.activeSession;
    if (active != null &&
        active.attendanceDate.year == _selectedMonth.year &&
        active.attendanceDate.month == _selectedMonth.month) {
      final list = recordMap.putIfAbsent(active.attendanceDate.day, () => []);
      if (!list.any(
        (r) => r.id == active.id || r.sessionType == active.sessionType,
      )) {
        list.add(active);
      }
    }
    final completedToday = state.completedSession;
    if (completedToday != null &&
        completedToday.attendanceDate.year == _selectedMonth.year &&
        completedToday.attendanceDate.month == _selectedMonth.month) {
      final list = recordMap.putIfAbsent(
        completedToday.attendanceDate.day,
        () => [],
      );
      if (!list.any(
        (r) =>
            r.id == completedToday.id ||
            r.sessionType == completedToday.sessionType,
      )) {
        list.add(completedToday);
      }
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
                final hasCompletedOnTime = dayRecords.any(
                  (r) => r.isCompleted && !r.isLate,
                );
                final hasActive = dayRecords.any((r) => r.isActive);
                final hasCompletedLate = dayRecords.any(
                  (r) => r.isCompleted && r.isLate,
                );

                if (hasCompletedOnTime) {
                  bgColor = AppColors.success;
                } else if (hasActive || hasCompletedLate) {
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
    final List<TeacherAttendanceModel> matchedRecords = [];
    for (final r in _monthRecords(state)) {
      if (r.attendanceDate.day == _selectedDate.day &&
          r.attendanceDate.month == _selectedDate.month &&
          r.attendanceDate.year == _selectedDate.year) {
        matchedRecords.add(r);
      }
    }
    final active = _matchesDate(state.activeSession, _selectedDate);
    if (active != null &&
        !matchedRecords.any(
          (m) => m.id == active.id || m.sessionType == active.sessionType,
        )) {
      matchedRecords.add(active);
    }
    final completed = _matchesDate(state.completedSession, _selectedDate);
    if (completed != null &&
        !matchedRecords.any(
          (m) => m.id == completed.id || m.sessionType == completed.sessionType,
        )) {
      matchedRecords.add(completed);
    }

    // Sort by session order (forenoon, afternoon, evening)
    matchedRecords.sort((a, b) {
      final order = {'forenoon': 1, 'afternoon': 2, 'evening': 3};
      return (order[a.sessionType] ?? 9).compareTo(order[b.sessionType] ?? 9);
    });

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
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.helpCircle,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'NOT MARKED',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No attendance marked for this day.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < matchedRecords.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildIndividualSessionCard(matchedRecords[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildIndividualSessionCard(TeacherAttendanceModel record) {
    Color color;
    IconData icon;
    String statusLabel;
    if (record.isCompleted) {
      if (record.isLate) {
        color = AppColors.warning;
        icon = LucideIcons.clock;
        statusLabel = 'LATE';
      } else {
        color = AppColors.success;
        icon = LucideIcons.checkCircle;
        statusLabel = 'PRESENT';
      }
    } else if (record.isActive) {
      color = AppColors.warning;
      icon = LucideIcons.clock;
      statusLabel = 'IN PROGRESS';
    } else {
      color = AppColors.error;
      icon = LucideIcons.xCircle;
      statusLabel = 'MISSED';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                record.sessionType.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  icon: LucideIcons.logIn,
                  label: 'Punch-In',
                  value: record.startTime != null
                      ? DateFormat(
                          'hh:mm a',
                        ).format(record.startTime!.toLocal())
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

  TeacherAttendanceModel? _matchesDate(
    TeacherAttendanceModel? r,
    DateTime date,
  ) {
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

    // Resolve batch from the chosen subject assignment.
    String? batchId = _filterBatchId;

    await ctx.read<TeacherAttendanceCubit>().startSession(
      teacherId: teacher.id as String,
      subjectId: _filterSubjectId,
      courseId: _filterCourseId,
      batchId: batchId,
      sessionType: _sessionType,
      campusProvider: ctx.read<CampusProvider>(),
    );
  }

  void _confirmEndSession(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
