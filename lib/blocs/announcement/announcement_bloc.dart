import 'package:atomus/models/dummy_data.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/announcement_repository.dart';
import '../../services/announcement_hive_service.dart';
import 'announcement_event.dart';
import 'announcement_state.dart';

class AnnouncementBloc extends Bloc<AnnouncementEvent, AnnouncementState> {
  final AnnouncementRepository _repository;
  final AnnouncementHiveService _hiveService;

  AnnouncementBloc({
    required AnnouncementRepository repository,
    AnnouncementHiveService? hiveService,
  }) : _repository = repository,
       _hiveService = hiveService ?? AnnouncementHiveService(),
       super(AnnouncementState()) {
    on<LoadAnnouncements>(_onLoadAnnouncements);
    on<DismissAnnouncement>(_onDismissAnnouncement);
  }

  Future<void> _onLoadAnnouncements(
    LoadAnnouncements event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(state.copyWith(status: AnnouncementStatus.loading));

    // ── 1. Show cached announcements instantly ───────────────────
    try {
      await _hiveService.initBoxes();
      final cachedData = _hiveService.getCachedAnnouncements();
      if (cachedData != null && cachedData.isNotEmpty) {
        final cachedAnnouncements =
            cachedData.map((item) => Announcement.fromMap(item)).toList();
        final filtered = await _filterSeenAnnouncements(cachedAnnouncements);
        if (filtered.isNotEmpty) {
          emit(state.copyWith(
            status: AnnouncementStatus.success,
            announcements: filtered,
            currentAnnouncement: filtered.first,
          ));
        }
      }
    } catch (e) {
      print('AnnouncementBloc: Cache read failed (non-fatal): $e');
    }

    // ── 2. Fetch fresh from Supabase ─────────────────────────────
    try {
      final announcements = await _repository.getActiveAnnouncements();

      // Cache for next launch
      try {
        await _hiveService.saveAnnouncements(
          announcements
              .map((a) => {
                    'id': a.id,
                    'title': a.title,
                    'description': a.description,
                    'image_url': a.imageUrl,
                    'image_drive_id': a.imageDriveId,
                    'type': a.type,
                    'target_audience': a.targetAudience,
                    'course_id': a.courseId,
                    'batch_id': a.batchId,
                    'is_popup': a.isPopup,
                    'is_active': a.isActive,
                    'start_date': a.startDate.toIso8601String(),
                    'end_date': a.endDate?.toIso8601String(),
                    'created_at': a.createdAt.toIso8601String(),
                  })
              .toList(),
        );
      } catch (cacheError) {
        print(
          'AnnouncementBloc: Cache write failed (non-fatal): $cacheError',
        );
      }

      final unseenAnnouncements =
          await _filterSeenAnnouncements(announcements);

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
      // If we already have cached data, keep it
      if (state.announcements.isNotEmpty) {
        print(
          'AnnouncementBloc: Network fetch failed, keeping cached data: $e',
        );
      } else {
        emit(
          state.copyWith(
            status: AnnouncementStatus.failure,
            errorMessage: e.toString(),
          ),
        );
      }
    }
  }

  /// Filters out announcements that have been seen/dismissed or read.
  Future<List<Announcement>> _filterSeenAnnouncements(
    List<Announcement> announcements,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenList = prefs.getStringList('seen_announcements') ?? [];
      final readIds = prefs.getStringList('read_announcement_ids') ?? [];
      return announcements
          .where((a) =>
              !seenList.contains(a.id.toString()) &&
              !readIds.contains(a.id.toString()))
          .toList();
    } catch (prefsError) {
      print('Error reading seen/read announcements from prefs: $prefsError');
      return announcements;
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
