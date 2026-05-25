import 'package:equatable/equatable.dart';
import '../../models/exam_marks_model.dart';

enum MarksLoadStatus { initial, loading, saving, success, failure }

class MarksState extends Equatable {
  final MarksLoadStatus status;
  final List<TeacherExam> exams;
  final TeacherExam? selectedExam;
  final List<StudentMarksEntry> entries;
  final String? errorMessage;
  final bool saved;

  // The mark_date being viewed/edited. Defaults to today. For regular
  // exams this stays at the exam's date; for daily exams the teacher
  // can flip it day-by-day from the UI without affecting the exam row.
  final DateTime? selectedMarkDate;

  const MarksState({
    this.status = MarksLoadStatus.initial,
    this.exams = const [],
    this.selectedExam,
    this.entries = const [],
    this.errorMessage,
    this.saved = false,
    this.selectedMarkDate,
  });

  double get classAverage {
    final valid = entries.where((e) => !e.isAbsent && e.marksObtained != null);
    if (valid.isEmpty) return 0;
    final total = valid.fold<double>(0, (sum, e) => sum + e.marksObtained!);
    return total / valid.length;
  }

  int get pendingCount =>
      entries.where((e) => !e.isAbsent && e.marksObtained == null).length;

  MarksState copyWith({
    MarksLoadStatus? status,
    List<TeacherExam>? exams,
    TeacherExam? selectedExam,
    List<StudentMarksEntry>? entries,
    String? errorMessage,
    bool? saved,
    DateTime? selectedMarkDate,
    bool clearSelectedMarkDate = false,
  }) {
    return MarksState(
      status:           status       ?? this.status,
      exams:            exams        ?? this.exams,
      selectedExam:     selectedExam ?? this.selectedExam,
      entries:          entries      ?? this.entries,
      errorMessage:     errorMessage ?? this.errorMessage,
      saved:            saved        ?? this.saved,
      selectedMarkDate: clearSelectedMarkDate
          ? null
          : (selectedMarkDate ?? this.selectedMarkDate),
    );
  }

  @override
  List<Object?> get props =>
      [status, exams, selectedExam, entries, saved, selectedMarkDate];
}
