import 'package:atomus/models/dummy_data.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/announcement_repository.dart';
import 'announcement_event.dart';
import 'announcement_state.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;

  AnnouncementBloc({required AnnouncementRepository repository})
    : _repository = repository,
      super(AnnouncementState()) {
    on<LoadAnnouncements>(_onLoadAnnouncements);
    on<DismissAnnouncement>(_onDismissAnnouncement);
  }

  Future<void> _onLoadAnnouncements(
    LoadAnnouncements event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(state.copyWith(status: AnnouncementStatus.loading));
    try {
      final announcements = await _repository.getActiveAnnouncements();

      // Filter out announcements that have already been seen/dismissed or read
      List<Announcement> unseenAnnouncements = [];
      try {
        final prefs = await SharedPreferences.getInstance();
        final seenList = prefs.getStringList('seen_announcements') ?? [];
        final readIds = prefs.getStringList('read_announcement_ids') ?? [];
        unseenAnnouncements = announcements
            .where((a) =>
                !seenList.contains(a.id.toString()) &&
                !readIds.contains(a.id.toString()))
            .toList();
      } catch (prefsError) {
        print('Error reading seen/read announcements from prefs: $prefsError');
        unseenAnnouncements = announcements;
      }

      emit(
        state.copyWith(
          status: AnnouncementStatus.success,
          announcements: unseenAnnouncements,
          currentAnnouncement: unseenAnnouncements.isNotEmpty
              ? unseenAnnouncements.first
              : null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AnnouncementStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDismissAnnouncement(
    DismissAnnouncement event,
    Emitter<AnnouncementState> emit,
  ) async {
    final dismissedId = state.currentAnnouncement?.id;
    if (dismissedId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final seenList = prefs.getStringList('seen_announcements') ?? [];
        final idStr = dismissedId.toString();
        if (!seenList.contains(idStr)) {
          seenList.add(idStr);
          await prefs.setStringList('seen_announcements', seenList);
        }
      } catch (e) {
        print('Error saving seen announcement to prefs: $e');
      }
    }

    if (state.announcements.isEmpty) return;

    final currentIndex = state.announcements.indexWhere(
      (a) => a.id == state.currentAnnouncement?.id,
    );

    if (currentIndex != -1 && currentIndex < state.announcements.length - 1) {
      // Show next announcement
      emit(
        state.copyWith(
          currentAnnouncement: state.announcements[currentIndex + 1],
        ),
      );
    } else {
      // No more announcements
      emit(state.copyWith(clearCurrent: true));
    }
  }
}
