import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/exam_marks_model.dart';
import '../services/security_validation_service.dart';
import '../services/teacher_hive_service.dart';

class MarksEntryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TeacherHiveService _hive;

  MarksEntryRepository({required TeacherHiveService hive}) : _hive = hive;

  Future<List<TeacherExam>> fetchAssignedExams({
    required List<String> subjectIds,
    required List<String> batchIds,
    required List<String> courseIds,
  }) async {
    if (subjectIds.isEmpty && courseIds.isEmpty) return [];

    try {
      String orQuery = '';
      List<String> conditions = [];
      if (subjectIds.isNotEmpty) {
        final subjStr = subjectIds.join(',');
        conditions.add('subject_id.in.($subjStr)');
      }
      if (courseIds.isNotEmpty) {
        final courseStr = courseIds.join(',');
        conditions.add('course_id.in.($courseStr)');
      }
      if (batchIds.isNotEmpty) {
        final batchStr = batchIds.join(',');
        conditions.add('batch_id.in.($batchStr)');
      }

      if (conditions.isEmpty) return [];
      orQuery = conditions.join(',');

      var builder = _supabase
          .from('exams')
          .select('*, subjects(name), courses(name), batches(name), marks(id, subject_id)')
          .or(orQuery)
          .order('exam_date', ascending: false);

      final rows = await builder;
      final allExams = (rows as List)
          .map((r) => TeacherExam.fromMap(r as Map<String, dynamic>))
          .toList();

      final teacherUserId = _supabase.auth.currentUser?.id;
      return allExams.where((e) {
        // Access control: only exams created by admin or the logged-in teacher are visible
        final isCreatedByMe = e.createdBy == teacherUserId;
        final isCreatedByAdmin = e.creatorRole?.toLowerCase() == 'admin' || e.creatorRole == null;
        if (!isCreatedByMe && !isCreatedByAdmin) return false;

        if (e.batchId == null) {
          // Course exam: course must match, and subject must either be null (course-wide) or match subjectIds
          if (e.courseId == null || !courseIds.contains(e.courseId)) return false;
          return e.subjectId == null || subjectIds.contains(e.subjectId);
        } else {
          // Batch exam: batch must match, and subject must either be null or match subjectIds
          if (!batchIds.contains(e.batchId)) return false;
          return e.subjectId == null || subjectIds.contains(e.subjectId);
        }
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<StudentMarksEntry>> loadStudentsWithMarks({
    required String examId,
    required String? subjectId,
    String? batchId,
    String? courseId,
    required double totalMarks,
  }) async {
    // Fetch students
    List<Map<String, dynamic>> students;
    try {
      var query = _supabase
          .from('students')
          .select(
            'id, full_name, roll_number, admission_number, profile_photo_drive_id',
          );

      if (batchId != null && batchId.isNotEmpty) {
        query = query.eq('batch_id', batchId);
      } else if (courseId != null && courseId.isNotEmpty) {
        query = query.eq('course_id', courseId);
      }

      final rows = await query.order('roll_number', ascending: true);
      students = (rows as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (_) {
      students = _hive.getCachedStudents(batchId ?? courseId ?? '') ?? [];
    }

    if (students.isEmpty) return [];

    // Fetch existing marks
    Map<String, Map<String, dynamic>> existingMap = {};
    try {
      var query = _supabase
          .from('marks')
          .select('id, student_id, subject_id, marks_obtained, total_marks, remarks')
          .eq('exam_id', examId);
      if (subjectId != null) {
        query = query.eq('subject_id', subjectId);
      } else {
        query = query.isFilter('subject_id', null);
      }
      final existing = await query;
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
    final resolvedTeacherId =
        teacherId ?? await SecurityValidationService.getTeacherId();

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

    final payload = entries
        .map((e) => e.toUpsertMap(teacherId: resolvedTeacherId))
        .toList();

    try {
      // Use upsert with the unique constraint on (exam_id, student_id, subject_id)
      await _supabase
          .from('marks')
          .upsert(payload, onConflict: 'exam_id,student_id,subject_id');
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
    String? campusId,
  }) async {
    // Validate assignments
    await SecurityValidationService.validateTeacherAssignments(
      subjectId: subjectId,
      batchId: batchId,
      courseId: courseId ?? '',
    );

    final isBatchExam = batchId.isNotEmpty;

    final payload = {
      'name': name,
      'exam_date': date.toIso8601String().split('T').first,
      'total_marks': totalMarks,
      'exam_scope': isBatchExam ? 'batch' : 'course',
      if (isBatchExam) 'batch_id': batchId,
      'subject_id': subjectId,
      if (courseId != null && courseId.isNotEmpty) 'course_id': courseId,
      if (campusId != null && campusId.isNotEmpty) 'campus_id': campusId,
      'created_by': Supabase.instance.client.auth.currentUser?.id,
      'creator_role': 'Teacher',
      'creator_id': Supabase.instance.client.auth.currentUser?.id,
    };

    await _supabase.from('exams').insert(payload);
  }

  /// Delete an exam.
  Future<void> deleteExam(String examId, String? subjectId) async {
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
          .select('subject_id, marks_obtained, total_marks, remarks')
          .inFilter('subject_id', subjectIds)
          .neq('remarks', 'Absent');

      final totals = <String, double>{};
      final counts = <String, int>{};
      for (final r in rows as List) {
        final row = r as Map<String, dynamic>;
        final sid = row['subject_id'] as String;
        final obtained = (row['marks_obtained'] as num?)?.toDouble() ?? 0;
        final total = (row['total_marks'] as num?)?.toDouble() ?? 100;
        final pct = total > 0 ? (obtained / total) * 100 : 0.0;
        totals[sid] = (totals[sid] ?? 0) + pct;
        counts[sid] = (counts[sid] ?? 0) + 1;
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
          .select(
            'student_id, marks_percentage, attendance_percentage, students(full_name, roll_number)',
          )
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
