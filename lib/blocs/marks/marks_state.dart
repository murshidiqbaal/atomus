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

  const MarksState({
    this.status = MarksLoadStatus.initial,
    this.exams = const [],
    this.selectedExam,
    this.entries = const [],
    this.errorMessage,
    this.saved = false,
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
  }) {
    return MarksState(
      status:       status       ?? this.status,
      exams:        exams        ?? this.exams,
      selectedExam: selectedExam ?? this.selectedExam,
      entries:      entries      ?? this.entries,
      errorMessage: errorMessage ?? this.errorMessage,
      saved:        saved        ?? this.saved,
    );
  }

  @override
  List<Object?> get props =>
      [status, exams, selectedExam, entries, saved];
}
