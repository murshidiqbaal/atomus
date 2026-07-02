import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('--- FETCHING STUDENT FEES STATUS ---');
  try {
    // We select student_id, payment_status, total_fee, paid_amount, balance_amount, and student details
    final response = await supabase
        .from('student_fees')
        .select('*, students(id, full_name)');
    
    if ((response as List).isEmpty) {
      print('No records found in student_fees table.');
      return;
    }

    final list = response as List;
    print('Found ${list.length} student fee records:\n');
    for (var record in list) {
      print(record);
      print('-' * 40);
    }
  } catch (e) {
    print('Error: $e');
  }
}
