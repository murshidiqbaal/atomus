import 'package:supabase_flutter/supabase_flutter.dart';

class UnauthorizedAssignmentException implements Exception {
  final String message;
  UnauthorizedAssignmentException(this.message);

  @override
  String toString() => message;
}

class SecurityValidationService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Verifies that a teacher user is signed in and returns their user ID.
  static String verifyTeacherSession() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw UnauthorizedAssignmentException(
        'Session expired. Please log in again to continue.',
      );
    }
    return user.id;
  }

  /// Resolves the corresponding teacher row ID from the teachers table.
  static Future<String> getTeacherId() async {
    final authUserId = verifyTeacherSession();
    
    // Try resolving teacher ID by matching auth_id, id, email, or phone
    for (final col in ['auth_id', 'id', 'email', 'phone_number']) {
      final val = col == 'email' ? _supabase.auth.currentUser!.email
                : col == 'phone_number' ? _supabase.auth.currentUser!.phone
                : authUserId;
      if (val == null) continue;
      try {
        final isTextColumn = col == 'email' || col == 'phone_number';
        final query = _supabase.from('teachers').select('id');
        final rows = await (isTextColumn
                ? query.ilike(col, val)
                : query.eq(col, val))
            .limit(1);
        if (rows.isNotEmpty) {
          return rows.first['id'] as String;
        }
      } catch (_) {}
    }
    
    // Fall back to returning the auth user ID directly
    return authUserId;
  }

  /// Confirms in teacher_subjects, teacher_batches, and teacher_courses
  /// that the active teacher is officially assigned to the specified
  /// subject_id, batch_id, and course_id.
  ///
  /// For course-level attendance, subjectId and batchId may be empty.
  /// In that case, we only validate against teacher_courses.
  static Future<void> validateTeacherAssignments({
    required String? subjectId,
    required String? batchId,
    required String? courseId,
  }) async {
    final teacherId = await getTeacherId();
    final sId = subjectId ?? '';
    final bId = batchId ?? '';
    final cId = courseId ?? '';

    // ── Course-level attendance (subjectId is empty) ──
    // Only need to validate that the teacher is assigned to the course.
    if (sId.isEmpty && cId.isNotEmpty) {
      bool courseAssigned = false;
      try {
        final rows = await _supabase
            .from('teacher_courses')
            .select('id')
            .eq('teacher_id', teacherId)
            .eq('course_id', cId);
        if (rows.isNotEmpty) courseAssigned = true;
      } catch (_) {}

      if (!courseAssigned) {
        throw UnauthorizedAssignmentException(
          'Access Denied: You are not officially assigned to this Course.',
        );
      }
      return; // Authorized for course-level attendance
    }

    // ── Subject-level attendance (normal flow) ──
    bool subjectAssigned = false;
    bool batchAssigned = bId.isEmpty; // Skip batch check if empty
    bool courseAssigned = cId.isEmpty; // Skip course check if empty

    // 1. Validate in teacher_subjects
    try {
      final rows = await _supabase
          .from('teacher_subjects')
          .select('id, batch_id')
          .eq('teacher_id', teacherId)
          .eq('subject_id', sId);

      if (rows.isNotEmpty) {
        subjectAssigned = true;
        for (final row in rows) {
          if (row['batch_id'] == null || row['batch_id'] == bId) {
            batchAssigned = true;
          }
        }
      }
    } catch (_) {
      // If table query fails, we continue to secondary checks
    }

    // 2. Validate in teacher_batches (if table exists separately)
    if (!batchAssigned) {
      try {
        final rows = await _supabase
            .from('teacher_batches')
            .select('id')
            .eq('teacher_id', teacherId)
            .eq('batch_id', bId);
        if (rows.isNotEmpty) {
          batchAssigned = true;
        }
      } catch (_) {
        // Table may not exist separately — trust composite teacher_subjects if matched
      }
    }

    // 3. Validate in teacher_courses (if table exists separately)
    if (!courseAssigned) {
      try {
        final rows = await _supabase
            .from('teacher_courses')
            .select('id')
            .eq('teacher_id', teacherId)
            .eq('course_id', cId);
        if (rows.isNotEmpty) {
          courseAssigned = true;
        }
      } catch (_) {
        // Table may not exist separately — trust composite teacher_subjects if matched
      }
    }

    if (!subjectAssigned) {
      throw UnauthorizedAssignmentException(
        'Access Denied: You are not assigned to teach this Subject.',
      );
    }

    if (!batchAssigned) {
      throw UnauthorizedAssignmentException(
        'Access Denied: You are not officially assigned to this Student Batch.',
      );
    }

    if (!courseAssigned) {
      throw UnauthorizedAssignmentException(
        'Access Denied: You are not officially assigned to this Course.',
      );
    }
  }

  /// Restricts exam deletion so only the teacher who created or is assigned to the exam's subject can delete it.
  static Future<void> validateExamDeletion(String examId, String? subjectId) async {
    final teacherId = await getTeacherId();

    try {
      // Check if teacher is creator
      final exam = await _supabase
          .from('exams')
          .select('created_by, creator_id')
          .eq('id', examId)
          .maybeSingle();

      if (exam != null) {
        final creatorId = exam['creator_id'] as String? ?? exam['created_by'] as String?;
        if (creatorId == teacherId || creatorId == _supabase.auth.currentUser?.id) {
          return; // Authorized as creator!
        }
      }

      if (subjectId != null) {
        // Check if teacher is assigned to the exam's subject
        final assigned = await _supabase
            .from('teacher_subjects')
            .select('id')
            .eq('teacher_id', teacherId)
            .eq('subject_id', subjectId)
            .eq('is_active', true)
            .limit(1);

        if (assigned.isNotEmpty) {
          return; // Authorized as assigned subject teacher!
        }
      }

      throw UnauthorizedAssignmentException(
        'Access Denied: Only the exam creator or the assigned subject teacher can delete this exam.',
      );
    } catch (e) {
      if (e is UnauthorizedAssignmentException) rethrow;
      throw UnauthorizedAssignmentException(
        'Access Denied: Verification failed. You are not authorized to delete this exam.',
      );
    }
  }
}
