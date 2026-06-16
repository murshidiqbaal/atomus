import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_report_model.dart';
import '../services/teacher_hive_service.dart';

class DailyReportRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TeacherHiveService _hive;

  DailyReportRepository({required TeacherHiveService hive}) : _hive = hive;

  /// Retrieve a daily report from Hive by student, subject, and date
  DailyReportModel? getReport({
    required String studentId,
    String? subjectId,
    required DateTime date,
  }) {
    final dateStr = date.toIso8601String().split('T').first;
    final key = 'report_${studentId}_${subjectId ?? "general"}_$dateStr';
    final map = _hive.getDailyReport(key);
    if (map == null) return null;
    return DailyReportModel.fromMap(map);
  }

  /// Retrieve daily reports in bulk from Supabase or Hive cache
  Future<List<DailyReportModel>> fetchReports({
    required List<String> studentIds,
    String? subjectId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    if (studentIds.isEmpty) return [];

    try {
      var query = _supabase
          .from('student_daily_reports')
          .select()
          .eq('date_str', dateStr)
          .inFilter('student_id', studentIds);

      if (subjectId != null) {
        query = query.eq('subject_id', subjectId);
      } else {
        query = query.isFilter('subject_id', null);
      }

      final rows = await query;
      final reports = (rows as List).map((r) {
        final model = DailyReportModel.fromMap(Map<String, dynamic>.from(r));
        // Cache locally in Hive
        final key =
            'report_${model.studentId}_${model.subjectId ?? "general"}_${model.dateStr}';
        _hive.saveDailyReport(key, model.toMap());
        return model;
      }).toList();

      return reports;
    } catch (e) {
      print('DailyReportRepository [fetchReports] Supabase error: $e');
      // Fallback: read local Hive cache
      final List<DailyReportModel> cached = [];
      for (final studentId in studentIds) {
        final key = 'report_${studentId}_${subjectId ?? "general"}_$dateStr';
        final map = _hive.getDailyReport(key);
        if (map != null) {
          cached.add(DailyReportModel.fromMap(map));
        }
      }
      return cached;
    }
  }

  /// Save/Upsert a daily report to Hive and Supabase
  Future<void> saveReport(DailyReportModel report) async {
    try {
      // Check if a report already exists in Supabase for this student, subject, and date
      var query = _supabase
          .from('student_daily_reports')
          .select('id')
          .eq('student_id', report.studentId)
          .eq('date_str', report.dateStr);

      if (report.subjectId != null) {
        query = query.eq('subject_id', report.subjectId!);
      } else {
        query = query.isFilter('subject_id', null);
      }

      final existing = await query.maybeSingle();

      if (existing != null) {
        // Update the existing record
        final existingId = existing['id'] as String;
        await _supabase
            .from('student_daily_reports')
            .update(report.toMap())
            .eq('id', existingId);
      } else {
        // Insert a new record
        await _supabase
            .from('student_daily_reports')
            .insert(report.toMap());
      }
    } catch (e) {
      print('DailyReportRepository [saveReport] Supabase error: $e');
      // Continue to save locally even if offline
    }

    final key =
        'report_${report.studentId}_${report.subjectId ?? "general"}_${report.dateStr}';
    await _hive.saveDailyReport(key, report.toMap());
  }

  /// Delete/Clear a daily report from Hive and Supabase
  Future<void> deleteReport({
    required String studentId,
    String? subjectId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;

    try {
      var query = _supabase
          .from('student_daily_reports')
          .delete()
          .eq('student_id', studentId)
          .eq('date_str', dateStr);

      if (subjectId != null) {
        query = query.eq('subject_id', subjectId);
      } else {
        query = query.isFilter('subject_id', null);
      }

      await query;
    } catch (e) {
      print('DailyReportRepository [deleteReport] Supabase error: $e');
    }

    final key = 'report_${studentId}_${subjectId ?? "general"}_$dateStr';
    await _hive.deleteDailyReport(key);
  }

  /// Fetch students for a batch using Supabase (falls back to cached Hive students)
  Future<List<Map<String, dynamic>>> fetchStudents({
    required String batchId,
    String? campusId,
  }) async {
    try {
      var query = _supabase
          .from('students')
          .select(
            'id, full_name, roll_number, admission_number, profile_photo_drive_id, batch_id, course_id, campus_id',
          )
          .eq('batch_id', batchId);

      if (campusId != null && campusId.isNotEmpty) {
        query = query.eq('campus_id', campusId);
      }

      final rows = await query.order('roll_number', ascending: true);
      final students = (rows as List)
          .map((r) => r as Map<String, dynamic>)
          .toList();
      await _hive.cacheStudents(batchId, students);
      return students;
    } catch (_) {
      return _hive.getCachedStudents(batchId) ?? [];
    }
  }

  /// Fetch students for multiple courses in bulk
  Future<List<Map<String, dynamic>>> fetchStudentsForCourses({
    required List<String> courseIds,
    String? campusId,
  }) async {
    if (courseIds.isEmpty) return [];
    try {
      var query = _supabase
          .from('students')
          .select(
            'id, full_name, roll_number, admission_number, profile_photo_drive_id, batch_id, course_id, campus_id',
          )
          .inFilter('course_id', courseIds);

      if (campusId != null && campusId.isNotEmpty) {
        query = query.eq('campus_id', campusId);
      }

      final rows = await query.order('roll_number', ascending: true);
      final students = (rows as List)
          .map((r) => r as Map<String, dynamic>)
          .toList();
      return students;
    } catch (_) {
      return [];
    }
  }
}
