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
  }

  Future<void> _onLoadAnnouncements(
    LoadAnnouncements event,
    Emitter<AnnouncementState> emit,
  ) async {
    emit(state.copyWith(status: AnnouncementStatus.loading));
    try {
      final announcements = await _repository.getActiveAnnouncements();
      emit(state.copyWith(
        status: AnnouncementStatus.success,
        announcements: announcements,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AnnouncementStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
