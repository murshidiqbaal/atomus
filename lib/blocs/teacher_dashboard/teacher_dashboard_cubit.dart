import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/exam_marks_model.dart';
import '../../models/teacher_model.dart';
import '../../repositories/marks_entry_repository.dart';
import '../../repositories/teacher_attendance_repository.dart';
import '../../repositories/teacher_repository.dart';
import '../../services/teacher_hive_service.dart';
import 'teacher_dashboard_state.dart';
import '../auth/auth_bloc.dart';
import '../auth/auth_state.dart';
import '../../utils/attendance_date_validator.dart';

class TeacherDashboardCubit extends Cubit<TeacherDashboardState> {
  final TeacherRepository _teacherRepo;
  final TeacherAttendanceRepository _attendanceRepo;
  final MarksEntryRepository _marksRepo;
  final TeacherHiveService _hiveService;
  StreamSubscription<AuthState>? _authSubscription;

  TeacherDashboardCubit({
    required TeacherRepository teacherRepository,
    required TeacherAttendanceRepository attendanceRepository,
    required MarksEntryRepository marksRepository,
    required AuthBloc authBloc,
    TeacherHiveService? hiveService,
  }) : _teacherRepo = teacherRepository,
       _attendanceRepo = attendanceRepository,
       _marksRepo = marksRepository,
       _hiveService = hiveService ?? TeacherHiveService(),
       super(const TeacherDashboardState()) {
    _initAuthListener(authBloc);
  }

  void _initAuthListener(AuthBloc authBloc) {
    _authSubscription = authBloc.stream.listen((state) {
      if (state.status == AuthStatus.unauthenticated) {
        reset();
      }
    });
  }

  void reset() {
    emit(const TeacherDashboardState());
  }

  Future<void> load() async {
    emit(state.copyWith(status: TeacherDashboardStatus.loading));

    // ── 1. Show cached teacher profile instantly ─────────────────
    try {
      await _hiveService.initBoxes();
      final cachedProfile = _hiveService.getTeacherProfile();
      if (cachedProfile != null) {
        final cachedTeacher = TeacherModel.fromMap(cachedProfile);
        emit(state.copyWith(
          status: TeacherDashboardStatus.success,
          teacher: cachedTeacher,
          stats: TeacherDashboardStats(
            todayClassCount: cachedTeacher.subjects.length,
          ),
        ));
      }
    } catch (e) {
      print('TeacherDashboardCubit: Cache read failed (non-fatal): $e');
    }

    // ── 2. Fetch fresh data from Supabase ────────────────────────
    try {
      final teacher = await _teacherRepo.fetchTeacherProfile();
      if (teacher == null) {
        // If we already have cached data, keep it
        if (state.teacher != null) {
          emit(state.copyWith(
            status: TeacherDashboardStatus.success,
            errorMessage: 'Could not refresh teacher profile.',
          ));
          return;
        }
        emit(
          state.copyWith(
            status: TeacherDashboardStatus.failure,
            errorMessage: 'Teacher profile not found.',
          ),
        );
        return;
      }

      final subjectIds = teacher.subjects.map((s) => s.subjectId).toList();
      final batchIds = teacher.subjects
          .map((s) => s.batchId)
          .whereType<String>()
          .toSet()
          .toList();
      final courseIds = teacher.courses.map((c) => c.courseId).toSet().toList();

      final activeSession = await _attendanceRepo.fetchTodayActiveSession(
        teacher.id,
      );
      final monthlyPct = await _attendanceRepo.fetchMonthlyAttendancePercentage(
        teacher.id,
      );

      final now = AttendanceDateValidator.getCorrectedLocalTime();
      final from = DateTime(now.year, now.month, 1);
      final to = DateTime(now.year, now.month + 1, 0);
      final history = await _attendanceRepo.fetchHistory(
        teacherId: teacher.id,
        from: from,
        to: to,
      );
      final monthlyAttendanceCount = history.where((r) => r.isCompleted).length;

      List<TeacherExam> upcomingExams = [];
      int pendingMarks = 0;
      if (subjectIds.isNotEmpty || courseIds.isNotEmpty) {
        upcomingExams = await _marksRepo.fetchAssignedExams(
          subjectIds: subjectIds,
          batchIds: batchIds,
          courseIds: courseIds,
          includeUpcoming: true,
        );
        pendingMarks = upcomingExams.where((e) => !e.isMarksEntered).length;
      }

      final stats = TeacherDashboardStats(
        todayClassCount: teacher.subjects.length,
        attendancePercentage: monthlyPct,
        hasActiveSession: activeSession != null,
        upcomingExamCount: upcomingExams.length,
        pendingMarksCount: pendingMarks,
        monthlyAttendanceCount: monthlyAttendanceCount,
      );

      emit(
        state.copyWith(
          status: TeacherDashboardStatus.success,
          teacher: teacher,
          activeSession: activeSession,
          clearSession: activeSession == null,
          stats: stats,
          upcomingExams: upcomingExams.take(10).toList(),
        ),
      );
    } catch (e) {
      // If we already have cached data displayed, keep it
      if (state.teacher != null) {
        print(
          'TeacherDashboardCubit: Network fetch failed, keeping cached data: $e',
        );
        emit(state.copyWith(
          status: TeacherDashboardStatus.success,
          errorMessage: 'Using cached data. Could not refresh: $e',
        ));
      } else {
        emit(
          state.copyWith(
            status: TeacherDashboardStatus.failure,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  Future<void> refresh() => load();

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
