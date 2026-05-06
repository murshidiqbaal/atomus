import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/student_repository.dart';
import 'student_event.dart';
import 'student_state.dart';

class StudentBloc extends Bloc<StudentEvent, StudentState> {
  final StudentRepository studentRepository;

  StudentBloc({required this.studentRepository}) : super(const StudentState()) {
    on<LoadStudentData>(_onLoadStudentData);
  }

  Future<void> _onLoadStudentData(LoadStudentData event, Emitter<StudentState> emit) async {
    emit(state.copyWith(status: StudentStatus.loading));
    try {
      final info = await studentRepository.getStudentInfo();
      final exams = await studentRepository.getExamSessions();
      final attendance = await studentRepository.getAttendance();
      
      emit(state.copyWith(
        status: StudentStatus.success,
        studentInfo: info,
        exams: exams,
        attendance: attendance,
      ));
    } catch (e) {
      emit(state.copyWith(status: StudentStatus.failure, errorMessage: e.toString()));
    }
  }
}
