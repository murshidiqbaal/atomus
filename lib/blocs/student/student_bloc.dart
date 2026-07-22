import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dummy_data.dart';
import '../../models/student_performance_model.dart';
import '../../repositories/student_repository.dart';
import '../../services/student_hive_service.dart';
import '../../services/student_performance_service.dart';
import 'student_event.dart';
import 'student_state.dart';

class StudentBloc extends Bloc<StudentEvent, StudentState> {
  final StudentRepository studentRepository;
  final StudentHiveService _hiveService;

  // Realtime subscriptions
  StreamSubscription? _attendanceSub;
  StreamSubscription? _subjectAttendanceSub;
  StreamSubscription? _marksSub;
  String? _subscribedStudentId;

  StudentBloc({
    required this.studentRepository,
    StudentHiveService? hiveService,
  }) : _hiveService = hiveService ?? StudentHiveService(),
       super(const StudentState()) {
    on<LoadStudentData>(_onLoadStudentData);
    on<LoadAttendance>(_onLoadAttendance);
    on<UpdateStudentProfile>(_onUpdateStudentProfile);
  }

  Future<void> _onLoadStudentData(
    LoadStudentData event,
    Emitter<StudentState> emit,
  ) async {
    emit(state.copyWith(status: StudentStatus.loading));

    // ── 1. Show cached data instantly ────────────────────────────
    try {
      await _hiveService.initBoxes();
      final cachedInfo = _hiveService.getCachedStudentInfo();
      final cachedExams = _hiveService.getCachedExamSessions();

      if (cachedInfo != null) {
        final info = StudentInfo.fromMap(cachedInfo);
        final exams = cachedExams != null
            ? cachedExams
                .map((e) => ExamSession.fromMap(e, _parseExamMarks(e)))
                .toList()
            : <ExamSession>[];

        // Load cached attendance
        List<AttendanceRecord> cachedAttendance = [];
        final cachedAttData = _hiveService.getCachedAttendance('all');
        if (cachedAttData != null) {
          cachedAttendance =
              cachedAttData.map((e) => AttendanceRecord.fromMap(e)).toList();
        }

        emit(state.copyWith(
          status: StudentStatus.success,
          studentInfo: info,
          exams: exams,
          attendance: cachedAttendance,
          isFromCache: true,
        ));
      }
    } catch (e) {
      print('StudentBloc: Cache read failed (non-fatal): $e');
    }

    // ── 2. Fetch fresh data from Supabase ────────────────────────
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

      // ── 3. Cache the fresh data ────────────────────────────────
      try {
        if (info != null) {
          await _hiveService.saveStudentInfo({
            'id': info.id,
            'full_name': info.fullName,
            'admission_number': info.admissionNumber,
            'roll_number': info.rollNumber,
            'gender': info.gender,
            'date_of_birth': info.dateOfBirth,
            'grade': info.grade,
            'attendance_percentage': info.attendancePercentage,
            'progress_status': info.progressStatus,
            'email': info.email,
            'phone_number': info.phoneNumber,
            'relationship': info.relationship,
            'profile_photo_drive_id': info.profilePhotoDriveId,
            'course_id': info.courseId,
            'campus_id': info.campusId,
            'campus_name': info.campusName,
            'payment_qr_url': info.paymentQrUrl,
            'payment_qr_drive_id': info.paymentQrDriveId,
          });
        }
        // Cache attendance as raw maps for simplicity
        if (attendance.isNotEmpty) {
          await _hiveService.saveAttendance(
            'all',
            attendance
                .map((a) => {
                      'id': a.id,
                      'student_id': a.studentId,
                      'batch_id': a.batchId,
                      'course_id': a.courseId,
                      'subject_id': a.subjectId,
                      'attendance_date': a.date.toIso8601String(),
                      'status': a.status,
                      'period_number': a.periodNumber,
                      'attendance_marker_name': a.markerName,
                      'attendance_marker_role': a.markerRole,
                      'subject_name': a.subjectName,
                    })
                .toList(),
          );
        }
      } catch (cacheError) {
        print('StudentBloc: Cache write failed (non-fatal): $cacheError');
      }

      emit(
        state.copyWith(
          status: StudentStatus.success,
          studentInfo: info,
          exams: exams,
          attendance: attendance,
          performance: performance,
          isFromCache: false,
        ),
      );
    } catch (e) {
      // If we already have cached data displayed, keep it
      if (state.studentInfo != null) {
        print('StudentBloc: Network fetch failed, keeping cached data: $e');
        emit(state.copyWith(
          status: StudentStatus.success,
          isFromCache: true,
          errorMessage: 'Using cached data. Could not refresh: $e',
        ));
      } else {
        emit(
          state.copyWith(
            status: StudentStatus.failure,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  /// Parse exam marks from a cached exam session map.
  List<ExamMark> _parseExamMarks(Map<String, dynamic> examMap) {
    final subjectsList = examMap['_cached_subjects'] as List?;
    if (subjectsList == null) return [];
    return subjectsList
        .map((s) => ExamMark.fromMap(s as Map<String, dynamic>))
        .toList();
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
