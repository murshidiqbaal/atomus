import 'package:equatable/equatable.dart';
import '../../models/dummy_data.dart';

abstract class StudentEvent extends Equatable {
  const StudentEvent();

  @override
  List<Object?> get props => [];
}

class LoadStudentData extends StudentEvent {
  final DateTime? month;
  const LoadStudentData({this.month});

  @override
  List<Object?> get props => [month];
}

class LoadAttendance extends StudentEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? courseId;
  final String? subjectId;

  const LoadAttendance({this.startDate, this.endDate, this.courseId, this.subjectId});

  @override
  List<Object?> get props => [startDate, endDate, courseId, subjectId];
}

class UpdateStudentProfile extends StudentEvent {
  final StudentInfo student;
  const UpdateStudentProfile(this.student);

  @override
  List<Object?> get props => [student];
}
