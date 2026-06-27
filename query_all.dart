import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  final email = 'murshidiqbaalkm10@gmail.com';
  final phone = '+917994051281';

  print('--- Testing individual queries ---');

  for (final col in ['auth_user_id', 'id', 'email', 'phone_number']) {
    final val = col == 'email' ? email
              : col == 'phone_number' ? phone
              : 'some-random-uid';
    try {
      final rows = await supabase
          .from('teachers')
          .select('id, full_name, email, auth_user_id')
          .eq(col, val);
      print('col=$col, val=$val -> Found ${rows.length} rows: $rows');
    } catch (e) {
      print('col=$col, val=$val -> FAILED with: $e');
    }
  }
}
