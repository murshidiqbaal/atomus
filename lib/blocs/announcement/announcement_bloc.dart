import 'package:flutter_bloc/flutter_bloc.dart';
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
      emit(
        state.copyWith(
          status: AnnouncementStatus.success,
          announcements: announcements,
          currentAnnouncement: announcements.isNotEmpty
              ? announcements.first
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

  void _onDismissAnnouncement(
    DismissAnnouncement event,
    Emitter<AnnouncementState> emit,
  ) {
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
