import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dummy_data.dart';
import '../../models/student_performance_model.dart';
import '../../repositories/student_repository.dart';
import '../../services/student_performance_service.dart';
import 'student_event.dart';
import 'student_state.dart';

class StudentBloc extends Bloc<StudentEvent, StudentState> {
  final StudentRepository studentRepository;

  StudentBloc({required this.studentRepository}) : super(const StudentState()) {
    on<LoadStudentData>(_onLoadStudentData);
    on<LoadAttendance>(_onLoadAttendance);
    on<UpdateStudentProfile>(_onUpdateStudentProfile);
  }

  Future<void> _onLoadStudentData(
    LoadStudentData event,
    Emitter<StudentState> emit,
  ) async {
    emit(state.copyWith(status: StudentStatus.loading));
    try {
      final info = await studentRepository.getStudentInfo();
      
      List<ExamSession> exams = [];
      if (info != null) {
        exams = await studentRepository.getExamSessions(info.id);
      }

      List<AttendanceRecord> attendance = [];
      if (info != null) {
        DateTime? start;
        DateTime? end;
        if (event.month != null) {
          start = DateTime(event.month!.year, event.month!.month, 1);
          end = DateTime(event.month!.year, event.month!.month + 1, 0);
        }
        attendance = await studentRepository.getAttendance(
          studentId: info.id,
          startDate: start,
          endDate: end,
        );
      }

      final performance = info != null
          ? StudentPerformanceService.calculatePerformance(attendance, exams)
          : null;

      emit(
        state.copyWith(
          status: StudentStatus.success,
          studentInfo: info,
          exams: exams,
          attendance: attendance,
          performance: performance,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onLoadAttendance(
    LoadAttendance event,
    Emitter<StudentState> emit,
  ) async {
    if (state.studentInfo == null) return;

    emit(state.copyWith(status: StudentStatus.loading));
    try {
      final attendance = await studentRepository.getAttendance(
        studentId: state.studentInfo!.id,
        startDate: event.startDate,
        endDate: event.endDate,
        courseId: event.courseId,
        subjectId: event.subjectId,
      );

      final performance = StudentPerformanceService.calculatePerformance(
        attendance,
        state.exams,
      );

      emit(
        state.copyWith(
          status: StudentStatus.success,
          attendance: attendance,
          performance: performance,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdateStudentProfile(
    UpdateStudentProfile event,
    Emitter<StudentState> emit,
  ) async {
    try {
      await studentRepository.updateStudent(event.student);
      // Reload data to ensure state is in sync with DB
      add(LoadStudentData());
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}

