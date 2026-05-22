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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final dashState = context.read<TeacherDashboardCubit>().state;
    final teacher   = dashState.teacher;
    if (teacher == null) return;

    await context
        .read<TeacherAttendanceCubit>()
        .loadTodaySession(teacher.id);

    if (!mounted) return;

    if (teacher.hasCampusCoordinates) {
      await context.read<GeofenceCubit>().checkGeofence(
            campusLatitude:  teacher.campusLatitude!,
            campusLongitude: teacher.campusLongitude!,
            radiusMeters:    teacher.geofenceRadiusMeters,
          );
    }

    if (mounted) _tryStartTimer();
  }

  void _tryStartTimer() {
    final attState = context.read<TeacherAttendanceCubit>().state;
    if (attState.hasActiveSession && attState.activeSession?.startTime != null) {
      _elapsed = DateTime.now().difference(attState.activeSession!.startTime!);
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    context.read<GeofenceCubit>().stopSessionTracking();
    super.dispose();
  }

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
          listener: (ctx, state) {
            if (state.status == TeacherAttendanceLoadStatus.success) {
              if (state.hasActiveSession) {
                _sessionTimer?.cancel();
                _elapsed = state.activeSession?.startTime != null
                    ? DateTime.now()
                        .difference(state.activeSession!.startTime!)
                    : Duration.zero;
                _sessionTimer =
                    Timer.periodic(const Duration(seconds: 1), (_) {
                  if (mounted) {
                    setState(() => _elapsed += const Duration(seconds: 1));
                  }
                });
                final teacher =
                    context.read<TeacherDashboardCubit>().state.teacher;
                if (teacher?.hasCampusCoordinates == true) {
                  ctx.read<GeofenceCubit>().startSessionTracking(
                        campusLatitude:  teacher!.campusLatitude!,
                        campusLongitude: teacher.campusLongitude!,
                        radiusMeters:    teacher.geofenceRadiusMeters,
                      );
                }
              } else {
                _sessionTimer?.cancel();
                ctx.read<GeofenceCubit>().stopSessionTracking();
              }
            }
            if (state.status == TeacherAttendanceLoadStatus.failure) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'An error occurred'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (ctx, attState) {
            return BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
              builder: (ctx2, dashState) {
                final teacher = dashState.teacher;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildGeofenceCard(context),
                    const SizedBox(height: 16),
                    _buildSessionCard(context, attState, teacher),
                    const SizedBox(height: 16),
                    _buildHistorySection(context, attState),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildGeofenceCard(BuildContext context) {
    return BlocBuilder<GeofenceCubit, GeofenceState>(
      builder: (ctx, geo) {
        final Color bg = geo.status == GeofenceStatus.inside
            ? AppColors.success
            : geo.status == GeofenceStatus.checking
                ? AppColors.info
                : AppColors.error;

        return CustomCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bg.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: geo.status == GeofenceStatus.checking
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: bg,
                        ),
                      )
                    : Icon(
                        geo.status == GeofenceStatus.inside
                            ? LucideIcons.mapPin
                            : LucideIcons.mapPinOff,
                        color: bg,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      geo.status == GeofenceStatus.inside
                          ? 'Inside Campus'
                          : geo.status == GeofenceStatus.checking
                              ? 'Checking Location...'
                              : 'Outside Campus',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: bg,
                      ),
                    ),
                    Text(
                      geo.statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (geo.status != GeofenceStatus.checking)
                IconButton(
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  onPressed: _recheckGeofence,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    TeacherAttendanceState attState,
    dynamic teacher,
  ) {
    final isLoading = attState.status == TeacherAttendanceLoadStatus.loading;

    if (attState.hasActiveSession) {
      return _buildActiveSessionCard(context, attState.activeSession!, isLoading);
    }

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Today\'s Session',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _buildSubjectSelector(context, teacher),
          const SizedBox(height: 16),
          BlocBuilder<GeofenceCubit, GeofenceState>(
            builder: (ctx, geo) {
              final canStart = geo.status == GeofenceStatus.inside ||
                  teacher?.campusLatitude == null;
              return SizedBox(
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
                    canStart ? 'Start Class' : 'Outside Campus Radius',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        canStart ? AppColors.primary : AppColors.textSecondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: (canStart && !isLoading)
                      ? () => _startSession(ctx, teacher, geo)
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String? _selectedSubjectId;
  String? _selectedCourseId;
  String? _selectedBatchId;

  Widget _buildSubjectSelector(BuildContext context, dynamic teacher) {
    final subjects = (teacher?.subjects as List?) ?? [];
    if (subjects.isEmpty) {
      return const Text('No subjects assigned.',
          style: TextStyle(color: AppColors.textSecondary));
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

  Widget _buildActiveSessionCard(
    BuildContext context,
    TeacherAttendanceModel session,
    bool isLoading,
  ) {
    final hours   = _elapsed.inHours;
    final minutes = _elapsed.inMinutes % 60;
    final seconds = _elapsed.inSeconds % 60;

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text('CLASS IN SESSION',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: AppColors.success,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            session.subjectName ?? 'Active Class',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timerSegment(hours.toString().padLeft(2, '0'), 'HRS'),
              const Text(' : ',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent)),
              _timerSegment(minutes.toString().padLeft(2, '0'), 'MIN'),
              const Text(' : ',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent)),
              _timerSegment(seconds.toString().padLeft(2, '0'), 'SEC'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Started at ${session.startTime != null ? DateFormat('hh:mm a').format(session.startTime!) : '--'}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.users, size: 16),
                  label: const Text('Take Attendance'),
                  onPressed: () => _goToStudentAttendance(context, session),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
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
                      : () => _confirmEndSession(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
      BuildContext context, TeacherAttendanceState state) {
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
    final Color color = record.isCompleted ? AppColors.success : AppColors.error;
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
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

  Widget _timerSegment(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
              fontSize: 32,
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

  Future<void> _recheckGeofence() async {
    final teacher =
        context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null || !teacher.hasCampusCoordinates) return;
    await context.read<GeofenceCubit>().checkGeofence(
          campusLatitude:  teacher.campusLatitude!,
          campusLongitude: teacher.campusLongitude!,
          radiusMeters:    teacher.geofenceRadiusMeters,
        );
  }

  Future<void> _startSession(
      BuildContext context, dynamic teacher, GeofenceState geo) async {
    await context.read<TeacherAttendanceCubit>().startSession(
          teacherId: teacher.id as String,
          campusId:  teacher.campusId as String?,
          subjectId: _selectedSubjectId,
          courseId:  _selectedCourseId,
          batchId:   _selectedBatchId,
          latitude:  geo.position?.latitude,
          longitude: geo.position?.longitude,
        );
  }

  void _confirmEndSession(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Class?'),
        content: const Text(
            'This will mark your attendance as completed for today.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TeacherAttendanceCubit>().endSession();
            },
            child: const Text('End Class',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _goToStudentAttendance(
      BuildContext context, TeacherAttendanceModel session) {
    if (session.subjectId == null || session.batchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No batch assigned to this session.')),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudentAttendanceScreen(
        subjectId:   session.subjectId!,
        subjectName: session.subjectName ?? 'Subject',
        batchId:     session.batchId!,
        courseId:    session.courseId,
      ),
    ));
  }
}
