import 'package:equatable/equatable.dart';
import '../../models/dummy_data.dart';
import '../../models/student_performance_model.dart';

enum StudentStatus { initial, loading, success, failure }

class StudentState extends Equatable {
  final StudentStatus status;
  final StudentInfo? studentInfo;
  final List<ExamSession> exams;
  final List<AttendanceRecord> attendance;
  final StudentPerformanceModel? performance;
  final String? errorMessage;

  const StudentState({
    this.status = StudentStatus.initial,
    this.studentInfo,
    this.exams = const [],
    this.attendance = const [],
    this.performance,
    this.errorMessage,
  });

  StudentState copyWith({
    StudentStatus? status,
    StudentInfo? studentInfo,
    List<ExamSession>? exams,
    List<AttendanceRecord>? attendance,
    StudentPerformanceModel? performance,
    String? errorMessage,
  }) {
    return StudentState(
      status: status ?? this.status,
      studentInfo: studentInfo ?? this.studentInfo,
      exams: exams ?? this.exams,
      attendance: attendance ?? this.attendance,
      performance: performance ?? this.performance,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    studentInfo,
    exams,
    attendance,
    performance,
    errorMessage,
  ];
}
