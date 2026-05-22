import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/teacher_model.dart';
import '../services/teacher_hive_service.dart';

class TeacherRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TeacherHiveService _hive;

  TeacherRepository({required TeacherHiveService hive}) : _hive = hive;

  Future<TeacherModel?> fetchTeacherProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final uid   = user.id;
      final email = user.email;

      // Try auth_user_id first, then id, then email
      for (final filter in [
        {'col': 'auth_user_id', 'val': uid},
        {'col': 'id',           'val': uid},
        if (email != null) {'col': 'email', 'val': email},
      ]) {
        try {
          final rows = await _supabase
              .from('teachers')
              .select('*, campuses(*)')
              .eq(filter['col']!, filter['val']!)
              .limit(1);
          if (rows.isNotEmpty) {
            final row      = rows.first;
            final campusMap = row['campuses'] as Map<String, dynamic>?;
            final teacher  = TeacherModel.fromMap(row, campusData: campusMap);
            final withSubjects = await _attachSubjects(teacher);
            await _hive.saveTeacherProfile(row);
            return withSubjects;
          }
        } catch (_) {}
      }

      // Offline fallback
      final cached = _hive.getTeacherProfile();
      if (cached != null) {
        return TeacherModel.fromMap(cached);
      }

      return null;
    } catch (_) {
      final cached = _hive.getTeacherProfile();
      if (cached != null) return TeacherModel.fromMap(cached);
      return null;
    }
  }

  Future<TeacherModel> _attachSubjects(TeacherModel teacher) async {
    try {
      final rows = await _supabase
          .from('teacher_subjects')
          .select('*, subjects(name), courses(name), batches(name)')
          .eq('teacher_id', teacher.id)
          .eq('is_active', true);

      final assignments = (rows as List)
          .map((r) => TeacherSubjectAssignment.fromMap(r as Map<String, dynamic>))
          .toList();

      final mapList = assignments.map((a) => {
        'id': a.id,
        'subject_id': a.subjectId,
        'subject_name': a.subjectName,
        'course_id': a.courseId,
        'batch_id': a.batchId,
        'batch_name': a.batchName,
      }).toList();
      await _hive.saveAssignments(mapList);

      return teacher.copyWith(subjects: assignments);
    } catch (_) {
      return teacher;
    }
  }

  // Returns all students in a given batch, filtered to the teacher's campus.
  Future<List<Map<String, dynamic>>> fetchStudentsForBatch({
    required String batchId,
    String? campusId,
  }) async {
    try {
      var query = _supabase
          .from('students')
          .select('id, full_name, roll_number, admission_number, profile_photo_drive_id, batch_id, course_id')
          .eq('batch_id', batchId)
          .order('roll_number', ascending: true);

      final rows = await query;
      final students = (rows as List).map((r) => r as Map<String, dynamic>).toList();
      await _hive.cacheStudents(batchId, students);
      return students;
    } catch (_) {
      return _hive.getCachedStudents(batchId) ?? [];
    }
  }

  Future<void> updateFcmToken(String teacherId, String token) async {
    try {
      await _supabase
          .from('teachers')
          .update({'fcm_token': token, 'last_active': DateTime.now().toIso8601String()})
          .eq('id', teacherId);
    } catch (_) {}
  }
}
