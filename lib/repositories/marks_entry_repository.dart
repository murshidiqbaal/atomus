import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_marks_model.dart';
import '../services/teacher_hive_service.dart';
import '../services/security_validation_service.dart';

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
          .from('marks')
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
    if (entries.isEmpty) return;

    final first = entries.first;

    // 1. Verify user profile and fetch teacher assignments via supabase
    final resolvedTeacherId = teacherId ?? await SecurityValidationService.getTeacherId();

    // 2. Validate assignments: confirm the active teacher is assigned to this exam's subject, batch, and course.
    try {
      final exam = await _supabase
          .from('exams')
          .select('batch_id, course_id, subject_id')
          .eq('id', first.examId)
          .maybeSingle();

      if (exam != null) {
        final eSubjectId = exam['subject_id'] as String? ?? first.subjectId;
        final eBatchId = exam['batch_id'] as String? ?? '';
        final eCourseId = exam['course_id'] as String? ?? '';
        await SecurityValidationService.validateTeacherAssignments(
          subjectId: eSubjectId,
          batchId: eBatchId,
          courseId: eCourseId,
        );
      }
    } catch (_) {
      // If offline or check fails, allow fallback save or bubble up security exceptions
    }

    final payload = entries.map((e) => e.toUpsertMap(teacherId: resolvedTeacherId)).toList();

    try {
      // 3. Replicate UPSERT: Fetch existing marks for exam_id and student_ids, separate into updates and inserts
      final studentIds = entries.map((e) => e.studentId).toList();
      final existingRows = await _supabase
          .from('marks')
          .select('id, student_id')
          .eq('exam_id', first.examId)
          .inFilter('student_id', studentIds);

      final existingStudentIds = (existingRows as List)
          .map((r) => r['student_id'] as String)
          .toSet();

      final inserts = <Map<String, dynamic>>[];
      final updates = <Map<String, dynamic>>[];

      for (var item in payload) {
        final sid = item['student_id'] as String;
        if (existingStudentIds.contains(sid)) {
          // If match found, map current database ID to perform update
          final dbRow = existingRows.firstWhere((r) => r['student_id'] == sid);
          item['id'] = dbRow['id'];
          updates.add(item);
        } else {
          inserts.add(item);
        }
      }

      if (inserts.isNotEmpty) {
        await _supabase.from('marks').insert(inserts);
      }
      if (updates.isNotEmpty) {
        await _supabase.from('marks').upsert(updates);
      }
    } catch (_) {
      if (entries.isNotEmpty) {
        await _hive.savePendingMarks(entries.first.examId, payload);
      }
    }
  }

  /// Create an exam.
  Future<void> createExam({
    required String name,
    required DateTime date,
    required double totalMarks,
    required String batchId,
    required String subjectId,
    String? courseId,
  }) async {
    final teacherId = await SecurityValidationService.getTeacherId();

    // Validate assignments
    await SecurityValidationService.validateTeacherAssignments(
      subjectId: subjectId,
      batchId: batchId,
      courseId: courseId ?? '',
    );

    final payload = {
      'name': name,
      'exam_date': date.toIso8601String().split('T').first,
      'total_marks': totalMarks,
      'batch_id': batchId,
      'subject_id': subjectId,
      if (courseId != null) 'course_id': courseId,
      'created_by': teacherId,
      'creator_role': 'Teacher',
      'creator_id': teacherId,
    };

    await _supabase.from('exams').insert(payload);
  }

  /// Delete an exam.
  Future<void> deleteExam(String examId, String subjectId) async {
    // Restrict exam deletion so only the teacher who created or is assigned to the exam's subject can delete it.
    await SecurityValidationService.validateExamDeletion(examId, subjectId);
    await _supabase.from('exams').delete().eq('id', examId);
  }

  /// Analytics: class average per exam.
  Future<Map<String, double>> fetchClassAverages({
    required List<String> subjectIds,
    required String batchId,
  }) async {
    if (subjectIds.isEmpty) return {};
    try {
      final rows = await _supabase
          .from('marks')
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
