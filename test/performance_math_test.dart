import 'package:flutter_test/flutter_test.dart';
import 'package:atomus/services/student_performance_service.dart';
import 'package:atomus/models/dummy_data.dart';

void main() {
  test('Verify dynamic performance calculations from Mock Models', () async {
    final attendance = <AttendanceRecord>[
      AttendanceRecord(
        id: '1',
        studentId: 'stud-123',
        subjectId: 'sub-math',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Present',
      ),
      AttendanceRecord(
        id: '2',
        studentId: 'stud-123',
        subjectId: 'sub-math',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Absent',
      ),
      AttendanceRecord(
        id: '3',
        studentId: 'stud-123',
        subjectId: 'sub-sci',
        date: DateTime.now(),
        status: 'Late',
      ),
    ];

    final exams = <ExamSession>[
      ExamSession(
        title: 'Midterm',
        date: '2026-05-15',
        subjects: [
          ExamMark(
            subject: 'Mathematics',
            subjectId: 'sub-math',
            marksObtained: 85,
            totalMarks: 100,
            grade: 'A',
          ),
          ExamMark(
            subject: 'Science',
            subjectId: 'sub-sci',
            marksObtained: 90,
            totalMarks: 100,
            grade: 'A',
          ),
        ],
      ),
    ];

    final result = StudentPerformanceService.calculatePerformance(
      attendance,
      exams,
    );

    print('\n--- CALCULATION RESULTS ---');
    print('Overall Academic Performance: ${result.academicPerformance.toStringAsFixed(2)}%');
    print('Marks Average: ${result.marksPercentage.toStringAsFixed(2)}%');
    print('Attendance Average: ${result.attendancePercentage.toStringAsFixed(2)}%');
    print('Progress Status: ${result.progressStatus}');
    print('Progress Color: ${result.progressColor}');
    print('Number of Subjects Analyzed: ${result.subjectWisePerformance.length}');

    for (final sub in result.subjectWisePerformance) {
      print('  Subject: ${sub.subjectName}');
      print('    Academics: ${sub.marksPercentage.toStringAsFixed(2)}%');
      print('    Attendance: ${sub.attendancePercentage.toStringAsFixed(2)}%');
      print('    Combined: ${sub.combinedScore.toStringAsFixed(2)}%');
    }

    // Verify expectations
    expect(result.attendancePercentage >= 0.0 && result.attendancePercentage <= 100.0, true);
    expect(result.marksPercentage >= 0.0 && result.marksPercentage <= 100.0, true);
    expect(result.academicPerformance >= 0.0 && result.academicPerformance <= 100.0, true);
    
    // Mathematics academics: 85%. Mathematics attendance: Present (100) and Absent (0) -> 50%
    // Combined = 0.7 * 85 + 0.3 * 50 = 59.5 + 15 = 74.5%
    final mathPerf = result.subjectWisePerformance.firstWhere((p) => p.subjectName.toLowerCase() == 'mathematics');
    expect(mathPerf.marksPercentage, 85.0);
    expect(mathPerf.attendancePercentage, 50.0);
    expect(mathPerf.combinedScore, 74.5);
  });
}
