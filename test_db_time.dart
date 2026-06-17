import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('=== TEST GET DB TIME ===');
  try {
    final response = await supabase.rpc('get_db_time');
    print('RPC get_db_time success: $response');
  } catch (e) {
    print('RPC get_db_time failed: $e');
  }

  try {
    // Let's try querying a table that has a created_at column and see if we can select now()
    final response = await supabase.from('campuses').select('created_at').limit(1);
    print('Campuses created_at: $response');
  } catch (e) {
    print('Query failed: $e');
  }
}
