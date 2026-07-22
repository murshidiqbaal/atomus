import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  final campus1Id = '38635807-7d54-47c1-a690-db3f1e85c91f'; // Campus 1 - ARR
  final course10 = '359f1bf5-3955-45df-abc8-309d2341d107'; // 10 Regular
  final batchMorning10 = '51294ea3-385f-4757-a9e8-0a153ce445d4';

  print('=== TESTING REPOSITORY QUERY WITHOUT INVALID COLUMN ===\n');

  try {
    var query = supabase
        .from('students')
        .select(
          'id, full_name, roll_number, admission_number, batch_id, course_id, campus_id',
        );

    query = query.eq('course_id', course10);
    query = query.or('campus_id.eq.$campus1Id,campus_id.is.null');

    final rows = await query.order('roll_number', ascending: true);
    print('SUCCESS! Rows returned: ${rows.length}');
    for (var r in rows.take(5)) {
      print('   -> Student: ${r['full_name']} | Roll: ${r['roll_number']}');
    }
  } catch (e, stack) {
    print('FAILURE! Error: $e');
    print('Stack: $stack');
  }
}
