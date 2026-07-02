import 'package:supabase_flutter/supabase_flutter.dart';

/// RealtimeSyncService provides a structured wrapper around Supabase Realtime (WebSockets)
/// to stream list updates and listen to PostgreSQL CDC (Change Data Capture) changes
/// for tables: attendance, daily_class_reports, exams, expenses, overall_attendance,
/// student_academic_performance, subject_attendance, and teacher_attendance.
class RealtimeSyncService {
  final SupabaseClient _supabase;

  RealtimeSyncService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // 1. Generic Real-time Streams (List Sync)
  // ---------------------------------------------------------------------------

  /// Exposes a stream of records for the given table filtered by column/value.
  /// Emits an updated list whenever any row is inserted, updated, or deleted.
  Stream<List<Map<String, dynamic>>> getTableStream({
    required String tableName,
    required List<String> primaryKey,
    String? filterColumn,
    String? filterValue,
  }) {
    final query = _supabase.from(tableName).stream(primaryKey: primaryKey);
    if (filterColumn != null && filterValue != null) {
      return query.eq(filterColumn, filterValue);
    }
    return query;
  }

  // ---------------------------------------------------------------------------
  // 2. Specific Streams for requested tables
  // ---------------------------------------------------------------------------

  /// Real-time stream for Student Attendance.
  Stream<List<Map<String, dynamic>>> getAttendanceStream({String? studentId}) {
    return getTableStream(
      tableName: 'attendance',
      primaryKey: ['id'],
      filterColumn: studentId != null ? 'student_id' : null,
      filterValue: studentId,
    );
  }

  /// Real-time stream for Daily Class Reports.
  Stream<List<Map<String, dynamic>>> getDailyClassReportsStream({String? subjectId}) {
    return getTableStream(
      tableName: 'daily_class_reports',
      primaryKey: ['id'],
      filterColumn: subjectId != null ? 'subject_id' : null,
      filterValue: subjectId,
    );
  }

  /// Real-time stream for Exams.
  Stream<List<Map<String, dynamic>>> getExamsStream({String? campusId}) {
    return getTableStream(
      tableName: 'exams',
      primaryKey: ['id'],
      filterColumn: campusId != null ? 'campus_id' : null,
      filterValue: campusId,
    );
  }

  /// Real-time stream for Expenses.
  Stream<List<Map<String, dynamic>>> getExpensesStream({String? campusId}) {
    return getTableStream(
      tableName: 'expenses',
      primaryKey: ['id'],
      filterColumn: campusId != null ? 'campus_id' : null,
      filterValue: campusId,
    );
  }

  /// Real-time stream for Overall Attendance metrics.
  Stream<List<Map<String, dynamic>>> getOverallAttendanceStream({String? studentId}) {
    return getTableStream(
      tableName: 'overall_attendance',
      primaryKey: ['id'],
      filterColumn: studentId != null ? 'student_id' : null,
      filterValue: studentId,
    );
  }

  /// Real-time stream for Student Academic Performance.
  Stream<List<Map<String, dynamic>>> getStudentAcademicPerformanceStream({String? studentId}) {
    return getTableStream(
      tableName: 'student_academic_performance',
      primaryKey: ['id'],
      filterColumn: studentId != null ? 'student_id' : null,
      filterValue: studentId,
    );
  }

  /// Real-time stream for Subject Attendance.
  Stream<List<Map<String, dynamic>>> getSubjectAttendanceStream({String? subjectId}) {
    return getTableStream(
      tableName: 'subject_attendance',
      primaryKey: ['id'],
      filterColumn: subjectId != null ? 'subject_id' : null,
      filterValue: subjectId,
    );
  }

  /// Real-time stream for Teacher Attendance.
  Stream<List<Map<String, dynamic>>> getTeacherAttendanceStream({String? teacherId}) {
    return getTableStream(
      tableName: 'teacher_attendance',
      primaryKey: ['id'],
      filterColumn: teacherId != null ? 'teacher_id' : null,
      filterValue: teacherId,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Postgres Changes CDC Listeners
  // ---------------------------------------------------------------------------

  /// Listens to inserts, updates, or deletes on a specific table and invokes [callback].
  /// Make sure to remove the returned channel when the widget or cubit is disposed.
  RealtimeChannel listenToTableChanges({
    required String channelName,
    required String tableName,
    PostgresChangeEvent event = PostgresChangeEvent.all,
    String? filterColumn,
    String? filterValue,
    required void Function(PostgresChangeEvent event, Map<String, dynamic> record) callback,
  }) {
    final channel = _supabase.channel(channelName);

    PostgresChangeFilter? changeFilter;
    if (filterColumn != null && filterValue != null) {
      changeFilter = PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: filterColumn,
        value: filterValue,
      );
    }

    return channel.onPostgresChanges(
      event: event,
      schema: 'public',
      table: tableName,
      filter: changeFilter,
      callback: (payload) {
        final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
        callback(payload.eventType, record);
      },
    )..subscribe();
  }

  /// Unsubscribes and disposes a realtime channel.
  Future<void> removeChannel(RealtimeChannel channel) async {
    await _supabase.removeChannel(channel);
  }
}
