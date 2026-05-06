import '../models/dummy_data.dart';

class StudentRepository {
  Future<StudentInfo> getStudentInfo() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return DummyData.currentStudent;
  }

  Future<List<ExamSession>> getExamSessions() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return DummyData.exams;
  }

  Future<List<AttendanceRecord>> getAttendance() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return DummyData.recentAttendance;
  }
}
