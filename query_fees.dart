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
      final student = record['students'];
      final studentName = student != null ? student['full_name'] : 'Unknown Student';
      final studentId = record['student_id'];
      final status = record['payment_status'];
      final total = record['total_fee'];
      final paid = record['paid_amount'];
      final balance = record['balance_amount'];
      
      print('Student Name: $studentName');
      print('Student ID  : $studentId');
      print('Status      : $status');
      print('Total Fee   : $total');
      print('Paid Amount : $paid');
      print('Balance     : $balance');
      print('-' * 40);
    }
  } catch (e) {
    print('Error: $e');
  }
}
