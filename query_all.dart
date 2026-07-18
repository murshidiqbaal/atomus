import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  final email = 'murshidiqbaalkm10@gmail.com';
  final phone = '+917994051281';

  try {
    final marks = await supabase.from('marks').select().limit(1);
    if (marks.isNotEmpty) {
      print('marks columns: ${marks.first.keys.toList()}');
    } else {
      print('marks table is empty');
    }
  } catch (e) {
    print('marks check failed: $e');
  }

  try {
    final exams = await supabase.from('exams').select().limit(1);
    if (exams.isNotEmpty) {
      print('exams columns: ${exams.first.keys.toList()}');
    } else {
      print('exams table is empty');
    }
  } catch (e) {
    print('exams check failed: $e');
  }

  try {
    final fees = await supabase.from('fees').select().limit(1);
    if (fees.isNotEmpty) {
      print('fees columns: ${fees.first.keys.toList()}');
    } else {
      print('fees table is empty');
    }
  } catch (e) {
    print('fees check failed: $e');
  }
}
