import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student_attendance_entry_model.dart';
import '../services/security_validation_service.dart';
import '../services/teacher_hive_service.dart';
import '../utils/attendance_date_validator.dart';


class StudentAttendanceTeacherRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TeacherHiveService _hive;

  StudentAttendanceTeacherRepository({required TeacherHiveService hive})
    : _hive = hive;

  /// Load students for a batch with any existing attendance for today/given date.
  Future<List<StudentAttendanceEntry>> loadStudentsWithAttendance({
    required String subjectId,
    required String batchId,
    required DateTime date,
    String? courseId,
    String? campusId,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;

    // Special Batches Fallback Logic
    bool useCohortFallback = false;
    String? resolvedCourseId = courseId;

    try {
      final batchData = await _supabase
          .from('batches')
          .select('name, course_id')
          .eq('id', batchId)
          .maybeSingle();
      if (batchData != null) {
        final name = (batchData['name'] as String? ?? '').toLowerCase();
        resolvedCourseId ??= batchData['course_id'] as String?;
        if (name.contains('any') ||
            name.contains('morning') ||
            name.contains('evening') ||
            name.contains('afternoon')) {
          useCohortFallback = true;
        }
      }
    } catch (_) {}

    // Fetch students
    List<Map<String, dynamic>> students;
    try {
      var query = _supabase
          .from('students')
          .select(
            'id, full_name, roll_number, admission_number, profile_photo_drive_id, batch_id, course_id, campus_id',
          );

      if (batchId.isEmpty && resolvedCourseId != null) {
        // Course-level attendance: fetch all students in the course
        query = query.eq('course_id', resolvedCourseId);
      } else if (useCohortFallback && resolvedCourseId != null) {
        query = query.eq('course_id', resolvedCourseId);
      } else {
        query = query.eq('batch_id', batchId);
      }

      if (campusId != null && campusId.isNotEmpty) {
        query = query.eq('campus_id', campusId);
      }

      final rows = await query.order('roll_number', ascending: true);
      students = (rows as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      await _hive.cacheStudents(
        batchId.isEmpty ? resolvedCourseId ?? 'course' : batchId,
        students,
      );
    } catch (_) {
      students =
          _hive.getCachedStudents(
            batchId.isEmpty ? resolvedCourseId ?? 'course' : batchId,
          ) ??
          [];
    }

    if (students.isEmpty) return [];

    // Fetch existing attendance records for today
    Map<String, Map<String, dynamic>> existingMap = {};
    try {
      var query = _supabase
          .from('attendance')
          .select('id, student_id, status, marked_by, marked_at')
          .eq('attendance_date', dateStr);

      // Use courseId when subjectId is empty (course-level attendance)
      if (subjectId.isEmpty && resolvedCourseId != null) {
        query = query.eq('course_id', resolvedCourseId);
      } else {
        query = query.eq('subject_id', subjectId);
      }

      final existing = await query;
      for (final r in existing as List) {
        existingMap[(r as Map<String, dynamic>)['student_id'] as String] = r;
      }
    } catch (_) {}

    return students.map((s) {
      return StudentAttendanceEntry.fromStudentMap(
        s,
        subjectId: subjectId,
        date: date,
        existingRecord: existingMap[s['id'] as String],
      );
    }).toList();
  }

  /// Save all entries (upsert). Queues offline if network unavailable.
  Future<List<Map<String, dynamic>>> saveAttendance({
    required String teacherId,
    required List<StudentAttendanceEntry> entries,
    String? teacherName,
    String? campusId,
  }) async {
    if (entries.isEmpty) return [];

    final first = entries.first;
    final deviceTime = DateTime.now();
    final dbUtcTime = await AttendanceDateValidator.getDatabaseUtcTime();
    final convertedLocalDate = AttendanceDateValidator.convertToLocal(dbUtcTime);
    final dbToday = DateTime(convertedLocalDate.year, convertedLocalDate.month, convertedLocalDate.day);

    AttendanceDateValidator.logValidation(
      deviceTime: deviceTime,
      dbUtcTime: dbUtcTime,
      selectedDate: first.attendanceDate,
      convertedLocalDate: convertedLocalDate,
    );

    if (!AttendanceDateValidator.canSubmit(first.attendanceDate, dbToday)) {
      throw Exception('Attendance cannot be marked for future dates.');
    }

    // 2. Validate assignments in teacher_subjects, teacher_batches, teacher_courses
    await SecurityValidationService.validateTeacherAssignments(
      subjectId: first.subjectId,
      batchId: first.batchId ?? '',
      courseId: first.courseId ?? '',
    );

    final payload = entries
        .map(
          (e) => e.toUpsertMap(
            teacherId,
            teacherName: teacherName,
            campusId: campusId,
          ),
        )
        .toList();

    try {
      // Upsert mode. The unique index on (student_id, subject_id,
      // attendance_date) handles conflicts. Existing rows are updated.
      final result = await _supabase
          .from('attendance')
          .upsert(
            payload,
            onConflict: 'student_id,subject_id,attendance_date',
            ignoreDuplicates: false,
          )
          .select();

      if (result.isEmpty) {
        throw Exception(
          'No rows were written. The attendance for these students was '
          'already marked by another teacher or admin, or RLS blocked '
          'the insert. Refresh and try again.',
        );
      }
      return (result as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      if (e is PostgrestException) {
        final errStr = e.toString();
        if (errStr.contains('attendance_no_future_dates')) {
          throw Exception('Attendance cannot be marked for future dates.');
        }
      }
      // Queue for later retry, but surface the error so the cubit emits
      // failure and the user sees a SnackBar instead of a silent no-op.
      final batchKey = entries.first.batchId ?? 'unknown';
      await _hive.savePendingStudentAttendance(batchKey, payload);
      rethrow;
    }
  }

  /// Monthly attendance summary for analytics (per student).
  Future<Map<String, int>> fetchMonthlyAbsenceCount({
    required String subjectId,
    required String batchId,
    required DateTime month,
  }) async {
    try {
      final from = DateTime(month.year, month.month, 1);
      final to = DateTime(month.year, month.month + 1, 0);
      final rows = await _supabase
          .from('attendance')
          .select('student_id, status')
          .eq('subject_id', subjectId)
          .gte('attendance_date', from.toIso8601String().split('T').first)
          .lte('attendance_date', to.toIso8601String().split('T').first);

      final counts = <String, int>{};
      for (final r in rows as List) {
        final row = r as Map<String, dynamic>;
        if (row['status'] == 'Absent') {
          final sid = row['student_id'] as String;
          counts[sid] = (counts[sid] ?? 0) + 1;
        }
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  /// Summary stats: present/absent/late/leave counts for a session.
  Map<String, int> summarise(List<StudentAttendanceEntry> entries) {
    final counts = <String, int>{
      'Present': 0,
      'Absent': 0,
      'Late': 0,
      'Leave': 0,
    };
    for (final e in entries) {
      final key = e.status.value;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }
}
