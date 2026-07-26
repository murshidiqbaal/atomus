import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dummy_data.dart';
import '../services/announcement_hive_service.dart';

class AnnouncementRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Announcement>> getActiveAnnouncements() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('is_active', true)
          .lte('start_date', now)
          .or(
            'end_date.is.null,end_date.gt.$now',
          )
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final mapList = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await AnnouncementHiveService().saveAnnouncements(mapList);

      return data.map((item) => Announcement.fromMap(item)).toList();
    } catch (e) {
      print('NOTICE [getActiveAnnouncements offline fallback]: $e');
      final cached = AnnouncementHiveService().getCachedAnnouncements(allowStale: true);
      if (cached != null) {
        return cached.map((item) => Announcement.fromMap(item)).toList();
      }
      return [];
    }
  }
}
