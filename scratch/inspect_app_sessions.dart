import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('--- CHECKING APP SESSIONS ---');
  try {
    final response = await supabase.from('app_sessions').select().limit(1);
    print('app_sessions exists: $response');
  } catch (e) {
    print('app_sessions check error (possibly table does not exist): $e');
  }

  print('\n--- CHECKING PARENTS COLUMNS ---');
  try {
    final response = await supabase.from('parents').select('last_app_opened_at, last_seen_at, is_online, app_version, device_platform').limit(1);
    print('parents columns exist: $response');
  } catch (e) {
    print('parents columns error: $e');
  }

  print('\n--- CHECKING TEACHERS COLUMNS ---');
  try {
    final response = await supabase.from('teachers').select('last_app_opened_at, last_seen_at, is_online, app_version, device_platform').limit(1);
    print('teachers columns exist: $response');
  } catch (e) {
    print('teachers columns error: $e');
  }
}
