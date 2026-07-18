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
          .or(
            'batch_id.eq.$batchId,batch_ids.cs.{$batchId},batch_id.is.null',
          );

      bool isMainCampus = false;
      if (campusId != null && campusId.isNotEmpty) {
        try {
          final res = await _supabase
              .from('campuses')
              .select('name')
              .eq('id', campusId)
              .maybeSingle();
          if (res != null) {
            final name = (res['name'] as String?)?.toLowerCase() ?? '';
            if (name.contains('main')) {
              isMainCampus = true;
            }
          }
        } catch (_) {}
      }

      if (campusId != null && campusId.isNotEmpty && !isMainCampus) {
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

      bool isMainCampus = false;
      if (campusId != null && campusId.isNotEmpty) {
        try {
          final res = await _supabase
              .from('campuses')
              .select('name')
              .eq('id', campusId)
              .maybeSingle();
          if (res != null) {
            final name = (res['name'] as String?)?.toLowerCase() ?? '';
            if (name.contains('main')) {
              isMainCampus = true;
            }
          }
        } catch (_) {}
      }

      if (campusId != null && campusId.isNotEmpty && !isMainCampus) {
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

  /// Fetch all daily reports for a specific student, joining with daily_class_reports and teachers table
  Future<List<DailyReportModel>> fetchAllReportsForStudent({
    required String studentId,
  }) async {
    try {
      final rows = await _supabase
          .from('daily_student_reports')
          .select('''
            *,
            daily_class_reports (
              report_date,
              session_type,
              topics_covered,
              homework,
              general_remarks,
              subjects (
                name
              ),
              teachers (
                full_name
              )
            )
          ''')
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      final reports = (rows as List).map((r) {
        return DailyReportModel.fromMap(Map<String, dynamic>.from(r));
      }).toList();

      // Fallback/Legacy query support: if no records returned, try legacy student_daily_reports
      if (reports.isEmpty) {
        final legacyRows = await _supabase
            .from('student_daily_reports')
            .select('''
              *,
              subjects (
                name
              )
            ''')
            .eq('student_id', studentId)
            .order('date_str', ascending: false);

        return (legacyRows as List).map((r) {
          return DailyReportModel.fromMap(Map<String, dynamic>.from(r));
        }).toList();
      }

      return reports;
    } catch (e) {
      print('DailyReportRepository [fetchAllReportsForStudent] Supabase error: $e');
      return [];
    }
  }

  /// Retrieve a daily class report by Course, Batch, Subject, Date, and Session
  Future<Map<String, dynamic>?> fetchDailyClassReport({
    required String courseId,
    required String batchId,
    required String subjectId,
    required DateTime date,
    required String sessionType,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    try {
      var query = _supabase
          .from('daily_class_reports')
          .select('''
            *,
            daily_student_reports (
              *
            )
          ''')
          .eq('course_id', courseId)
          .eq('report_date', dateStr)
          .eq('session_type', sessionType);

      if (batchId.isEmpty) {
        query = query.isFilter('batch_id', null);
      } else {
        query = query.eq('batch_id', batchId);
      }

      if (subjectId.isEmpty) {
        query = query.isFilter('subject_id', null);
      } else {
        query = query.eq('subject_id', subjectId);
      }

      final rows = await query.limit(1);

      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first);
    } catch (e) {
      print('DailyReportRepository [fetchDailyClassReport] Supabase error: $e');
      return null;
    }
  }

  /// Save/Upsert a daily class report and all student reports bulk
  Future<void> saveDailyClassReport({
    required String courseId,
    required String batchId,
    required String subjectId,
    required DateTime date,
    required String sessionType,
    required String teacherId,
    required String topicsCovered,
    String? homework,
    String? generalRemarks,
    required List<Map<String, dynamic>> studentReports,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;
    try {
      // 1. Upsert daily class report
      final classReportData = {
        'course_id': courseId,
        'batch_id': batchId.isEmpty ? null : batchId,
        'subject_id': subjectId.isEmpty ? null : subjectId,
        'report_date': dateStr,
        'session_type': sessionType,
        'teacher_id': teacherId,
        'topics_covered': topicsCovered,
        'homework': homework,
        'general_remarks': generalRemarks,
      };

      final response = await _supabase
          .from('daily_class_reports')
          .upsert(classReportData, onConflict: 'course_id,batch_id,subject_id,report_date,session_type')
          .select('id')
          .single();

      final classReportId = response['id'] as String;

      // 2. Clear previous student reports for this class report ID to overwrite
      await _supabase
          .from('daily_student_reports')
          .delete()
          .eq('daily_report_id', classReportId);

      // 3. Bulk insert student reports
      if (studentReports.isNotEmpty) {
        final toInsert = studentReports.map((sr) => {
          'daily_report_id': classReportId,
          'student_id': sr['student_id'],
          'status': sr['status'],
          'comment': sr['comment'],
          'behavior_rating': sr['behavior_rating'] ?? 'Needs Imp.',
          'study_engagement': sr['study_engagement'] ?? 'Active',
          'homework_status': sr['homework_status'] ?? 'Completed',
        }).toList();

        await _supabase
            .from('daily_student_reports')
            .insert(toInsert);
      }
    } catch (e) {
      print('DailyReportRepository [saveDailyClassReport] Supabase error: $e');
      rethrow;
    }
  }

  /// Fetch all daily class reports created by a teacher
  Future<List<Map<String, dynamic>>> fetchClassReportsForTeacher(String teacherId) async {
    try {
      final rows = await _supabase
          .from('daily_class_reports')
          .select('''
            *,
            courses (
              name
            ),
            batches (
              name
            ),
            subjects (
              name
            )
          ''')
          .eq('teacher_id', teacherId)
          .order('report_date', ascending: false)
          .limit(20);
      return (rows as List).map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      print('DailyReportRepository [fetchClassReportsForTeacher] Supabase error: $e');
      return [];
    }
  }

  /// Fetch recent student daily reports for all students in a course
  Future<List<DailyReportModel>> fetchRecentReportsForCourse({
    required String courseId,
    int limit = 20,
  }) async {
    try {
      // 1. Get all students in the course
      final students = await fetchStudentsForCourses(courseIds: [courseId]);
      if (students.isEmpty) return [];
      final studentIds = students.map((s) => s['id'] as String).toList();

      // 2. Fetch daily student reports
      final rows = await _supabase
          .from('daily_student_reports')
          .select('''
            *,
            students (
              full_name
            ),
            daily_class_reports (
              report_date,
              session_type,
              topics_covered,
              homework,
              general_remarks,
              subjects (
                name
              ),
              teachers (
                full_name
              )
            )
          ''')
          .inFilter('student_id', studentIds)
          .order('created_at', ascending: false)
          .limit(limit);

      final reports = (rows as List).map((r) {
        return DailyReportModel.fromMap(Map<String, dynamic>.from(r));
      }).toList();

      return reports;
    } catch (e) {
      print('DailyReportRepository [fetchRecentReportsForCourse] Supabase error: $e');
      return [];
    }
  }
}
