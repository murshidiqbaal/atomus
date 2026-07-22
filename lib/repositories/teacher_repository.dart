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

      final uid = user.id;
      final email = user.email;

      // Try auth_id first, then id, then email
      for (final filter in [
        {'col': 'auth_id', 'val': uid},
        {'col': 'id', 'val': uid},
        if (email != null) {'col': 'email', 'val': email},
      ]) {
        try {
          final rows = await _supabase
              .from('teachers')
              .select('*, campuses(*)')
              .eq(filter['col']!, filter['val']!)
              .limit(1);
          if (rows.isNotEmpty) {
            final row = rows.first;
            final campusMap = row['campuses'] as Map<String, dynamic>?;
            final teacher = TeacherModel.fromMap(row, campusData: campusMap);

            // Link auth_id if missing or mismatched
            if (row['auth_id'] == null || row['auth_id'] != uid) {
              try {
                await _supabase
                    .from('teachers')
                    .update({'auth_id': uid})
                    .eq('id', teacher.id);
              } catch (_) {}
            }

            final withAssignments = await _attachAssignments(teacher);
            await _hive.saveTeacherProfile(withAssignments.toMap());
            return withAssignments;
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

  Future<TeacherModel> _attachAssignments(TeacherModel teacher) async {
    List<TeacherSubjectAssignment> subjects = [];
    List<TeacherCourseAssignment> courses = [];

    final initialCampusIds = {
      if (teacher.campusId != null) teacher.campusId!,
      ...teacher.assignedCampuses,
    };

    bool hasMainCampus = false;
    for (final cid in initialCampusIds) {
      try {
        final res = await _supabase
            .from('campuses')
            .select('name')
            .eq('id', cid)
            .maybeSingle();
        if (res != null) {
          final name = (res['name'] as String?)?.toLowerCase() ?? '';
          if (name.contains('main')) {
            hasMainCampus = true;
            break;
          }
        }
      } catch (_) {}
    }

    // Fetch subjects
    try {
      final rows = await _supabase
          .from('teacher_subjects')
          .select(
            '*, subjects(name, course_id, courses(name)), batches(name)',
          )
          .eq('teacher_id', teacher.id); // is_active removed from schema

      subjects = (rows as List).map((r) {
        final subject = r['subjects'] as Map<String, dynamic>?;
        final batch = r['batches'] as Map<String, dynamic>?;
        final course = subject?['courses'] as Map<String, dynamic>?;
        return TeacherSubjectAssignment(
          id: r['id'] as String,
          subjectId: r['subject_id'] as String,
          subjectName: subject?['name'] as String? ?? 'Unknown Subject',
          courseId:
              subject?['course_id'] as String?, // get course_id from subject
          courseName:
              course?['name']
                  as String?, // get courseName from subjects.courses
          batchId: r['batch_id'] as String?,
          batchName: batch?['name'] as String?,
          campusId: r['campus_id'] as String?,
        );
      }).toList();

      if (hasMainCampus) {
        try {
          final List<dynamic> subjectsRows = await _supabase
              .from('subjects')
              .select('id, name, course_id, courses(name)');
          final List<dynamic> batchesRows = await _supabase
              .from('batches')
              .select('id, name, course_id');

          final List<TeacherSubjectAssignment> mainCampusSubjects = [];
          for (final sRow in subjectsRows) {
            final sId = sRow['id'] as String;
            final sName = sRow['name'] as String? ?? '';
            final cId = sRow['course_id'] as String?;
            final cName = sRow['courses']?['name'] as String?;

            final courseBatches = batchesRows
                .where((b) => b['course_id'] == cId)
                .toList();
            if (courseBatches.isEmpty) {
              mainCampusSubjects.add(
                TeacherSubjectAssignment(
                  id: 'mc_subj_$sId',
                  subjectId: sId,
                  subjectName: sName,
                  courseId: cId,
                  courseName: cName,
                  batchId: null,
                  batchName: null,
                  campusId: teacher.campusId,
                ),
              );
            } else {
              for (final bRow in courseBatches) {
                mainCampusSubjects.add(
                  TeacherSubjectAssignment(
                    id: 'mc_subj_${sId}_${bRow['id']}',
                    subjectId: sId,
                    subjectName: sName,
                    courseId: cId,
                    courseName: cName,
                    batchId: bRow['id'] as String,
                    batchName: bRow['name'] as String?,
                    campusId: teacher.campusId,
                  ),
                );
              }
            }
          }

          final Set<String> existingKeys = subjects
              .map((s) => '${s.subjectId}_${s.batchId}')
              .toSet();
          for (final mcs in mainCampusSubjects) {
            final key = '${mcs.subjectId}_${mcs.batchId}';
            if (!existingKeys.contains(key)) {
              subjects.add(mcs);
              existingKeys.add(key);
            }
          }
        } catch (e) {
          print('Error fetching main campus subjects fallback: $e');
        }
      }

      final mapList = subjects
          .map(
            (a) => <String, dynamic>{
              'id': a.id,
              'subject_id': a.subjectId,
              'subject_name': a.subjectName,
              'course_id': a.courseId,
              'batch_id': a.batchId,
              'batch_name': a.batchName,
              'campus_id': a.campusId,
            },
          )
          .toList();
      await _hive.saveAssignments(mapList);
    } catch (e) {
      print('Error fetching teacher_subjects: $e');
    }

    final allCampusIds = {
      if (teacher.campusId != null) teacher.campusId!,
      ...teacher.assignedCampuses,
      for (final s in subjects)
        if (s.campusId != null) s.campusId!,
    };

    // Fetch courses
    try {
      final rows = await _supabase
          .from('teacher_courses')
          .select('*, courses!inner(name, campus_courses!inner(campus_id))')
          .eq('teacher_id', teacher.id);

      final filteredRows = (rows as List).where((r) {
        if (hasMainCampus) return true;
        try {
          final course = r['courses'] as Map<String, dynamic>?;
          final campusCourses = course?['campus_courses'];
          if (campusCourses is List) {
            return campusCourses.any(
              (cc) => allCampusIds.contains(cc['campus_id']),
            );
          } else if (campusCourses is Map) {
            return allCampusIds.contains(campusCourses['campus_id']);
          }
        } catch (_) {}
        return true;
      }).toList();

      courses = filteredRows.map((r) {
        // Need to handle the nested courses -> name structure correctly
        final cMap = Map<String, dynamic>.from(r);
        final coursesData = cMap['courses'] as Map<String, dynamic>?;
        cMap['courses'] = {'name': coursesData?['name']};
        return TeacherCourseAssignment.fromMap(cMap);
      }).toList();

      if (hasMainCampus) {
        try {
          final List<dynamic> coursesRows = await _supabase
              .from('courses')
              .select('id, name');

          final List<TeacherCourseAssignment> mainCampusCourses = [];
          for (final cRow in coursesRows) {
            mainCampusCourses.add(
              TeacherCourseAssignment(
                id: 'mc_course_${cRow['id']}',
                courseId: cRow['id'] as String,
                courseName: cRow['name'] as String? ?? '',
                teacherId: '',
              ),
            );
          }

          final Set<String> existingCourseIds = courses
              .map((c) => c.courseId)
              .toSet();
          for (final mcc in mainCampusCourses) {
            if (!existingCourseIds.contains(mcc.courseId)) {
              courses.add(mcc);
              existingCourseIds.add(mcc.courseId);
            }
          }
        } catch (e) {
          print('Error fetching main campus courses fallback: $e');
        }
      }
    } catch (_) {}

    List<CampusLocation> campuses = [];
    if (allCampusIds.isNotEmpty) {
      try {
        final campusRes = await _supabase
            .from('campuses')
            .select('*')
            .inFilter('id', allCampusIds.toList());
        campuses = (campusRes as List)
            .map((c) => CampusLocation.fromMap(c as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error fetching campuses: $e');
      }
    }

    return teacher.copyWith(
      subjects: subjects,
      courses: courses,
      campuses: campuses,
    );
  }

  // Returns all students in a given batch, filtered to the teacher's campus.
  Future<List<Map<String, dynamic>>> fetchStudentsForBatch({
    required String batchId,
    String? campusId,
  }) async {
    try {
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

      var query = _supabase
          .from('students')
          .select(
            'id, full_name, roll_number, admission_number, image_url, batch_id, course_id, campus_id',
          )
          .or('batch_id.eq.$batchId,batch_ids.cs.{$batchId},batch_id.is.null');

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

  Future<void> updateFcmToken(String teacherId, String token) async {
    try {
      await _supabase
          .from('teachers')
          .update({
            'fcm_token': token,
            'last_active': DateTime.now().toIso8601String(),
          })
          .eq('id', teacherId);
    } catch (_) {}
  }
}
