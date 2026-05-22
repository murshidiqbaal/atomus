import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('--- MAHIN ATTENDANCE RECORDS ---');
  try {
    final response = await supabase
        .from('attendance')
        .select()
        .eq('student_id', '59a0e20d-039e-464d-982c-e5161bd96a64');
    print('Total records in attendance table: ${response.length}');
    for (var r in response) {
      print(
        '  - Date: ${r['attendance_date']}, Status: ${r['status']}, Period: ${r['period_number']}, Subject ID: ${r['subject_id']}',
      );
    }
  } catch (e) {
    print('Error: $e');
  }

  print('\n--- ALL SUBJECT ATTENDANCE RECORDS ---');
  try {
    final response = await supabase.from('subject_attendance').select();
    print('Total records in subject_attendance table: ${response.length}');
  } catch (e) {
    print('Error: $e');
  }
}
