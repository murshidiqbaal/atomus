import 'package:equatable/equatable.dart';
import '../../models/exam_marks_model.dart';
import '../../models/teacher_model.dart';
import '../../models/teacher_attendance_model.dart';

enum TeacherDashboardStatus { initial, loading, success, failure }

class TeacherDashboardState extends Equatable {
  final TeacherDashboardStatus status;
  final TeacherModel? teacher;
  final TeacherAttendanceModel? activeSession;
  final TeacherDashboardStats stats;
  final List<TeacherExam> upcomingExams;
  final String? errorMessage;

  const TeacherDashboardState({
    this.status = TeacherDashboardStatus.initial,
    this.teacher,
    this.activeSession,
    this.stats = const TeacherDashboardStats(),
    this.upcomingExams = const [],
    this.errorMessage,
  });

  TeacherDashboardState copyWith({
    TeacherDashboardStatus? status,
    TeacherModel? teacher,
    TeacherAttendanceModel? activeSession,
    bool clearSession = false,
    TeacherDashboardStats? stats,
    List<TeacherExam>? upcomingExams,
    String? errorMessage,
  }) {
    return TeacherDashboardState(
      status:        status        ?? this.status,
      teacher:       teacher       ?? this.teacher,
      activeSession: clearSession ? null : (activeSession ?? this.activeSession),
      stats:         stats         ?? this.stats,
      upcomingExams: upcomingExams ?? this.upcomingExams,
      errorMessage:  errorMessage  ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, teacher, activeSession, stats, upcomingExams];
}
