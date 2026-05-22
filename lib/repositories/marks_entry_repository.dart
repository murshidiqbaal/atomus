import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_marks_model.dart';
import '../services/teacher_hive_service.dart';

class MarksEntryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TeacherHiveService _hive;

  MarksEntryRepository({required TeacherHiveService hive}) : _hive = hive;

  /// Exams assigned to this teacher (filtered by assigned subject IDs).
  Future<List<TeacherExam>> fetchAssignedExams({
    required List<String> subjectIds,
    String? batchId,
  }) async {
    if (subjectIds.isEmpty) return [];

    try {
      var builder = _supabase
          .from('exams')
          .select('*, subjects(name), courses(name), batches(name)')
          .inFilter('subject_id', subjectIds);

      if (batchId != null) {
        builder = builder.eq('batch_id', batchId);
      }

      final rows = await builder.order('exam_date', ascending: false);
      return (rows as List)
          .map((r) => TeacherExam.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Load students with any existing marks for an exam.
  Future<List<StudentMarksEntry>> loadStudentsWithMarks({
    required String examId,
    required String subjectId,
    required String batchId,
    required double totalMarks,
  }) async {
    // Fetch students
    List<Map<String, dynamic>> students;
    try {
      final rows = await _supabase
          .from('students')
          .select(
              'id, full_name, roll_number, admission_number, profile_photo_drive_id')
          .eq('batch_id', batchId)
          .order('roll_number', ascending: true);
      students = (rows as List).map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (_) {
      students = _hive.getCachedStudents(batchId) ?? [];
    }

    if (students.isEmpty) return [];

    // Fetch existing marks
    Map<String, Map<String, dynamic>> existingMap = {};
    try {
      final existing = await _supabase
          .from('exam_results')
          .select('id, student_id, marks_obtained, total_marks, is_absent, remarks')
          .eq('exam_id', examId)
          .eq('subject_id', subjectId);
      for (final r in existing as List) {
        final row = r as Map<String, dynamic>;
        existingMap[row['student_id'] as String] = row;
      }
    } catch (_) {}

    return students.map((s) {
      return StudentMarksEntry.fromStudentMap(
        s,
        examId: examId,
        subjectId: subjectId,
        totalMarks: totalMarks,
        existingMarks: existingMap[s['id'] as String],
      );
    }).toList();
  }

  /// Upsert marks for all students. Queues offline if needed.
  Future<void> saveMarks(
    List<StudentMarksEntry> entries, {
    String? teacherId,
  }) async {
    final payload = entries.map((e) => e.toUpsertMap(teacherId: teacherId)).toList();

    try {
      await _supabase.from('exam_results').upsert(payload);
    } catch (_) {
      if (entries.isNotEmpty) {
        await _hive.savePendingMarks(entries.first.examId, payload);
      }
    }
  }

  /// Analytics: class average per exam.
  Future<Map<String, double>> fetchClassAverages({
    required List<String> subjectIds,
    required String batchId,
  }) async {
    if (subjectIds.isEmpty) return {};
    try {
      final rows = await _supabase
          .from('exam_results')
          .select('subject_id, marks_obtained, total_marks, is_absent')
          .inFilter('subject_id', subjectIds)
          .eq('is_absent', false);

      final totals = <String, double>{};
      final counts = <String, int>{};
      for (final r in rows as List) {
        final row        = r as Map<String, dynamic>;
        final sid        = row['subject_id'] as String;
        final obtained   = (row['marks_obtained'] as num?)?.toDouble() ?? 0;
        final total      = (row['total_marks'] as num?)?.toDouble() ?? 100;
        final pct        = total > 0 ? (obtained / total) * 100 : 0.0;
        totals[sid]      = (totals[sid] ?? 0) + pct;
        counts[sid]      = (counts[sid] ?? 0) + 1;
      }

      return totals.map((k, v) => MapEntry(k, v / (counts[k] ?? 1)));
    } catch (_) {
      return {};
    }
  }

  /// Identify students below passing threshold (default 40%).
  Future<List<Map<String, dynamic>>> fetchWeakStudents({
    required List<String> subjectIds,
    required String batchId,
    double threshold = 40.0,
  }) async {
    if (subjectIds.isEmpty) return [];
    try {
      final rows = await _supabase
          .from('student_academic_performance')
          .select('student_id, marks_percentage, attendance_percentage, students(full_name, roll_number)')
          .inFilter('subject_id', subjectIds)
          .lt('marks_percentage', threshold)
          .order('marks_percentage', ascending: true)
          .limit(20);

      return (rows as List).map((r) => r as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }
}
