import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/teacher_repository.dart';
import 'teacher_session_state.dart';

class TeacherSessionCubit extends Cubit<TeacherSessionState> {
  final TeacherRepository _repo;

  TeacherSessionCubit({required TeacherRepository repository})
      : _repo = repository,
        super(const TeacherSessionState());

  Future<void> loadSession() async {
    emit(state.copyWith(status: TeacherSessionStatus.loading));
    try {
      final teacher = await _repo.fetchTeacherProfile();
      if (teacher == null) {
        emit(state.copyWith(
          status:       TeacherSessionStatus.error,
          errorMessage: 'Teacher profile not found.',
        ));
        return;
      }
      emit(state.copyWith(
        status:  TeacherSessionStatus.ready,
        teacher: teacher,
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       TeacherSessionStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void refresh() => loadSession();
}
