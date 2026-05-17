import '../../models/dummy_data.dart';

enum CourseStatus { initial, loading, success, failure }

class CourseState {
  final CourseStatus status;
  final List<Course> courses;
  final List<Subject> subjects;
  final String? errorMessage;

  CourseState({
    this.status = CourseStatus.initial,
    this.courses = const [],
    this.subjects = const [],
    this.errorMessage,
  });

  CourseState copyWith({
    CourseStatus? status,
    List<Course>? courses,
    List<Subject>? subjects,
    String? errorMessage,
  }) {
    return CourseState(
      status: status ?? this.status,
      courses: courses ?? this.courses,
      subjects: subjects ?? this.subjects,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
