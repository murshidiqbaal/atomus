import 'package:equatable/equatable.dart';
import '../../models/teacher_attendance_model.dart';

enum TeacherAttendanceLoadStatus { initial, loading, success, failure }

class TeacherAttendanceState extends Equatable {
  final TeacherAttendanceLoadStatus status;
  final TeacherAttendanceModel? activeSession;
  final TeacherAttendanceModel? completedSession; // today's most recent completed session
  final List<TeacherAttendanceModel> history;
  final double monthlyPercentage;
  final String? errorMessage;
  final String sessionType; // 'forenoon' or 'afternoon'

  const TeacherAttendanceState({
    this.status = TeacherAttendanceLoadStatus.initial,
    this.activeSession,
    this.completedSession,
    this.history = const [],
    this.monthlyPercentage = 0,
    this.errorMessage,
    this.sessionType = 'forenoon',
  });

  bool get hasActiveSession => activeSession != null && activeSession!.isActive;

  TeacherAttendanceState copyWith({
    TeacherAttendanceLoadStatus? status,
    TeacherAttendanceModel? activeSession,
    TeacherAttendanceModel? completedSession,
    bool clearSession = false,
    bool clearCompleted = false,
    List<TeacherAttendanceModel>? history,
    double? monthlyPercentage,
    String? errorMessage,
    String? sessionType,
  }) {
    return TeacherAttendanceState(
      status:            status             ?? this.status,
      activeSession:     clearSession ? null : (activeSession ?? this.activeSession),
      completedSession:  clearCompleted ? null : (completedSession ?? this.completedSession),
      history:           history            ?? this.history,
      monthlyPercentage: monthlyPercentage  ?? this.monthlyPercentage,
      errorMessage:      errorMessage       ?? this.errorMessage,
      sessionType:      sessionType        ?? this.sessionType,
    );
  }

  @override
  List<Object?> get props =>
      [status, activeSession, completedSession, history, monthlyPercentage, errorMessage, sessionType];
}
