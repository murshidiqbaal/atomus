import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('--- CHECKING parent_app_activity_logs TABLE ---');
  try {
    final response = await supabase.from('parent_app_activity_logs').select().limit(1);
    print('parent_app_activity_logs check succeeded: $response');
  } catch (e) {
    print('parent_app_activity_logs check error: $e');
  }
}
