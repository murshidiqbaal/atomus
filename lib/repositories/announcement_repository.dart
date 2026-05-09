import '../models/dummy_data.dart';

class AnnouncementRepository {
  Future<List<Announcement>> getActiveAnnouncements() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Return dummy data
    return DummyData.announcements;
  }
}
