abstract class CourseEvent {}

class LoadCourses extends CourseEvent {}

class LoadSubjects extends CourseEvent {
  final String courseId;
  LoadSubjects(this.courseId);
}
