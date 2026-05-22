import 'package:equatable/equatable.dart';
import '../../models/teacher_attendance_model.dart';

enum TeacherAttendanceLoadStatus { initial, loading, success, failure }

class TeacherAttendanceState extends Equatable {
  final TeacherAttendanceLoadStatus status;
  final TeacherAttendanceModel? activeSession;
  final List<TeacherAttendanceModel> history;
  final double monthlyPercentage;
  final String? errorMessage;

  const TeacherAttendanceState({
    this.status = TeacherAttendanceLoadStatus.initial,
    this.activeSession,
    this.history = const [],
    this.monthlyPercentage = 0,
    this.errorMessage,
  });

  bool get hasActiveSession => activeSession != null && activeSession!.isActive;

  TeacherAttendanceState copyWith({
    TeacherAttendanceLoadStatus? status,
    TeacherAttendanceModel? activeSession,
    bool clearSession = false,
    List<TeacherAttendanceModel>? history,
    double? monthlyPercentage,
    String? errorMessage,
  }) {
    return TeacherAttendanceState(
      status:             status            ?? this.status,
      activeSession:      clearSession ? null : (activeSession ?? this.activeSession),
      history:            history           ?? this.history,
      monthlyPercentage:  monthlyPercentage ?? this.monthlyPercentage,
      errorMessage:       errorMessage      ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, activeSession, history, monthlyPercentage, errorMessage];
}
