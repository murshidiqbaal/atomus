import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('=== TEACHERS TABLE DETAILS ===');
  try {
    final response = await supabase.from('teachers').select();
    for (var r in response) {
      print('Teacher: ${r['full_name']}');
      print('  - id: ${r['id']}');
      print('  - auth_user_id: ${r['auth_user_id']}');
      print('  - email: ${r['email']}');
      print('  - phone_number: ${r['phone_number']}');
      print('  - campus_id: ${r['campus_id']}');
      print('');
    }
  } catch (e) {
    print('Error: $e');
  }
}
