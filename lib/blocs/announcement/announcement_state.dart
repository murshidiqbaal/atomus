import '../../models/dummy_data.dart';

enum AnnouncementStatus { initial, loading, success, failure }

class AnnouncementState {
  final AnnouncementStatus status;
  final List<Announcement> announcements;
  final Announcement? currentAnnouncement;
  final String? errorMessage;

  AnnouncementState({
    this.status = AnnouncementStatus.initial,
    this.announcements = const [],
    this.currentAnnouncement,
    this.errorMessage,
  });

  AnnouncementState copyWith({
    AnnouncementStatus? status,
    List<Announcement>? announcements,
    Announcement? currentAnnouncement,
    bool clearCurrent = false,
    String? errorMessage,
  }) {
    return AnnouncementState(
      status: status ?? this.status,
      announcements: announcements ?? this.announcements,
      currentAnnouncement: clearCurrent
          ? null
          : (currentAnnouncement ?? this.currentAnnouncement),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
