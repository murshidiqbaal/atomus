import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/exam_marks_model.dart';
import '../../repositories/marks_entry_repository.dart';
import '../../repositories/teacher_attendance_repository.dart';
import '../../repositories/teacher_repository.dart';
import 'teacher_dashboard_state.dart';

class TeacherDashboardCubit extends Cubit<TeacherDashboardState> {
  final TeacherRepository _teacherRepo;
  final TeacherAttendanceRepository _attendanceRepo;
  final MarksEntryRepository _marksRepo;

  TeacherDashboardCubit({
    required TeacherRepository teacherRepository,
    required TeacherAttendanceRepository attendanceRepository,
    required MarksEntryRepository marksRepository,
  })  : _teacherRepo    = teacherRepository,
        _attendanceRepo = attendanceRepository,
        _marksRepo      = marksRepository,
        super(const TeacherDashboardState());

  Future<void> load() async {
    emit(state.copyWith(status: TeacherDashboardStatus.loading));
    try {
      final teacher = await _teacherRepo.fetchTeacherProfile();
      if (teacher == null) {
        emit(state.copyWith(
          status:       TeacherDashboardStatus.failure,
          errorMessage: 'Teacher profile not found.',
        ));
        return;
      }

      final subjectIds = teacher.subjects.map((s) => s.subjectId).toList();
      final batchIds   = teacher.subjects
          .map((s) => s.batchId)
          .whereType<String>()
          .toSet()
          .toList();
      final courseIds  = teacher.courses.map((c) => c.courseId).toSet().toList();

      final activeSession  = await _attendanceRepo.fetchTodayActiveSession(teacher.id);
      final monthlyPct     = await _attendanceRepo.fetchMonthlyAttendancePercentage(teacher.id);

      List<TeacherExam> upcomingExams = [];
      int pendingMarks = 0;
      if (subjectIds.isNotEmpty || courseIds.isNotEmpty) {
        upcomingExams = await _marksRepo.fetchAssignedExams(
          subjectIds: subjectIds,
          batchIds:   batchIds,
          courseIds:  courseIds,
        );
        pendingMarks = upcomingExams
            .where((e) => !e.isMarksEntered)
            .length;
      }

      final stats = TeacherDashboardStats(
        todayClassCount:         teacher.subjects.length,
        attendancePercentage:    monthlyPct,
        hasActiveSession:        activeSession != null,
        upcomingExamCount:       upcomingExams.length,
        pendingMarksCount:       pendingMarks,
      );

      emit(state.copyWith(
        status:        TeacherDashboardStatus.success,
        teacher:       teacher,
        activeSession: activeSession,
        clearSession:  activeSession == null,
        stats:         stats,
        upcomingExams: upcomingExams.take(5).toList(),
      ));
    } catch (e) {
      emit(state.copyWith(
        status:       TeacherDashboardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> refresh() => load();
}
