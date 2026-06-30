import '../../models/daily_report_model.dart';

enum DailyReportStatus { initial, loading, success, failure, saving }

class DailyReportState {
  final DailyReportStatus status;
  final List<Map<String, dynamic>> students;
  final Map<String, DailyReportModel> reports; // Key: studentId, Value: report
  final List<DailyReportModel> studentReports; // For student-facing IReportsScreen
  final List<DailyReportModel> courseReports; // For parent dashboard marquee
  final Map<String, dynamic>? loadedClassReport; // For the new bulk class report flow
  final List<Map<String, dynamic>> classReports; // For teacher historical class reports
  final String? errorMessage;

  const DailyReportState({
    this.status = DailyReportStatus.initial,
    this.students = const [],
    this.reports = const {},
    this.studentReports = const [],
    this.courseReports = const [],
    this.loadedClassReport,
    this.classReports = const [],
    this.errorMessage,
  });

  DailyReportState copyWith({
    DailyReportStatus? status,
    List<Map<String, dynamic>>? students,
    Map<String, DailyReportModel>? reports,
    List<DailyReportModel>? studentReports,
    List<DailyReportModel>? courseReports,
    Map<String, dynamic>? loadedClassReport,
    bool clearLoadedClassReport = false,
    List<Map<String, dynamic>>? classReports,
    String? errorMessage,
  }) {
    return DailyReportState(
      status: status ?? this.status,
      students: students ?? this.students,
      reports: reports ?? this.reports,
      studentReports: studentReports ?? this.studentReports,
      courseReports: courseReports ?? this.courseReports,
      loadedClassReport: clearLoadedClassReport ? null : (loadedClassReport ?? this.loadedClassReport),
      classReports: classReports ?? this.classReports,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
