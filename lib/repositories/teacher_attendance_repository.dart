import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/teacher_attendance_model.dart';
import '../services/teacher_hive_service.dart';
import '../utils/attendance_date_validator.dart';

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
    required String sessionType,
  }) async {
    final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
    final now   = dbUtc.toLocal();
    final today = DateTime(now.year, now.month, now.day);

    // Time-based session guards
    if (sessionType == 'forenoon' && now.hour >= 12) {
      throw Exception('Cannot mark attendance for forenoon at this time.');
    }
    if (sessionType == 'afternoon' && now.hour < 12) {
      throw Exception('Cannot mark attendance for afternoon at this time.');
    }

    // Guard: block if an active session already exists in DB
    final existing = await fetchTodayActiveSession(teacherId, sessionType);
    if (existing != null) return existing;

    // Guard: block if a completed session already exists in DB
    final completed = await fetchTodayCompletedSession(teacherId, sessionType);
    if (completed != null) return completed;

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
      sessionType:    sessionType,
    );

    try {
      final inserted = await _supabase
          .from('teacher_attendance')
          .upsert(record.toInsertMap(), onConflict: 'teacher_id,attendance_date,session_type')
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
    final dbUtc    = await AttendanceDateValidator.getDatabaseUtcTime();
    final now      = dbUtc.toLocal();
    final duration = active.startTime != null
        ? now.difference(active.startTime!).inMinutes
        : 0;

    final updated  = active.copyWith(
      endTime:              now,
      status:               TeacherAttendanceStatus.completed,
      totalDurationMinutes: duration > 0 ? duration : 0,
    );

    // total_duration_minutes is a GENERATED column in Postgres -- it is
    // computed automatically from start_time/end_time. Never write to it.
    final updatePayload = {
      'end_time':          now.toUtc().toIso8601String(),
      'attendance_status': TeacherAttendanceStatus.completed.value,
    };

    final dateStr = active.attendanceDate.toIso8601String().split('T').first;

    // Resolve the row id. If the in-memory model lost it (e.g. restored
    // from offline cache), look it up by (teacher_id, attendanceDate, Active, sessionType).
    String? rowId = active.id;
    if (rowId == null) {
      try {
        final rows = await _supabase
            .from('teacher_attendance')
            .select('id')
            .eq('teacher_id', active.teacherId)
            .eq('attendance_date', dateStr)
            .eq('attendance_status', 'Active')
            .eq('session_type', active.sessionType)
            .limit(1);
        if (rows.isNotEmpty) {
          rowId = rows.first['id'] as String?;
        }
      } catch (_) {
        // ignore; handled below
      }
    }

    try {
      List<dynamic> result = [];
      if (rowId != null) {
        result = await _supabase
            .from('teacher_attendance')
            .update(updatePayload)
            .eq('id', rowId)
            .select();
      }

      // Fallback 1: Update by session query criteria if rowId update matched 0 rows
      if (result.isEmpty) {
        result = await _supabase
            .from('teacher_attendance')
            .update(updatePayload)
            .eq('teacher_id', active.teacherId)
            .eq('attendance_date', dateStr)
            .eq('attendance_status', 'Active')
            .eq('session_type', active.sessionType)
            .select();
      }

      // Fallback 2: Upsert full updated record if active row wasn't present in DB yet (e.g. offline punch-in)
      if (result.isEmpty) {
        result = await _supabase
            .from('teacher_attendance')
            .upsert(updated.toInsertMap(), onConflict: 'teacher_id,attendance_date,session_type')
            .select();
      }
    } catch (e) {
      // Persist for retry when online connection/sync completes
      await _hive.savePendingTeacherAttendance(updated.toInsertMap());
    }

    await _hive.clearActiveSession();
    return updated;
  }

  Future<TeacherAttendanceModel?> fetchTodayActiveSession(String teacherId, [String? sessionType]) async {
    try {
      final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
      final now   = dbUtc.toLocal();
      final today = now.toIso8601String().split('T').first;
      var query = _supabase
          .from('teacher_attendance')
          .select('*, subjects(name)')
          .eq('teacher_id', teacherId)
          .eq('attendance_date', today)
          .eq('attendance_status', 'Active');

      if (sessionType != null) {
        query = query.eq('session_type', sessionType);
      }
      
      final rows = await query.limit(1);

      if (rows.isEmpty) {
        await _hive.clearActiveSession();
        return null;
      }
      final session = TeacherAttendanceModel.fromMap(rows.first);

      // Auto-punch-out rule: if duration exceeds 4 hours (240 minutes), auto complete it
      if (session.startTime != null) {
        final elapsed = now.difference(session.startTime!).inMinutes;
        if (elapsed >= 240) {
          final autoEndTime = session.startTime!.add(const Duration(hours: 4));
          await _supabase
              .from('teacher_attendance')
              .update({
                'end_time': autoEndTime.toUtc().toIso8601String(),
                'attendance_status': TeacherAttendanceStatus.completed.value,
              })
              .eq('id', session.id!);
          await _hive.clearActiveSession();
          return null; // Active session automatically completed
        }
      }

      await _hive.saveActiveSession(Map<String, dynamic>.from(rows.first));
      return session;
    } catch (_) {
      // Offline: restore from Hive
      final cached = _hive.getActiveSession();
      if (cached == null) return null;
      try {
        final model = TeacherAttendanceModel.fromMap(cached);
        if (sessionType != null && model.sessionType != sessionType) {
          return null;
        }
        if (model.startTime != null) {
          final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
          final now   = dbUtc.toLocal();
          final elapsed = now.difference(model.startTime!).inMinutes;
          if (elapsed >= 240) {
            await _hive.clearActiveSession();
            return null;
          }
          return model;
        }
        return null;
      } catch (_) {
        return null;
      }
    }
  }

  // Fetch today's most recent completed session.
  Future<TeacherAttendanceModel?> fetchTodayCompletedSession(String teacherId, [String? sessionType]) async {
    final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
    final now   = dbUtc.toLocal();
    final type  = sessionType ?? (now.hour >= 12 ? 'afternoon' : 'forenoon');
    try {
      final today = now.toIso8601String().split('T').first;
      final rows  = await _supabase
          .from('teacher_attendance')
          .select('*, subjects(name)')
          .eq('teacher_id', teacherId)
          .eq('attendance_date', today)
          .eq('attendance_status', 'Completed')
          .eq('session_type', type)
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
      final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
      final now   = dbUtc.toLocal();
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
