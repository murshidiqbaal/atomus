import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/daily_report_model.dart';
import '../../repositories/daily_report_repository.dart';
import 'daily_report_state.dart';

class DailyReportCubit extends Cubit<DailyReportState> {
  final DailyReportRepository _repo;

  DailyReportCubit({required DailyReportRepository repository})
    : _repo = repository,
      super(const DailyReportState());

  /// Load students and their reports for the selected batch/subject (or course-level) and date
  Future<void> loadStudentsAndReports({
    String? batchId,
    String? subjectId,
    required DateTime date,
    List<String>? courseIds,
    String? campusId,
  }) async {
    emit(state.copyWith(status: DailyReportStatus.loading));
    try {
      List<Map<String, dynamic>> studentList = [];
      if (batchId != null && batchId.isNotEmpty) {
        studentList = await _repo.fetchStudents(
          batchId: batchId,
          campusId: campusId,
        );
      } else if (courseIds != null && courseIds.isNotEmpty) {
        studentList = await _repo.fetchStudentsForCourses(
          courseIds: courseIds,
          campusId: campusId,
        );
      }

      final Map<String, DailyReportModel> loadedReports = {};
      if (studentList.isNotEmpty) {
        final studentIds = studentList.map((s) => s['id'] as String).toList();
        final reportsList = await _repo.fetchReports(
          studentIds: studentIds,
          subjectId: subjectId,
          date: date,
        );
        for (final report in reportsList) {
          loadedReports[report.studentId] = report;
        }
      }

      emit(
        state.copyWith(
          status: DailyReportStatus.success,
          students: studentList,
          reports: loadedReports,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyReportStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Load daily class report and batch students
  Future<void> loadDailyClassReport({
    required String courseId,
    required String batchId,
    required String subjectId,
    required DateTime date,
    required String sessionType,
    String? campusId,
  }) async {
    emit(state.copyWith(status: DailyReportStatus.loading, clearLoadedClassReport: true));
    try {
      final studentList = await _repo.fetchStudentsForCourses(
        courseIds: [courseId],
        campusId: campusId,
      );

      final classReport = await _repo.fetchDailyClassReport(
        courseId: courseId,
        batchId: batchId,
        subjectId: subjectId,
        date: date,
        sessionType: sessionType,
      );

      emit(
        state.copyWith(
          status: DailyReportStatus.success,
          students: studentList,
          loadedClassReport: classReport,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyReportStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Save daily class report and bulk student reports
  Future<void> saveDailyClassReport({
    required String courseId,
    required String batchId,
    required String subjectId,
    required DateTime date,
    required String sessionType,
    required String teacherId,
    required String topicsCovered,
    String? homework,
    String? generalRemarks,
    required List<Map<String, dynamic>> studentReports,
  }) async {
    emit(state.copyWith(status: DailyReportStatus.saving));
    try {
      await _repo.saveDailyClassReport(
        courseId: courseId,
        batchId: batchId,
        subjectId: subjectId,
        date: date,
        sessionType: sessionType,
        teacherId: teacherId,
        topicsCovered: topicsCovered,
        homework: homework,
        generalRemarks: generalRemarks,
        studentReports: studentReports,
      );

      // Reload report details after saving
      final classReport = await _repo.fetchDailyClassReport(
        courseId: courseId,
        batchId: batchId,
        subjectId: subjectId,
        date: date,
        sessionType: sessionType,
      );

      emit(
        state.copyWith(
          status: DailyReportStatus.success,
          loadedClassReport: classReport,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyReportStatus.failure,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Save daily report
  Future<void> saveReport(DailyReportModel report) async {
    emit(state.copyWith(status: DailyReportStatus.saving));
    try {
      await _repo.saveReport(report);

      final updatedReports = Map<String, DailyReportModel>.from(state.reports);
      updatedReports[report.studentId] = report;

      emit(
        state.copyWith(
          status: DailyReportStatus.success,
          reports: updatedReports,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyReportStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Delete daily report
  Future<void> deleteReport({
    required String studentId,
    String? subjectId,
    required DateTime date,
  }) async {
    emit(state.copyWith(status: DailyReportStatus.saving));
    try {
      await _repo.deleteReport(
        studentId: studentId,
        subjectId: subjectId,
        date: date,
      );

      final updatedReports = Map<String, DailyReportModel>.from(state.reports);
      updatedReports.remove(studentId);

      emit(
        state.copyWith(
          status: DailyReportStatus.success,
          reports: updatedReports,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyReportStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Fetch all reports for a student (used in student-facing IReportsScreen)
  Future<void> fetchReportsForCurrentStudent({
    required String studentId,
  }) async {
    emit(state.copyWith(status: DailyReportStatus.loading));
    try {
      final reports = await _repo.fetchAllReportsForStudent(
        studentId: studentId,
      );
      emit(
        state.copyWith(
          status: DailyReportStatus.success,
          studentReports: reports,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyReportStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Load historical class reports for the logged in teacher
  Future<void> loadClassReportsForTeacher(String teacherId) async {
    emit(state.copyWith(status: DailyReportStatus.loading));
    try {
      final reports = await _repo.fetchClassReportsForTeacher(teacherId);
      emit(
        state.copyWith(
          status: DailyReportStatus.success,
          classReports: reports,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyReportStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Fetch recent reports for a course (used on parent dashboard marquee)
  Future<void> fetchRecentReportsForCourse({
    required String courseId,
  }) async {
    emit(state.copyWith(status: DailyReportStatus.loading));
    try {
      final reports = await _repo.fetchRecentReportsForCourse(courseId: courseId);
      emit(
        state.copyWith(
          status: DailyReportStatus.success,
          courseReports: reports,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: DailyReportStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
