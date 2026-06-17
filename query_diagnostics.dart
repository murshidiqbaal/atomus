import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('=== DIAGNOSTICS ===');

  try {
    print('\n--- CAMPUSES ---');
    final campuses = await supabase.from('campuses').select('id, name');
    print(campuses);

    print('\n--- COURSES ---');
    final courses = await supabase.from('courses').select('id, name');
    print(courses);

    print('\n--- TEACHERS ---');
    final teachers = await supabase.from('teachers').select('id, full_name, email, campus_id');
    print(teachers);

    print('\n--- TEACHER COURSES ---');
    final teacherCourses = await supabase.from('teacher_courses').select();
    print(teacherCourses);

    print('\n--- TEACHER SUBJECTS ---');
    final teacherSubjects = await supabase.from('teacher_subjects').select();
    print(teacherSubjects);

    print('\n--- STUDENTS ---');
    final students = await supabase.from('students').select('id, full_name, course_id, campus_id, batch_id');
    print(students);
  } catch (e) {
    print('Error during query: $e');
  }
}
