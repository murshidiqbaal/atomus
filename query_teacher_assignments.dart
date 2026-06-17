import 'package:supabase/supabase.dart';

class TeacherSubjectAssignment {
  final String id;
  final String subjectId;
  final String subjectName;
  final String? courseId;
  final String? courseName;
  final String? batchId;
  final String? batchName;
  final String? campusId;
  final bool isActive;

  const TeacherSubjectAssignment({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    this.courseId,
    this.courseName,
    this.batchId,
    this.batchName,
    this.campusId,
    this.isActive = true,
  });

  @override
  String toString() => 'SubjectAssignment(id: $id, subjectName: $subjectName, courseName: $courseName, batchName: $batchName)';
}

class TeacherCourseAssignment {
  final String id;
  final String courseId;
  final String courseName;
  final String? campusId;

  const TeacherCourseAssignment({
    required this.id,
    required this.courseId,
    required this.courseName,
    this.campusId,
  });

  @override
  String toString() => 'CourseAssignment(id: $id, courseId: $courseId, courseName: $courseName)';
}

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('=== TEACHER ASSIGNMENTS DIAGNOSTICS ===');

  try {
    final teachers = await supabase.from('teachers').select('*, campuses(*)');
    for (final teacher in teachers) {
      print('\n----------------------------------------');
      print('Teacher: ${teacher['full_name']} (ID: ${teacher['id']})');
      print('Campus ID: ${teacher['campus_id']}');

      // Fetch subjects
      List<TeacherSubjectAssignment> subjects = [];
      try {
        final rows = await supabase
            .from('teacher_subjects')
            .select('*, subjects(name, course_id, courses(name)), batches(name)')
            .eq('teacher_id', teacher['id']);
        
        subjects = (rows as List).map((r) {
          final subject = r['subjects'] as Map<String, dynamic>?;
          final batch = r['batches'] as Map<String, dynamic>?;
          final course = subject?['courses'] as Map<String, dynamic>?;
          return TeacherSubjectAssignment(
            id: r['id'] as String,
            subjectId: r['subject_id'] as String,
            subjectName: subject?['name'] as String? ?? 'Unknown Subject',
            courseId: subject?['course_id'] as String?,
            courseName: course?['name'] as String?,
            batchId: r['batch_id'] as String?,
            batchName: batch?['name'] as String?,
          );
        }).toList();
        print('Subjects: $subjects');
      } catch (e) {
        print('Error fetching subjects: $e');
      }

      // Fetch courses
      List<TeacherCourseAssignment> courses = [];
      try {
        final rows = await supabase
            .from('teacher_courses')
            .select('*, courses!inner(name, campus_courses!inner(campus_id))')
            .eq('teacher_id', teacher['id'])
            .eq('courses.campus_courses.campus_id', teacher['campus_id'] as Object);

        courses = (rows as List).map((r) {
          final cMap = Map<String, dynamic>.from(r);
          final coursesData = cMap['courses'] as Map<String, dynamic>?;
          cMap['courses'] = {'name': coursesData?['name']};
          
          final course = cMap['courses'] as Map<String, dynamic>?;
          return TeacherCourseAssignment(
            id: cMap['id'] as String,
            courseId: cMap['course_id'] as String,
            courseName: course?['name'] as String? ?? cMap['course_id'] as String,
            campusId: cMap['campus_id'] as String?,
          );
        }).toList();
        print('Courses: $courses');
      } catch (e) {
        print('Error fetching courses: $e');
      }
    }
  } catch (e) {
    print('Global error: $e');
  }
}
