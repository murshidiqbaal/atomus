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

  const LoadAttendance({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class UpdateStudentProfile extends StudentEvent {
  final StudentInfo student;
  const UpdateStudentProfile(this.student);

  @override
  List<Object?> get props => [student];
}
