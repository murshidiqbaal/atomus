import 'package:equatable/equatable.dart';
import '../../models/teacher_attendance_model.dart';

enum TeacherAttendanceLoadStatus { initial, loading, success, failure }

class TeacherAttendanceState extends Equatable {
  final TeacherAttendanceLoadStatus status;
  final TeacherAttendanceModel? openSession;
  final List<TeacherAttendanceModel> todaySessions;
  final int todayTotalMinutes;
  final bool isPunchingIn;
  final bool isPunchingOut;
  final List<TeacherAttendanceModel> history;
  final double monthlyPercentage;
  final String? errorMessage;

  const TeacherAttendanceState({
    this.status = TeacherAttendanceLoadStatus.initial,
    this.openSession,
    this.todaySessions = const [],
    this.todayTotalMinutes = 0,
    this.isPunchingIn = false,
    this.isPunchingOut = false,
    this.history = const [],
    this.monthlyPercentage = 0,
    this.errorMessage,
  });

  // Backward compatibility getters
  TeacherAttendanceModel? get activeSession => openSession;
  TeacherAttendanceModel? get completedSession {
    final completed = todaySessions.where((s) => s.isCompleted).toList();
    return completed.isNotEmpty ? completed.last : null;
  }
  bool get hasActiveSession => openSession != null && openSession!.isActive;
  bool get hasOpenSession => hasActiveSession;

  TeacherAttendanceState copyWith({
    TeacherAttendanceLoadStatus? status,
    TeacherAttendanceModel? openSession,
    bool clearOpenSession = false,
    List<TeacherAttendanceModel>? todaySessions,
    int? todayTotalMinutes,
    bool? isPunchingIn,
    bool? isPunchingOut,
    List<TeacherAttendanceModel>? history,
    double? monthlyPercentage,
    String? errorMessage,
    // Legacy support params
    TeacherAttendanceModel? activeSession,
    bool clearSession = false,
    bool clearCompleted = false,
    TeacherAttendanceModel? completedSession,
    String? sessionType,
  }) {
    return TeacherAttendanceState(
      status:            status            ?? this.status,
      openSession:       (clearOpenSession || clearSession)
                             ? null
                             : (openSession ?? activeSession ?? this.openSession),
      todaySessions:     todaySessions     ?? this.todaySessions,
      todayTotalMinutes: todayTotalMinutes ?? this.todayTotalMinutes,
      isPunchingIn:      isPunchingIn      ?? this.isPunchingIn,
      isPunchingOut:     isPunchingOut     ?? this.isPunchingOut,
      history:           history           ?? this.history,
      monthlyPercentage: monthlyPercentage ?? this.monthlyPercentage,
      errorMessage:      errorMessage      ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        openSession,
        todaySessions,
        todayTotalMinutes,
        isPunchingIn,
        isPunchingOut,
        history,
        monthlyPercentage,
        errorMessage,
      ];
}
