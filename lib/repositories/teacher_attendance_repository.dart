import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/teacher_attendance_model.dart';
import '../services/teacher_hive_service.dart';
import '../utils/attendance_date_validator.dart';

class TeacherAttendanceRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TeacherHiveService _hive;

  TeacherAttendanceRepository({required TeacherHiveService hive}) : _hive = hive;

  /// Start a teacher attendance session.
  /// Strictly prevents creating another session if an open session currently exists.
  Future<TeacherAttendanceModel> startSession({
    required String teacherId,
    required String? campusId,
    required String? subjectId,
    required String? courseId,
    required String? batchId,
    required double? latitude,
    required double? longitude,
    String? sessionType,
  }) async {
    final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
    final now   = dbUtc.toLocal();
    final today = DateTime(now.year, now.month, now.day);

    // Guard: block if an active (open) session already exists
    final active = await fetchTodayActiveSession(teacherId);
    if (active != null) {
      throw Exception('OPEN_SESSION_EXISTS: You already have an active attendance session. Please punch out before starting another session.');
    }

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
      sessionType:    sessionType ?? 'session',
    );

    // Try RPC first for atomic DB-level validation
    try {
      final response = await _supabase.rpc('fn_teacher_punch_in', params: {
        'p_teacher_id': teacherId,
        'p_campus_id': campusId,
        'p_subject_id': subjectId,
        'p_course_id': courseId,
        'p_batch_id': batchId,
        'p_latitude': latitude,
        'p_longitude': longitude,
      });

      if (response != null && (response as List).isNotEmpty) {
        final saved = TeacherAttendanceModel.fromMap(response.first as Map<String, dynamic>);
        await _hive.saveActiveSession(saved.toInsertMap()..['id'] = saved.id);
        return saved;
      }
    } catch (rpcErr) {
      final errStr = rpcErr.toString();
      if (errStr.contains('OPEN_SESSION_EXISTS')) {
        rethrow;
      }
      // RPC not deployed yet or offline: fallback to standard query
    }

    try {
      final inserted = await _supabase
          .from('teacher_attendance')
          .insert(record.toInsertMap())
          .select()
          .single();
      final saved = TeacherAttendanceModel.fromMap(inserted);
      await _hive.saveActiveSession(saved.toInsertMap()..['id'] = saved.id);
      return saved;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('PostgrestException') ||
          errStr.contains('constraint') ||
          errStr.contains('violates') ||
          errStr.contains('OPEN_SESSION_EXISTS')) {
        rethrow;
      }
      // Offline fallback: persist to pending queue and active session cache
      await _hive.savePendingTeacherAttendance(record.toInsertMap());
      await _hive.saveActiveSession(record.toInsertMap());
      return record;
    }
  }

  /// End the active session and clear active state from Hive.
  Future<TeacherAttendanceModel> endSession(TeacherAttendanceModel active) async {
    final dbUtc    = await AttendanceDateValidator.getDatabaseUtcTime();
    final now      = dbUtc.toLocal();
    final duration = active.startTime != null
        ? now.difference(active.startTime!).inMinutes
        : 0;

    final updated = active.copyWith(
      endTime:              now,
      status:               TeacherAttendanceStatus.completed,
      totalDurationMinutes: duration > 0 ? duration : 0,
    );

    // Try RPC for atomic server-side punch out
    try {
      final response = await _supabase.rpc('fn_teacher_punch_out', params: {
        'p_teacher_id': active.teacherId,
        'p_session_id': active.id,
      });
      if (response != null && (response as List).isNotEmpty) {
        await _hive.clearActiveSession();
        return TeacherAttendanceModel.fromMap(response.first as Map<String, dynamic>);
      }
    } catch (_) {
      // RPC fallback to direct query
    }

    final updatePayload = {
      'end_time':          now.toUtc().toIso8601String(),
      'attendance_status': TeacherAttendanceStatus.completed.value,
    };

    String? rowId = active.id;
    try {
      List<dynamic> result = [];
      if (rowId != null) {
        result = await _supabase
            .from('teacher_attendance')
            .update(updatePayload)
            .eq('id', rowId)
            .select();
      }

      if (result.isEmpty) {
        final dateStr = active.attendanceDate.toIso8601String().split('T').first;
        result = await _supabase
            .from('teacher_attendance')
            .update(updatePayload)
            .eq('teacher_id', active.teacherId)
            .eq('attendance_date', dateStr)
            .filter('end_time', 'is', null)
            .select();
      }

      if (result.isEmpty) {
        result = await _supabase
            .from('teacher_attendance')
            .upsert(updated.toInsertMap())
            .select();
      }
    } catch (e) {
      await _hive.savePendingTeacherAttendance(updated.toInsertMap());
    }

    await _hive.clearActiveSession();
    return updated;
  }

  /// Fetch teacher's currently OPEN session (punch_out / end_time IS NULL).
  Future<TeacherAttendanceModel?> fetchTodayActiveSession(String teacherId, [String? sessionType]) async {
    try {
      final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
      final now   = dbUtc.toLocal();
      final today = now.toIso8601String().split('T').first;

      final rows = await _supabase
          .from('teacher_attendance')
          .select('*, subjects(name)')
          .eq('teacher_id', teacherId)
          .eq('attendance_date', today)
          .filter('end_time', 'is', null)
          .order('start_time', ascending: false)
          .limit(1);

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
          return null;
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
        if (model.startTime != null && model.endTime == null) {
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

  /// Alias for fetchTodayActiveSession.
  Future<TeacherAttendanceModel?> fetchOpenSession(String teacherId) =>
      fetchTodayActiveSession(teacherId);

  /// Fetch ALL attendance sessions for today, sorted chronologically.
  Future<List<TeacherAttendanceModel>> fetchTodaySessions(String teacherId) async {
    try {
      final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
      final now   = dbUtc.toLocal();
      final today = now.toIso8601String().split('T').first;

      final rows = await _supabase
          .from('teacher_attendance')
          .select('*, subjects(name)')
          .eq('teacher_id', teacherId)
          .eq('attendance_date', today)
          .order('start_time', ascending: true);

      return (rows as List)
          .map((r) => TeacherAttendanceModel.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch today's most recent completed session (legacy compatibility helper).
  Future<TeacherAttendanceModel?> fetchTodayCompletedSession(String teacherId, [String? sessionType]) async {
    final todaySessions = await fetchTodaySessions(teacherId);
    final completed = todaySessions.where((s) => s.isCompleted).toList();
    if (completed.isEmpty) return null;
    return completed.last;
  }

  /// History for a date range.
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
          .order('attendance_date', ascending: false)
          .order('start_time', ascending: true);

      return (rows as List)
          .map((r) => TeacherAttendanceModel.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Calculate monthly attendance percentage where a day is present if >= 1 session was completed.
  Future<double> fetchMonthlyAttendancePercentage(String teacherId) async {
    try {
      final dbUtc = await AttendanceDateValidator.getDatabaseUtcTime();
      final now   = dbUtc.toLocal();
      final from  = DateTime(now.year, now.month, 1);
      final to    = DateTime(now.year, now.month + 1, 0);

      final rows = await _supabase
          .from('teacher_attendance')
          .select('attendance_date, attendance_status, end_time')
          .eq('teacher_id', teacherId)
          .gte('attendance_date', from.toIso8601String().split('T').first)
          .lte('attendance_date', to.toIso8601String().split('T').first);

      if (rows.isEmpty) return 0;

      final Set<String> presentDays = {};
      final Set<String> totalDays   = {};

      for (final r in rows as List) {
        final dateStr = r['attendance_date'] as String;
        totalDays.add(dateStr);
        final status = r['attendance_status'] as String?;
        final endTime = r['end_time'];
        if (status == 'Completed' || endTime != null) {
          presentDays.add(dateStr);
        }
      }

      if (totalDays.isEmpty) return 0;
      return (presentDays.length / totalDays.length) * 100;
    } catch (_) {
      return 0;
    }
  }

  /// Calculate today's total completed working duration in minutes.
  Future<int> fetchTodayTotalMinutes(String teacherId) async {
    final todaySessions = await fetchTodaySessions(teacherId);
    int total = 0;
    for (final s in todaySessions) {
      if (s.isCompleted && s.totalDurationMinutes != null) {
        total += s.totalDurationMinutes!;
      }
    }
    return total;
  }
}
