import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/teacher_attendance_repository.dart';
import '../../services/attendance_service.dart';
import '../../providers/campus_provider.dart';
import 'teacher_attendance_state.dart';

class TeacherAttendanceCubit extends Cubit<TeacherAttendanceState> {
  final TeacherAttendanceRepository _repo;
  final AttendanceService _attendanceService;

  TeacherAttendanceCubit({
    required TeacherAttendanceRepository repository,
    required AttendanceService attendanceService,
  }) : _repo = repository,
       _attendanceService = attendanceService,
       super(const TeacherAttendanceState());

  /// Loads current open session, today's session list, and total working minutes for today.
  Future<void> loadTodayAttendance(String teacherId) async {
    emit(state.copyWith(status: TeacherAttendanceLoadStatus.loading));
    try {
      final open = await _repo.fetchOpenSession(teacherId);
      final todayList = await _repo.fetchTodaySessions(teacherId);
      final pct = await _repo.fetchMonthlyAttendancePercentage(teacherId);

      int totalMinutes = 0;
      for (final s in todayList) {
        if (s.isCompleted && s.totalDurationMinutes != null) {
          totalMinutes += s.totalDurationMinutes!;
        }
      }

      emit(
        state.copyWith(
          status: TeacherAttendanceLoadStatus.success,
          openSession: open,
          clearOpenSession: open == null,
          todaySessions: todayList,
          todayTotalMinutes: totalMinutes,
          monthlyPercentage: pct,
          isPunchingIn: false,
          isPunchingOut: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeacherAttendanceLoadStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
          isPunchingIn: false,
          isPunchingOut: false,
        ),
      );
    }
  }

  /// Backward compatibility alias for loadTodayAttendance.
  Future<void> loadTodaySession(String teacherId, {String? sessionType}) =>
      loadTodayAttendance(teacherId);

  /// Punch In to create a new session. Strictly blocked if an open session exists.
  Future<void> startSession({
    required String teacherId,
    required String? subjectId,
    required String? courseId,
    required String? batchId,
    String? sessionType,
    required CampusProvider campusProvider,
  }) async {
    if (state.isPunchingIn || state.hasOpenSession) return;

    emit(state.copyWith(
      status: TeacherAttendanceLoadStatus.loading,
      isPunchingIn: true,
    ));
    try {
      final session = await _attendanceService.punchIn(
        teacherId: teacherId,
        subjectId: subjectId,
        courseId: courseId,
        batchId: batchId,
        sessionType: sessionType ?? 'session',
        campusProvider: campusProvider,
      );

      final todayList = await _repo.fetchTodaySessions(teacherId);
      int totalMinutes = 0;
      for (final s in todayList) {
        if (s.isCompleted && s.totalDurationMinutes != null) {
          totalMinutes += s.totalDurationMinutes!;
        }
      }

      emit(
        state.copyWith(
          status: TeacherAttendanceLoadStatus.success,
          openSession: session,
          todaySessions: todayList,
          todayTotalMinutes: totalMinutes,
          isPunchingIn: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeacherAttendanceLoadStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
          isPunchingIn: false,
        ),
      );
    }
  }

  /// End (Punch Out) the currently open attendance session.
  Future<void> endSession() async {
    final active = state.openSession;
    if (active == null || !active.isActive || state.isPunchingOut) return;

    emit(state.copyWith(
      status: TeacherAttendanceLoadStatus.loading,
      isPunchingOut: true,
    ));
    try {
      await _repo.endSession(active);
      final todayList = await _repo.fetchTodaySessions(active.teacherId);
      int totalMinutes = 0;
      for (final s in todayList) {
        if (s.isCompleted && s.totalDurationMinutes != null) {
          totalMinutes += s.totalDurationMinutes!;
        }
      }

      emit(
        state.copyWith(
          status: TeacherAttendanceLoadStatus.success,
          clearOpenSession: true,
          todaySessions: todayList,
          todayTotalMinutes: totalMinutes,
          isPunchingOut: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeacherAttendanceLoadStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
          isPunchingOut: false,
        ),
      );
    }
  }

  /// Alias for endSession.
  Future<void> punchOut() => endSession();

  /// Load historical sessions for selected date range / month.
  Future<void> loadHistory(String teacherId, {DateTime? month}) async {
    final ref = month ?? DateTime.now();
    final from = DateTime(ref.year, ref.month, 1);
    final to = DateTime(ref.year, ref.month + 1, 0);
    try {
      final history = await _repo.fetchHistory(
        teacherId: teacherId,
        from: from,
        to: to,
      );
      emit(
        state.copyWith(
          status: TeacherAttendanceLoadStatus.success,
          history: history,
        ),
      );
    } catch (_) {}
  }
}
