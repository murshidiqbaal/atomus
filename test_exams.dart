import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('--- TESTING ATTENDANCE TABLE ---');
  try {
    final response = await supabase.from('attendance').select().limit(2);
    print('attendance output: $response');
  } catch (e) {
    print('attendance table error: $e');
  }

  print('\n--- TESTING SUBJECT_ATTENDANCE TABLE ---');
  try {
    final response = await supabase
        .from('subject_attendance')
        .select('''
          *,
          subjects (
            name
          )
        ''')
        .limit(2);
    print('subject_attendance output: $response');
  } catch (e) {
    print('subject_attendance table error: $e');
  }
}
