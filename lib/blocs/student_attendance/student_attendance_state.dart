import 'package:equatable/equatable.dart';
import '../../models/student_attendance_entry_model.dart';

enum StudentAttendanceLoadStatus { initial, loading, saving, success, failure }

class StudentAttendanceState extends Equatable {
  final StudentAttendanceLoadStatus status;
  final List<StudentAttendanceEntry> entries;
  final String? currentSubjectId;
  final String? currentBatchId;
  final DateTime? sessionDate;
  final String? errorMessage;
  final bool saved;

  const StudentAttendanceState({
    this.status = StudentAttendanceLoadStatus.initial,
    this.entries = const [],
    this.currentSubjectId,
    this.currentBatchId,
    this.sessionDate,
    this.errorMessage,
    this.saved = false,
  });

  Map<String, int> get summary {
    final counts = <String, int>{'Present': 0, 'Absent': 0, 'Late': 0, 'Leave': 0};
    for (final e in entries) {
      final k = e.status.value;
      counts[k] = (counts[k] ?? 0) + 1;
    }
    return counts;
  }

  int get totalStudents => entries.length;
  int get presentCount  => summary['Present'] ?? 0;
  int get absentCount   => summary['Absent']  ?? 0;

  StudentAttendanceState copyWith({
    StudentAttendanceLoadStatus? status,
    List<StudentAttendanceEntry>? entries,
    String? currentSubjectId,
    String? currentBatchId,
    DateTime? sessionDate,
    String? errorMessage,
    bool? saved,
  }) {
    return StudentAttendanceState(
      status:           status           ?? this.status,
      entries:          entries          ?? this.entries,
      currentSubjectId: currentSubjectId ?? this.currentSubjectId,
      currentBatchId:   currentBatchId   ?? this.currentBatchId,
      sessionDate:      sessionDate      ?? this.sessionDate,
      errorMessage:     errorMessage     ?? this.errorMessage,
      saved:            saved            ?? this.saved,
    );
  }

  @override
  List<Object?> get props =>
      [status, entries, currentSubjectId, currentBatchId, sessionDate, saved];
}
