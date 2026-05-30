import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dummy_data.dart';

class AnnouncementRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Announcement>> getActiveAnnouncements() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('is_active', true)
          .lte('start_date', now) // Only show if started
          .or(
            'end_date.is.null,end_date.gt.$now',
          ) // Show if no end date or not ended
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => Announcement.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching announcements: $e');
      return [];
    }
  }
}
