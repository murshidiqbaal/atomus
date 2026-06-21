import 'package:atomus/models/dummy_data.dart';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txtvvlxaurqovghtngzm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  );

  final now = DateTime.now().toUtc().toIso8601String();
  print('now: $now');

  try {
    final response = await supabase
        .from('announcements')
        .select()
        .eq('is_active', true)
        .lte('start_date', now)
        .or('end_date.is.null,end_date.gt.$now');

    print('Query succeeded! Result length: ${response.length}');
    final announcements = (response as List)
        .map((item) => Announcement.fromMap(item as Map<String, dynamic>))
        .toList();
    print('Announcement model mapping succeeded!');
    for (final a in announcements) {
      print(
        'Announcement: id=${a.id}, title=${a.title}, description=${a.description}, createdAt=${a.createdAt}',
      );
    }
  } catch (e, stacktrace) {
    print('Failed with error: $e');
    print('Stacktrace: $stacktrace');
  }
}
