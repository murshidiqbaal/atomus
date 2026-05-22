import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/teacher_attendance_model.dart';
import '../services/teacher_hive_service.dart';

class TeacherAttendanceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TeacherHiveService _hive;

  TeacherAttendanceRepository({required TeacherHiveService hive}) : _hive = hive;

  // Start a teacher attendance session. Returns the created record.
  Future<TeacherAttendanceModel> startSession({
    required String teacherId,
    required String? campusId,
    required String? subjectId,
    required String? courseId,
    required String? batchId,
    required double? latitude,
    required double? longitude,
  }) async {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final record = TeacherAttendanceModel(
      teacherId:      teacherId,
      campusId:       campusId,
      subjectId:      subjectId,
      courseId:       courseId,
      batchId:        batchId,
      attendanceDate: today,
      startTime:      now,
      latitude:       latitude,
      longitude:      longitude,
      status:         TeacherAttendanceStatus.active,
    );

    try {
      final inserted = await _supabase
          .from('teacher_attendance')
          .upsert(record.toInsertMap())
          .select()
          .single();
      return TeacherAttendanceModel.fromMap(inserted);
    } catch (_) {
      // Offline: queue for later sync
      await _hive.savePendingTeacherAttendance(record.toInsertMap());
      return record;
    }
  }

  // End the active session.
  Future<TeacherAttendanceModel> endSession(TeacherAttendanceModel active) async {
    final now      = DateTime.now();
    final duration = now.difference(active.startTime!).inMinutes;
    final updated  = active.copyWith(
      endTime:              now,
      status:               TeacherAttendanceStatus.completed,
      totalDurationMinutes: duration,
    );

    try {
      if (active.id != null) {
        await _supabase
            .from('teacher_attendance')
            .update({
              'end_time':          now.toIso8601String(),
              'attendance_status': TeacherAttendanceStatus.completed.value,
            })
            .eq('id', active.id!);
      } else {
        await _supabase
            .from('teacher_attendance')
            .upsert(updated.toInsertMap());
      }
    } catch (_) {
      await _hive.savePendingTeacherAttendance(updated.toInsertMap());
    }

    return updated;
  }

  // Fetch today's active session for the teacher, if any.
  Future<TeacherAttendanceModel?> fetchTodayActiveSession(String teacherId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final rows  = await _supabase
          .from('teacher_attendance')
          .select('*, subjects(name)')
          .eq('teacher_id', teacherId)
          .eq('attendance_date', today)
          .eq('attendance_status', 'Active')
          .limit(1);

      if (rows.isEmpty) return null;
      return TeacherAttendanceModel.fromMap(rows.first);
    } catch (_) {
      return null;
    }
  }

  // History for a date range.
  Future<List<TeacherAttendanceModel>> fetchHistory({
    required String teacherId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await _supabase
          .from('teacher_attendance')
          .select('*, subjects(name)')
          .eq('teacher_id', teacherId)
          .gte('attendance_date', from.toIso8601String().split('T').first)
          .lte('attendance_date', to.toIso8601String().split('T').first)
          .order('attendance_date', ascending: false);

      return (rows as List)
          .map((r) => TeacherAttendanceModel.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<double> fetchMonthlyAttendancePercentage(String teacherId) async {
    try {
      final now   = DateTime.now();
      final from  = DateTime(now.year, now.month, 1);
      final to    = DateTime(now.year, now.month + 1, 0);
      final rows  = await _supabase
          .from('teacher_attendance')
          .select('attendance_status')
          .eq('teacher_id', teacherId)
          .gte('attendance_date', from.toIso8601String().split('T').first)
          .lte('attendance_date', to.toIso8601String().split('T').first);

      if (rows.isEmpty) return 0;
      final total     = (rows as List).length;
      final completed = rows.where((r) =>
          r['attendance_status'] == 'Completed').length;
      return total > 0 ? (completed / total) * 100 : 0;
    } catch (_) {
      return 0;
    }
  }
}
