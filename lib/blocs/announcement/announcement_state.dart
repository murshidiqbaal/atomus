import '../../models/dummy_data.dart';

enum AnnouncementStatus { initial, loading, success, failure }

class AnnouncementState {
  final AnnouncementStatus status;
  final List<Announcement> announcements;
  final String? errorMessage;

  AnnouncementState({
    this.status = AnnouncementStatus.initial,
    this.announcements = const [],
    this.errorMessage,
  });

  AnnouncementState copyWith({
    AnnouncementStatus? status,
    List<Announcement>? announcements,
    String? errorMessage,
  }) {
    return AnnouncementState(
      status: status ?? this.status,
      announcements: announcements ?? this.announcements,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
