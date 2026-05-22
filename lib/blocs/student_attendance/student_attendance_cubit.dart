import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/student_attendance_entry_model.dart';
import '../../repositories/student_attendance_teacher_repository.dart';
import 'student_attendance_state.dart';

class StudentAttendanceCubit extends Cubit<StudentAttendanceState> {
  final StudentAttendanceTeacherRepository _repo;

  StudentAttendanceCubit({
    required StudentAttendanceTeacherRepository repository,
  })  : _repo = repository,
        super(const StudentAttendanceState());

  Future<void> loadStudents({
    required String subjectId,
    required String batchId,
    DateTime? date,
    String? courseId,
  }) async {
    final sessionDate = date ?? DateTime.now();
    emit(state.copyWith(
      status:           StudentAttendanceLoadStatus.loading,
      currentSubjectId: subjectId,
      currentBatchId:   batchId,
      sessionDate:      sessionDate,
      saved:            false,
    ));
    try {
      final entries = await _repo.loadStudentsWithAttendance(
        subjectId: subjectId,
        batchId:   batchId,
        date:      sessionDate,
        courseId:  courseId,
      );
      emit(state.copyWith(
        status:  StudentAttendanceLoadStatus.success,
        entries: entries,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       StudentAttendanceLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  // Toggle a single student's status cyclically: Present → Absent → Late → Leave → Present
  void toggleStatus(String studentId) {
    final updated = state.entries.map((e) {
      if (e.studentId != studentId) return e;
      final next = _nextStatus(e.status);
      return e.copyWith(status: next);
    }).toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  void setStatus(String studentId, StudentAttendanceStatus status) {
    final updated = state.entries.map((e) {
      return e.studentId == studentId ? e.copyWith(status: status) : e;
    }).toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  // Mark all present at once.
  void markAllPresent() {
    final updated = state.entries
        .map((e) => e.copyWith(status: StudentAttendanceStatus.present))
        .toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  Future<void> saveAttendance(
    String teacherId, {
    String? teacherName,
    String? campusId,
  }) async {
    if (state.entries.isEmpty) return;
    emit(state.copyWith(status: StudentAttendanceLoadStatus.saving));
    try {
      await _repo.saveAttendance(
        teacherId:   teacherId,
        entries:     state.entries,
        teacherName: teacherName,
        campusId:    campusId,
      );
      emit(state.copyWith(
        status: StudentAttendanceLoadStatus.success,
        saved:  true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       StudentAttendanceLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  StudentAttendanceStatus _nextStatus(StudentAttendanceStatus current) {
    switch (current) {
      case StudentAttendanceStatus.present: return StudentAttendanceStatus.absent;
      case StudentAttendanceStatus.absent:  return StudentAttendanceStatus.late;
      case StudentAttendanceStatus.late:    return StudentAttendanceStatus.leave;
      case StudentAttendanceStatus.leave:   return StudentAttendanceStatus.present;
    }
  }
}
