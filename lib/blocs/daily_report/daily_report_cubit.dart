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
}
