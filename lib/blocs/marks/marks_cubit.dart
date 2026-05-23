import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/exam_marks_model.dart';
import '../../repositories/marks_entry_repository.dart';
import 'marks_state.dart';

class MarksCubit extends Cubit<MarksState> {
  final MarksEntryRepository _repo;
  MarksEntryRepository get repo => _repo;

  MarksCubit({required MarksEntryRepository repository})
      : _repo = repository,
        super(const MarksState());

  Future<void> loadExams({
    required List<String> subjectIds,
    String? batchId,
  }) async {
    emit(state.copyWith(status: MarksLoadStatus.loading));
    try {
      final exams = await _repo.fetchAssignedExams(
        subjectIds: subjectIds,
        batchId:    batchId,
      );
      emit(state.copyWith(status: MarksLoadStatus.success, exams: exams));
    } catch (e) {
      emit(state.copyWith(
        status:       MarksLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> selectExam(TeacherExam exam) async {
    if (exam.batchId == null) return;
    emit(state.copyWith(
      status:       MarksLoadStatus.loading,
      selectedExam: exam,
      entries:      [],
      saved:        false,
    ));
    try {
      final entries = await _repo.loadStudentsWithMarks(
        examId:     exam.id,
        subjectId:  exam.subjectId,
        batchId:    exam.batchId!,
        totalMarks: exam.totalMarks,
      );
      emit(state.copyWith(
        status:  MarksLoadStatus.success,
        entries: entries,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       MarksLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
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
    emit(state.copyWith(selectedExam: null, entries: []));
  }

  Future<void> saveMarks() async {
    if (state.entries.isEmpty) return;
    emit(state.copyWith(status: MarksLoadStatus.saving));
    try {
      await _repo.saveMarks(state.entries);
      emit(state.copyWith(status: MarksLoadStatus.success, saved: true));
    } catch (e) {
      emit(state.copyWith(
        status:       MarksLoadStatus.failure,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> createExam({
    required String name,
    required DateTime date,
    required double totalMarks,
    required String batchId,
    required String subjectId,
    required List<String> subjectIds,
    String? courseId,
  }) async {
    emit(state.copyWith(status: MarksLoadStatus.loading));
    try {
      await _repo.createExam(
        name: name,
        date: date,
        totalMarks: totalMarks,
        batchId: batchId,
        subjectId: subjectId,
        courseId: courseId,
      );
      final exams = await _repo.fetchAssignedExams(subjectIds: subjectIds);
      emit(state.copyWith(status: MarksLoadStatus.success, exams: exams, saved: true));
    } catch (e) {
      emit(state.copyWith(
        status:       MarksLoadStatus.failure,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> deleteExam({
    required String examId,
    required String subjectId,
    required List<String> subjectIds,
  }) async {
    emit(state.copyWith(status: MarksLoadStatus.loading));
    try {
      await _repo.deleteExam(examId, subjectId);
      final exams = await _repo.fetchAssignedExams(subjectIds: subjectIds);
      emit(state.copyWith(status: MarksLoadStatus.success, exams: exams));
    } catch (e) {
      emit(state.copyWith(
        status:       MarksLoadStatus.failure,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }
}
