import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('--- TESTING STUDENTS ---');
  try {
    final response = await supabase.from('students').select().limit(1);
    print('Students: $response');
  } catch (e) {
    print('Students error: $e');
  }

  print('\n--- TESTING EXAMS ---');
  try {
    final response = await supabase.from('exams').select().limit(2);
    print('Exams: $response');
  } catch (e) {
    print('Exams error: $e');
  }

  print('\n--- TESTING MARKS ---');
  try {
    final response = await supabase.from('marks').select().limit(2);
    print('Marks: $response');
  } catch (e) {
    print('Marks error: $e');
  }

  print('\n--- TESTING SUBJECT_ATTENDANCE ---');
  try {
    final response = await supabase.from('subject_attendance').select().limit(2);
    print('Subject Attendance: $response');
  } catch (e) {
    print('Subject Attendance error: $e');
  }

  print('\n--- TESTING STUDENT_ACADEMIC_PERFORMANCE ---');
  try {
    final response = await supabase.from('student_academic_performance').select().limit(2);
    print('Student Academic Performance: $response');
  } catch (e) {
    print('Student Academic Performance error: $e');
  }
}
