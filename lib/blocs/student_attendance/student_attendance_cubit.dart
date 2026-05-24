import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/student_attendance_entry_model.dart';
import '../../repositories/student_attendance_teacher_repository.dart';
import 'student_attendance_state.dart';

class StudentAttendanceCubit extends Cubit<StudentAttendanceState> {
  final StudentAttendanceTeacherRepository _repo;

  StudentAttendanceCubit({
    required StudentAttendanceTeacherRepository repository,
  }) : _repo = repository,
       super(const StudentAttendanceState());

  Future<void> loadStudents({
    required String subjectId,
    required String batchId,
    DateTime? date,
    String? courseId,
    String? campusId,
  }) async {
    final sessionDate = date ?? DateTime.now();
    emit(
      state.copyWith(
        status: StudentAttendanceLoadStatus.loading,
        currentSubjectId: subjectId,
        currentBatchId: batchId,
        sessionDate: sessionDate,
        saved: false,
      ),
    );
    try {
      final entries = await _repo.loadStudentsWithAttendance(
        subjectId: subjectId,
        batchId: batchId,
        date: sessionDate,
        courseId: courseId,
        campusId: campusId,
      );
      emit(
        state.copyWith(
          status: StudentAttendanceLoadStatus.success,
          entries: entries,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentAttendanceLoadStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // Toggle a single student's status cyclically: Present → Absent → Late → Leave → Present
  void toggleStatus(String studentId) {
    final updated = state.entries.map((e) {
      if (e.studentId != studentId || e.id != null) return e;
      final next = _nextStatus(e.status);
      return e.copyWith(status: next);
    }).toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  void setStatus(String studentId, StudentAttendanceStatus status) {
    final updated = state.entries.map((e) {
      return e.studentId == studentId && e.id == null
          ? e.copyWith(status: status)
          : e;
    }).toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  void setRemarks(String studentId, String remarks) {
    final updated = state.entries.map((e) {
      return e.studentId == studentId && e.id == null
          ? e.copyWith(remarks: remarks.isEmpty ? null : remarks)
          : e;
    }).toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  // Mark all present at once.
  void markAllPresent() {
    final updated = state.entries
        .map(
          (e) => e.id == null
              ? e.copyWith(status: StudentAttendanceStatus.present)
              : e,
        )
        .toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  // Clear all statuses back to present or unmarked.
  void clearAll() {
    final updated = state.entries
        .map(
          (e) => e.id == null
              ? e.copyWith(
                  status: StudentAttendanceStatus.present,
                  remarks: null,
                )
              : e,
        )
        .toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  Future<void> saveAttendance(
    String teacherId, {
    String? teacherName,
    String? campusId,
    int? periodNumber,
    String? periodLabel,
  }) async {
    if (state.entries.isEmpty) return;
    // A teacher may only write rows for students who do not yet have an
    // attendance record for this (student, subject, date). Entries that
    // already carry an id were marked by someone else (admin or another
    // teacher) and must not be overwritten from this screen -- admin
    // edits go through a separate admin flow.
    final modifiedEntries =
        state.entries.where((e) => e.id == null || e.status != e.originalStatus).toList();
    if (modifiedEntries.isEmpty) {
      emit(state.copyWith(
        status: StudentAttendanceLoadStatus.failure,
        errorMessage: 'No modifications to submit.',
      ));
      return;
    }
    emit(state.copyWith(status: StudentAttendanceLoadStatus.saving));
    try {
      final mappedEntries = modifiedEntries.map((e) {
        return e.copyWith(periodNumber: periodNumber, periodLabel: periodLabel);
      }).toList();

      final writtenRows = await _repo.saveAttendance(
        teacherId: teacherId,
        entries: mappedEntries,
        teacherName: teacherName,
        campusId: campusId,
      );

      // Map the written rows back to the existing entries in the state.
      // firstWhere requires orElse to return the element type, so use a
      // manual lookup that yields null when there is no matching row.
      final writtenList = (writtenRows as List).cast<Map>();
      final updatedEntries = state.entries.map((existing) {
        Map? match;
        for (final row in writtenList) {
          if (row['student_id'] == existing.studentId) {
            match = row;
            break;
          }
        }
        if (match != null) {
          final rowMap = Map<String, dynamic>.from(match);
          return StudentAttendanceEntry(
            id: rowMap['id'] as String?,
            studentId: existing.studentId,
            studentName: existing.studentName,
            rollNumber: existing.rollNumber,
            admissionNumber: existing.admissionNumber,
            profilePhotoDriveId: existing.profilePhotoDriveId,
            subjectId: existing.subjectId,
            courseId: existing.courseId,
            batchId: existing.batchId,
            attendanceDate: existing.attendanceDate,
            status: existing.status,
            originalStatus: existing.status, // Reset originalStatus to current status
            markedBy: rowMap['marked_by'] as String?,
            markedAt: rowMap['marked_at'] != null
                ? DateTime.parse(rowMap['marked_at'] as String)
                : null,
            remarks: rowMap['remarks'] as String?,
            periodNumber: rowMap['period_number'] as int?,
            periodLabel: rowMap['period_label'] as String?,
          );
        }
        return existing;
      }).toList();

      emit(
        state.copyWith(
          status: StudentAttendanceLoadStatus.success,
          saved: true,
          entries: updatedEntries,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentAttendanceLoadStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  StudentAttendanceStatus _nextStatus(StudentAttendanceStatus current) {
    switch (current) {
      case StudentAttendanceStatus.unmarked:
        return StudentAttendanceStatus.present;
      case StudentAttendanceStatus.present:
        return StudentAttendanceStatus.absent;
      case StudentAttendanceStatus.absent:
        return StudentAttendanceStatus.late;
      case StudentAttendanceStatus.late:
        return StudentAttendanceStatus.unmarked;
    }
  }
}
