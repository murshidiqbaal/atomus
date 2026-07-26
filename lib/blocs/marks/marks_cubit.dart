import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/exam_marks_model.dart';
import '../../repositories/marks_entry_repository.dart';
import 'marks_state.dart';

class MarksCubit extends Cubit<MarksState> {
  final MarksEntryRepository _repo;
  MarksEntryRepository get repo => _repo;

  /// Tracks the active campus filter so that changeMarkDate() can re-apply it.
  String? _activeCampusId;

  MarksCubit({required MarksEntryRepository repository})
    : _repo = repository,
      super(const MarksState());

  Future<void> loadExams({
    required List<String> subjectIds,
    required List<String> batchIds,
    required List<String> courseIds,
    bool includeAllDates = false,
    DateTime? date,
    String? campusId,
  }) async {
    emit(state.copyWith(status: MarksLoadStatus.loading, saved: false));
    try {
      final exams = await _repo.fetchAssignedExams(
        subjectIds: subjectIds,
        batchIds: batchIds,
        courseIds: courseIds,
        includeAllDates: includeAllDates,
        date: date,
        campusId: campusId,
      );
      emit(state.copyWith(status: MarksLoadStatus.success, exams: exams));
    } catch (e) {
      emit(
        state.copyWith(
          status: MarksLoadStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> selectExam(TeacherExam exam, {DateTime? markDate, String? subjectId, String? campusId}) async {
    // For daily exams default to today; for regular exams default to
    // the exam's own date (or today as a fallback).
    final resolvedDate = markDate ??
        (exam.isDaily
            ? _today()
            : (exam.examDate ?? _today()));
    final resolvedSubjectId = exam.subjectId ?? subjectId;
    // Store campusId so changeMarkDate can re-use it.
    _activeCampusId = campusId;
    emit(
      state.copyWith(
        status: MarksLoadStatus.loading,
        selectedExam: exam,
        selectedMarkDate: resolvedDate,
        entries: [],
        saved: false,
      ),
    );
    try {
      final entries = await _repo.loadStudentsWithMarks(
        examId: exam.id,
        subjectId: resolvedSubjectId,
        batchId: exam.batchId,
        courseId: exam.courseId,
        totalMarks: exam.totalMarks,
        markDate: resolvedDate,
        campusId: campusId,
      );
      emit(state.copyWith(status: MarksLoadStatus.success, entries: entries));
    } catch (e) {
      emit(
        state.copyWith(
          status: MarksLoadStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Re-load the entries for the currently selected exam against a
  /// different mark_date. Used by the daily-exam date selector in the
  /// marks entry screen.
  Future<void> changeMarkDate(DateTime newDate) async {
    final exam = state.selectedExam;
    if (exam == null) return;
    emit(state.copyWith(
      status: MarksLoadStatus.loading,
      selectedMarkDate: newDate,
      entries: const [],
      saved: false,
    ));
    try {
      final entries = await _repo.loadStudentsWithMarks(
        examId: exam.id,
        subjectId: exam.subjectId,
        batchId: exam.batchId,
        courseId: exam.courseId,
        totalMarks: exam.totalMarks,
        markDate: newDate,
        campusId: _activeCampusId,
      );
      emit(state.copyWith(status: MarksLoadStatus.success, entries: entries));
    } catch (e) {
      emit(state.copyWith(
        status: MarksLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void updateMarks(String studentId, double? marks) {
    final updated = state.entries.map((e) {
      if (e.studentId != studentId) return e;
      return e.copyWith(marksObtained: marks, isAbsent: false);
    }).toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  void toggleAbsent(String studentId) {
    final updated = state.entries.map((e) {
      if (e.studentId != studentId) return e;
      return e.copyWith(isAbsent: !e.isAbsent, marksObtained: null);
    }).toList();
    emit(state.copyWith(entries: updated, saved: false));
  }

  void clearSelection() {
    emit(
      MarksState(
        status: MarksLoadStatus.success,
        exams: state.exams,
        selectedExam: null,
        selectedMarkDate: null,
        entries: const [],
        errorMessage: null,
        saved: false,
      ),
    );
  }

  Future<void> saveMarks({
    required List<String> subjectIds,
    required List<String> batchIds,
    required List<String> courseIds,
  }) async {
    if (state.entries.isEmpty) return;
    emit(state.copyWith(status: MarksLoadStatus.saving));
    try {
      await _repo.saveMarks(state.entries);
      final exams = await _repo.fetchAssignedExams(
        subjectIds: subjectIds,
        batchIds: batchIds,
        courseIds: courseIds,
        date: state.selectedMarkDate,
      );
      emit(
        state.copyWith(
          status: MarksLoadStatus.success,
          exams: exams,
          saved: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: MarksLoadStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> createExam({
    required String name,
    required DateTime date,
    required double totalMarks,
    required String batchId,
    required String subjectId,
    required List<String> subjectIds,
    required List<String> batchIds,
    required List<String> courseIds,
    String? courseId,
    DateTime? listDate,
    String? campusId,
  }) async {
    emit(state.copyWith(status: MarksLoadStatus.loading, saved: false));
    try {
      await _repo.createExam(
        name: name,
        date: date,
        totalMarks: totalMarks,
        batchId: batchId,
        subjectId: subjectId,
        courseId: courseId,
        campusId: campusId,
      );
      final exams = await _repo.fetchAssignedExams(
        subjectIds: subjectIds,
        batchIds: batchIds,
        courseIds: courseIds,
        date: listDate,
      );
      emit(
        state.copyWith(
          status: MarksLoadStatus.success,
          exams: exams,
          saved: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: MarksLoadStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> updateExam({
    required String examId,
    required String name,
    required DateTime date,
    required double totalMarks,
    required String batchId,
    required String subjectId,
    String? courseId,
    String? currentSubjectId,
    required List<String> subjectIds,
    required List<String> batchIds,
    required List<String> courseIds,
    DateTime? listDate,
  }) async {
    emit(state.copyWith(status: MarksLoadStatus.loading, saved: false));
    try {
      await _repo.updateExam(
        examId: examId,
        name: name,
        date: date,
        totalMarks: totalMarks,
        batchId: batchId,
        subjectId: subjectId,
        courseId: courseId,
        currentSubjectId: currentSubjectId,
      );
      final exams = await _repo.fetchAssignedExams(
        subjectIds: subjectIds,
        batchIds: batchIds,
        courseIds: courseIds,
        date: listDate,
      );
      emit(
        state.copyWith(
          status: MarksLoadStatus.success,
          exams: exams,
          saved: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: MarksLoadStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> deleteExam({
    required String examId,
    required String? subjectId,
    required List<String> subjectIds,
    required List<String> batchIds,
    required List<String> courseIds,
    DateTime? listDate,
  }) async {
    emit(state.copyWith(status: MarksLoadStatus.loading, saved: false));
    try {
      await _repo.deleteExam(examId, subjectId);
      final exams = await _repo.fetchAssignedExams(
        subjectIds: subjectIds,
        batchIds: batchIds,
        courseIds: courseIds,
        date: listDate,
      );
      emit(state.copyWith(status: MarksLoadStatus.success, exams: exams));
    } catch (e) {
      emit(
        state.copyWith(
          status: MarksLoadStatus.failure,
          errorMessage: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }
}
