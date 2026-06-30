import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/teacher_attendance_repository.dart';
import 'teacher_attendance_state.dart';

class TeacherAttendanceCubit extends Cubit<TeacherAttendanceState> {
  final TeacherAttendanceRepository _repo;

  TeacherAttendanceCubit({required TeacherAttendanceRepository repository})
      : _repo = repository,
        super(const TeacherAttendanceState());

  Future<void> loadTodaySession(String teacherId, {String? sessionType}) async {
    final type = sessionType ?? state.sessionType;
    emit(state.copyWith(status: TeacherAttendanceLoadStatus.loading, sessionType: type));
    try {
      final session   = await _repo.fetchTodayActiveSession(teacherId, type);
      final resolvedType = session != null ? session.sessionType : type;

      final completed = session == null
          ? await _repo.fetchTodayCompletedSession(teacherId, resolvedType)
          : null;
      final pct       = await _repo.fetchMonthlyAttendancePercentage(teacherId);
      emit(state.copyWith(
        status:            TeacherAttendanceLoadStatus.success,
        activeSession:     session,
        completedSession:  completed,
        clearSession:      session == null,
        clearCompleted:    completed == null,
        monthlyPercentage: pct,
        sessionType:       resolvedType,
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
    required String sessionType,
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
        sessionType: sessionType,
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
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> loadHistory(String teacherId, {DateTime? month}) async {
    final ref  = month ?? DateTime.now();
    final from = DateTime(ref.year, ref.month, 1);
    final to   = DateTime(ref.year, ref.month + 1, 0);
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
