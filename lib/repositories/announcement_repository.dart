import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dummy_data.dart';

class AnnouncementRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Announcement>> getActiveAnnouncements() async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('is_active', true)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => Announcement.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching announcements: $e');
      // Fallback to empty list or handle error as needed
      return [];
    }
  }
}
