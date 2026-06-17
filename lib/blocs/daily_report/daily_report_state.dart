import '../../models/daily_report_model.dart';

enum DailyReportStatus { initial, loading, success, failure, saving }

class DailyReportState {
  final DailyReportStatus status;
  final List<Map<String, dynamic>> students;
  final Map<String, DailyReportModel> reports; // Key: studentId, Value: report
  final List<DailyReportModel> studentReports; // For student-facing IReportsScreen
  final String? errorMessage;

  const DailyReportState({
    this.status = DailyReportStatus.initial,
    this.students = const [],
    this.reports = const {},
    this.studentReports = const [],
    this.errorMessage,
  });

  DailyReportState copyWith({
    DailyReportStatus? status,
    List<Map<String, dynamic>>? students,
    Map<String, DailyReportModel>? reports,
    List<DailyReportModel>? studentReports,
    String? errorMessage,
  }) {
    return DailyReportState(
      status: status ?? this.status,
      students: students ?? this.students,
      reports: reports ?? this.reports,
      studentReports: studentReports ?? this.studentReports,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
