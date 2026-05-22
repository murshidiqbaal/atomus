import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/course_repository.dart';
import 'course_event.dart';
import 'course_state.dart';

class CourseBloc extends Bloc<CourseEvent, CourseState> {
  final CourseRepository courseRepository;

  CourseBloc({required this.courseRepository}) : super(CourseState()) {
    on<LoadCourses>(_onLoadCourses);
    on<LoadSubjects>(_onLoadSubjects);
  }

  Future<void> _onLoadCourses(
    LoadCourses event,
    Emitter<CourseState> emit,
  ) async {
    emit(state.copyWith(status: CourseStatus.loading));
    try {
      final courses = await courseRepository.getCourses();
      emit(state.copyWith(status: CourseStatus.success, courses: courses));
    } catch (e) {
      emit(
        state.copyWith(
          status: CourseStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onLoadSubjects(
    LoadSubjects event,
    Emitter<CourseState> emit,
  ) async {
    emit(state.copyWith(status: CourseStatus.loading));
    try {
      final subjects = await courseRepository.getSubjects(event.courseId);
      emit(state.copyWith(status: CourseStatus.success, subjects: subjects));
    } catch (e) {
      emit(
        state.copyWith(
          status: CourseStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
