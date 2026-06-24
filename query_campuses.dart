import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  print('=== QUERYING CAMPUSES ===');
  try {
    final campuses = await supabase.from('campuses').select();
    for (var campus in campuses) {
      print('ID: ${campus['id']}');
      print('Name: ${campus['name']}');
      print('Location: ${campus['location']}');
      print('payment_qr_url: ${campus['payment_qr_url']}');
      print('payment_qr_drive_id: ${campus['payment_qr_drive_id']}');
      print('-' * 40);
    }
  } catch (e) {
    print('Error: $e');
  }
}
