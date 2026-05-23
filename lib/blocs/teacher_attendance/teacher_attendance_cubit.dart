import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/teacher_attendance_repository.dart';
import 'teacher_attendance_state.dart';

class TeacherAttendanceCubit extends Cubit<TeacherAttendanceState> {
  final TeacherAttendanceRepository _repo;

  TeacherAttendanceCubit({required TeacherAttendanceRepository repository})
      : _repo = repository,
        super(const TeacherAttendanceState());

  Future<void> loadTodaySession(String teacherId) async {
    emit(state.copyWith(status: TeacherAttendanceLoadStatus.loading));
    try {
      final session   = await _repo.fetchTodayActiveSession(teacherId);
      final completed = session == null
          ? await _repo.fetchTodayCompletedSession(teacherId)
          : null;
      final pct       = await _repo.fetchMonthlyAttendancePercentage(teacherId);
      emit(state.copyWith(
        status:            TeacherAttendanceLoadStatus.success,
        activeSession:     session,
        completedSession:  completed,
        monthlyPercentage: pct,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       TeacherAttendanceLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> startSession({
    required String teacherId,
    required String? campusId,
    required String? subjectId,
    required String? courseId,
    required String? batchId,
    required double? latitude,
    required double? longitude,
  }) async {
    emit(state.copyWith(status: TeacherAttendanceLoadStatus.loading));
    try {
      final session = await _repo.startSession(
        teacherId: teacherId,
        campusId:  campusId,
        subjectId: subjectId,
        courseId:  courseId,
        batchId:   batchId,
        latitude:  latitude,
        longitude: longitude,
      );
      emit(state.copyWith(
        status:           TeacherAttendanceLoadStatus.success,
        activeSession:    session,
        clearCompleted:   true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       TeacherAttendanceLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> endSession() async {
    final active = state.activeSession;
    if (active == null || !active.isActive) return;

    emit(state.copyWith(status: TeacherAttendanceLoadStatus.loading));
    try {
      final completed = await _repo.endSession(active);
      final history   = [completed, ...state.history];
      emit(state.copyWith(
        status:           TeacherAttendanceLoadStatus.success,
        clearSession:     true,
        completedSession: completed,
        history:          history,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       TeacherAttendanceLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> loadHistory(String teacherId) async {
    final now  = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to   = DateTime(now.year, now.month + 1, 0);
    try {
      final history = await _repo.fetchHistory(
        teacherId: teacherId, from: from, to: to,
      );
      emit(state.copyWith(
        status:  TeacherAttendanceLoadStatus.success,
        history: history,
      ));
    } catch (_) {}
  }
}
