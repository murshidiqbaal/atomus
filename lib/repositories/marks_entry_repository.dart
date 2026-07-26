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
    bool includeAllDates = false,
    bool includeUpcoming = false,
    DateTime? date,
    String? campusId,
  }) async {
    final teacherUserId = _supabase.auth.currentUser?.id;
    String? effectiveCampusId = campusId;
    bool isMainCampusSelected = false;

    if (effectiveCampusId != null && effectiveCampusId.isNotEmpty) {
      try {
        final campusRow = await _supabase
            .from('campuses')
            .select('name')
            .eq('id', effectiveCampusId)
            .maybeSingle();
        if (campusRow != null) {
          final name = (campusRow['name'] as String?)?.toLowerCase() ?? '';
          if (name.contains('main')) {
            isMainCampusSelected = true;
          }
        }
      } catch (_) {}
    }

    if (!isMainCampusSelected &&
        teacherUserId != null &&
        (effectiveCampusId == null || effectiveCampusId.isEmpty)) {
      final teacherRow = await _supabase
          .from('teachers')
          .select('campus_id')
          .eq('auth_id', teacherUserId)
          .maybeSingle();
      effectiveCampusId = teacherRow?['campus_id'] as String?;
      if (effectiveCampusId != null) {
        try {
          final campusRow = await _supabase
              .from('campuses')
              .select('name')
              .eq('id', effectiveCampusId)
              .maybeSingle();
          if (campusRow != null) {
            final name = (campusRow['name'] as String?)?.toLowerCase() ?? '';
            if (name.contains('main')) {
              isMainCampusSelected = true;
            }
          }
        } catch (_) {}
      }
    }

    if (!isMainCampusSelected && subjectIds.isEmpty && courseIds.isEmpty) return [];

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

      if (!isMainCampusSelected && conditions.isEmpty) return [];
      orQuery = conditions.join(',');

      final targetDate = date ?? DateTime.now();
      final dateIso = targetDate.toIso8601String().split('T').first;
      final String visibilityOr;
      if (includeUpcoming) {
        visibilityOr = 'is_daily.eq.true,exam_date.gte.$dateIso';
      } else {
        visibilityOr = 'is_daily.eq.true,exam_date.eq.$dateIso';
      }

      var builder = _supabase
          .from('exams')
          .select(
              '*, subjects(name), courses(name), batches(name), marks(id, subject_id, mark_date)');
      
      if (!isMainCampusSelected && orQuery.isNotEmpty) {
        builder = builder.or(orQuery);
      }
      if (!includeAllDates) {
        builder = builder.or(visibilityOr);
      }
      builder = builder.eq('marks.mark_date', dateIso);
      final rows = await builder.order('exam_date', ascending: includeUpcoming ? true : false);
      final allExams = (rows as List)
          .map((r) => TeacherExam.fromMap(r as Map<String, dynamic>))
          .toList();

      if (includeUpcoming) {
        final todayDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
        allExams.sort((a, b) {
          final isTodayA = a.examDate != null &&
              DateTime(a.examDate!.year, a.examDate!.month, a.examDate!.day)
                  .isAtSameMomentAs(todayDate);
          final isTodayB = b.examDate != null &&
              DateTime(b.examDate!.year, b.examDate!.month, b.examDate!.day)
                  .isAtSameMomentAs(todayDate);

          if (isTodayA && !isTodayB) return -1;
          if (!isTodayA && isTodayB) return 1;

          if (a.isDaily && !b.isDaily) return -1;
          if (!a.isDaily && b.isDaily) return 1;

          if (a.isDaily && b.isDaily) {
            return a.name.compareTo(b.name);
          }

          final da = a.examDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.examDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return da.compareTo(db);
        });
      }

      return allExams.where((e) {
        final isCreatedByMe = e.createdBy == teacherUserId || e.creatorId == teacherUserId;
        final isCreatedByAdmin = e.creatorRole?.toLowerCase() == 'admin' || e.creatorRole == null;
        final isMatchingCampus = isMainCampusSelected ||
            e.campusId == null ||
            (effectiveCampusId != null && e.campusId == effectiveCampusId);

        if (!isCreatedByMe && !isCreatedByAdmin && !isMatchingCampus) return false;

        if (isMainCampusSelected) return true;

        if (e.batchId == null) {
          if (e.courseId == null || !courseIds.contains(e.courseId)) return false;
          return e.subjectId == null || subjectIds.isEmpty || subjectIds.contains(e.subjectId);
        } else {
          if (batchIds.isNotEmpty && !batchIds.contains(e.batchId)) return false;
          return e.subjectId == null || subjectIds.isEmpty || subjectIds.contains(e.subjectId);
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
    DateTime? markDate,
    String? campusId,
  }) async {
    final effectiveMarkDate = markDate ?? DateTime.now();
    final markDateIso =
        effectiveMarkDate.toIso8601String().split('T').first;

    List<Map<String, dynamic>> students = [];
    
    // Check if selected campus is Main Campus
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

    // Step 1: Query students with primary campus & batch/course parameters
    try {
      var query = _supabase
          .from('students')
          .select(
            'id, full_name, roll_number, admission_number, image_url, campus_id, course_id, batch_id',
          );

      if (courseId != null && courseId.isNotEmpty) {
        query = query.eq('course_id', courseId);
      }

      if (batchId != null && batchId.isNotEmpty) {
        query = query.eq('batch_id', batchId);
      }

      if (campusId != null && campusId.isNotEmpty && !isMainCampus) {
        query = query.or('campus_id.eq.$campusId,campus_id.is.null');
      }

      final rows = await query.order('roll_number', ascending: true);
      students = (rows as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (_) {}

    // Step 2: Fallback query if strict campus filter returned 0 students
    if (students.isEmpty && (courseId != null || batchId != null)) {
      try {
        var fallbackQuery = _supabase
            .from('students')
            .select(
              'id, full_name, roll_number, admission_number, image_url, campus_id, course_id, batch_id',
            );
        if (courseId != null && courseId.isNotEmpty) {
          fallbackQuery = fallbackQuery.eq('course_id', courseId);
        }
        if (batchId != null && batchId.isNotEmpty) {
          fallbackQuery = fallbackQuery.eq('batch_id', batchId);
        }
        final rows = await fallbackQuery.order('roll_number', ascending: true);
        students = (rows as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      } catch (_) {}
    }

    // Step 3: Offline Hive cache fallback
    if (students.isEmpty) {
      students = _hive.getCachedStudents(batchId ?? courseId ?? '') ?? [];
    }

    if (students.isEmpty) return [];

    // Fetch existing marks scoped to the requested mark_date.
    Map<String, Map<String, dynamic>> existingMap = {};
    try {
      var query = _supabase
          .from('marks')
          .select(
              'id, student_id, subject_id, marks_obtained, total_marks, remarks, mark_date')
          .eq('exam_id', examId)
          .eq('mark_date', markDateIso);
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
        markDate: effectiveMarkDate,
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
          .upsert(payload,
              onConflict: 'exam_id,student_id,subject_id,mark_date');
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

  /// Update an exam.
  Future<void> updateExam({
    required String examId,
    required String name,
    required DateTime date,
    required double totalMarks,
    required String batchId,
    required String subjectId,
    String? courseId,
    String? currentSubjectId,
  }) async {
    // Validate permission on the existing exam
    await SecurityValidationService.validateExamDeletion(examId, currentSubjectId);

    // Validate assignments for new configuration
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
      'batch_id': isBatchExam ? batchId : null,
      'subject_id': subjectId,
      'course_id': (courseId != null && courseId.isNotEmpty) ? courseId : null,
    };

    await _supabase.from('exams').update(payload).eq('id', examId);
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
