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

  // Realtime subscriptions
  StreamSubscription? _attendanceSub;
  StreamSubscription? _subjectAttendanceSub;
  StreamSubscription? _marksSub;
  String? _subscribedStudentId;

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

      // Try database calculation and upsert, fallback to local memory calculation if offline/failed
      StudentAcademicPerformanceModel? performance;
      if (info != null) {
        try {
          performance =
              await StudentPerformanceService.calculateAndStorePerformance(
                info.id,
              );
          // Set up real-time reactive streams
          _setupRealtimeStreams(info.id);
        } catch (dbError) {
          print(
            'Database performance calculation/connection failed. Using local fallback. Error: $dbError',
          );
          performance =
              StudentPerformanceService.calculatePerformanceLocalFallback(
                attendance,
                exams,
              );
        }
      }

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

      // Only recalculate performance locally when user is applying a
      // subject/course filter (e.g. subject-specific calendar view).
      // For general month navigation, keep the DB-calculated performance
      // from LoadStudentData to avoid the "flash of wrong values" bug.
      final bool isFilteredView =
          event.subjectId != null || event.courseId != null;

      final performance = isFilteredView
          ? StudentPerformanceService.calculatePerformanceLocalFallback(
              attendance,
              state.exams,
            )
          : state.performance;

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

  /// Establishes Supabase streams on student changes for instant reactive dashboard sync
  void _setupRealtimeStreams(String studentId) {
    if (_subscribedStudentId == studentId) return; // Already subscribed

    _cancelRealtimeStreams();
    _subscribedStudentId = studentId;

    final client = Supabase.instance.client;

    try {
      // 1. Listen to 'attendance' updates
      _attendanceSub = client
          .from('attendance')
          .stream(primaryKey: ['id'])
          .eq('student_id', studentId)
          .listen(
            (_) {
              print('Supabase Realtime: Attendance changed. Syncing...');
              add(LoadStudentData());
            },
            onError: (e) {
              print('Attendance Realtime Stream error: $e');
            },
          );
    } catch (e) {
      print('Failed to setup Realtime Attendance Stream: $e');
    }

    try {
      // 2. Listen to 'subject_attendance' updates
      _subjectAttendanceSub = client
          .from('subject_attendance')
          .stream(primaryKey: ['id'])
          .eq('student_id', studentId)
          .listen(
            (_) {
              print(
                'Supabase Realtime: Subject Attendance changed. Syncing...',
              );
              add(LoadStudentData());
            },
            onError: (e) {
              print('Subject Attendance Realtime Stream error: $e');
            },
          );
    } catch (e) {
      print('Failed to setup Realtime Subject Attendance Stream: $e');
    }

    try {
      // 3. Listen to 'marks' updates
      _marksSub = client
          .from('marks')
          .stream(primaryKey: ['id'])
          .eq('student_id', studentId)
          .listen(
            (_) {
              print('Supabase Realtime: Marks changed. Syncing...');
              add(LoadStudentData());
            },
            onError: (e) {
              print('Marks Realtime Stream error: $e');
            },
          );
    } catch (e) {
      print('Failed to setup Realtime Marks Stream: $e');
    }
  }

  void _cancelRealtimeStreams() {
    _attendanceSub?.cancel();
    _subjectAttendanceSub?.cancel();
    _marksSub?.cancel();
    _subscribedStudentId = null;
  }

  @override
  Future<void> close() {
    _cancelRealtimeStreams();
    return super.close();
  }
}
