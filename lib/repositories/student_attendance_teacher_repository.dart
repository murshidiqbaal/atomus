import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student_attendance_entry_model.dart';
import '../services/teacher_hive_service.dart';

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
  }) async {
    final dateStr = date.toIso8601String().split('T').first;

    // Fetch students
    List<Map<String, dynamic>> students;
    try {
      final rows = await _supabase
          .from('students')
          .select(
              'id, full_name, roll_number, admission_number, profile_photo_drive_id, batch_id, course_id')
          .eq('batch_id', batchId)
          .order('roll_number', ascending: true);
      students = (rows as List).map((r) => Map<String, dynamic>.from(r)).toList();
      await _hive.cacheStudents(batchId, students);
    } catch (_) {
      students = _hive.getCachedStudents(batchId) ?? [];
    }

    if (students.isEmpty) return [];

    // Fetch existing attendance records for today
    Map<String, Map<String, dynamic>> existingMap = {};
    try {
      final existing = await _supabase
          .from('attendance')
          .select('id, student_id, status, marked_by, marked_at')
          .eq('subject_id', subjectId)
          .eq('attendance_date', dateStr);
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
  Future<void> saveAttendance({
    required String teacherId,
    required List<StudentAttendanceEntry> entries,
    String? teacherName,
    String? campusId,
  }) async {
    final payload = entries
        .map((e) => e.toUpsertMap(
              teacherId,
              teacherName: teacherName,
              campusId: campusId,
            ))
        .toList();

    try {
      await _supabase.from('attendance').upsert(payload);
    } catch (_) {
      final batchKey = entries.isNotEmpty ? entries.first.batchId ?? 'unknown' : 'unknown';
      await _hive.savePendingStudentAttendance(batchKey, payload);
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
      final to   = DateTime(month.year, month.month + 1, 0);
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
