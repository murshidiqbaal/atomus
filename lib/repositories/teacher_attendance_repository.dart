import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/teacher_attendance_model.dart';
import '../services/teacher_hive_service.dart';

class TeacherAttendanceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TeacherHiveService _hive;

  TeacherAttendanceRepository({required TeacherHiveService hive}) : _hive = hive;

  // Start a teacher attendance session. Prevents duplicate active sessions.
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

    // Guard: block if an active session already exists in DB
    final existing = await fetchTodayActiveSession(teacherId);
    if (existing != null) return existing;

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
      final saved = TeacherAttendanceModel.fromMap(inserted);
      await _hive.saveActiveSession(saved.toInsertMap()..['id'] = saved.id);
      return saved;
    } catch (_) {
      // Offline: persist to pending queue and active session cache
      await _hive.savePendingTeacherAttendance(record.toInsertMap());
      await _hive.saveActiveSession(record.toInsertMap());
      return record;
    }
  }

  // End the active session and clear from Hive.
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
              'end_time':               now.toIso8601String(),
              'attendance_status':      TeacherAttendanceStatus.completed.value,
              'total_duration_minutes': duration,
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

    await _hive.clearActiveSession();
    return updated;
  }

  // Fetch today's active session; falls back to Hive when offline.
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

      if (rows.isEmpty) {
        await _hive.clearActiveSession();
        return null;
      }
      final session = TeacherAttendanceModel.fromMap(rows.first);
      await _hive.saveActiveSession(Map<String, dynamic>.from(rows.first));
      return session;
    } catch (_) {
      // Offline: restore from Hive
      final cached = _hive.getActiveSession();
      if (cached == null) return null;
      try {
        return TeacherAttendanceModel.fromMap(cached);
      } catch (_) {
        return null;
      }
    }
  }

  // Fetch today's most recent completed session.
  Future<TeacherAttendanceModel?> fetchTodayCompletedSession(String teacherId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final rows  = await _supabase
          .from('teacher_attendance')
          .select('*, subjects(name)')
          .eq('teacher_id', teacherId)
          .eq('attendance_date', today)
          .eq('attendance_status', 'Completed')
          .order('end_time', ascending: false)
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
