import 'package:equatable/equatable.dart';
import '../../models/teacher_model.dart';

enum TeacherSessionStatus { initial, loading, ready, error }

class TeacherSessionState extends Equatable {
  final TeacherSessionStatus status;
  final TeacherModel? teacher;
  final String? errorMessage;

  const TeacherSessionState({
    this.status = TeacherSessionStatus.initial,
    this.teacher,
    this.errorMessage,
  });

  bool get isReady => status == TeacherSessionStatus.ready && teacher != null;

  String? get teacherId   => teacher?.id;
  String  get teacherName => teacher?.fullName ?? '';
  String? get campusId    => teacher?.campusId;

  List<TeacherSubjectAssignment> get assignments => teacher?.subjects ?? [];
  List<String> get subjectIds => assignments.map((s) => s.subjectId).toList();
  List<String> get batchIds   => assignments
      .where((s) => s.batchId != null)
      .map((s) => s.batchId!)
      .toSet()
      .toList();

  TeacherSessionState copyWith({
    TeacherSessionStatus? status,
    TeacherModel? teacher,
    String? errorMessage,
  }) {
    return TeacherSessionState(
      status:       status       ?? this.status,
      teacher:      teacher      ?? this.teacher,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, teacher, errorMessage];
}
