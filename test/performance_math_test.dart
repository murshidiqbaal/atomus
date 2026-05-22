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
    print(
      'Overall Academic Performance: ${result.academicPerformance.toStringAsFixed(2)}%',
    );
    print('Marks Average: ${result.marksPercentage.toStringAsFixed(2)}%');
    print(
      'Attendance Average: ${result.attendancePercentage.toStringAsFixed(2)}%',
    );
    print('Progress Status: ${result.progressStatus}');
    print('Progress Color: ${result.progressColor}');
    print(
      'Number of Subjects Analyzed: ${result.subjectWisePerformance.length}',
    );

    for (final sub in result.subjectWisePerformance) {
      print('  Subject: ${sub.subjectName}');
      print('    Academics: ${sub.marksPercentage.toStringAsFixed(2)}%');
      print('    Attendance: ${sub.attendancePercentage.toStringAsFixed(2)}%');
      print('    Combined: ${sub.combinedScore.toStringAsFixed(2)}%');
    }

    // Verify expectations
    expect(
      result.attendancePercentage >= 0.0 &&
          result.attendancePercentage <= 100.0,
      true,
    );
    expect(
      result.marksPercentage >= 0.0 && result.marksPercentage <= 100.0,
      true,
    );
    expect(
      result.academicPerformance >= 0.0 && result.academicPerformance <= 100.0,
      true,
    );

    // Mathematics academics: 85%. Mathematics attendance: Present (100) and Absent (0) -> 50%
    // Combined = 0.7 * 85 + 0.3 * 50 = 59.5 + 15 = 74.5%
    final mathPerf = result.subjectWisePerformance.firstWhere(
      (p) => p.subjectName.toLowerCase() == 'mathematics',
    );
    expect(mathPerf.marksPercentage, 85.0);
    expect(mathPerf.attendancePercentage, 50.0);
    expect(mathPerf.combinedScore, 74.5);
  });

  test(
    'Verify merging duplicate exam sessions and subject marks from admin/teacher uploads',
    () {
      final mockDbData = [
        // Upload 1: Teacher uploads Science and Mathematics for "Midterm Exam" (ID: exam-1)
        {
          'exam_id': 'exam-1',
          'exams': {'name': 'Midterm Exam', 'exam_date': '2026-05-15'},
          'subject_name': 'Science',
          'marks_obtained': 90,
          'total_marks': 100,
          'grade': 'A',
        },
        {
          'exam_id': 'exam-1',
          'exams': {'name': 'Midterm Exam', 'exam_date': '2026-05-15'},
          'subject_name': 'Mathematics',
          'marks_obtained': 80,
          'total_marks': 100,
          'grade': 'B',
        },
        // Upload 2: Admin uploads English for a separate duplicate "Midterm Exam" record (ID: exam-2)
        {
          'exam_id': 'exam-2',
          'exams': {
            'name': 'midterm exam',
            'exam_date': '2026-05-15',
          }, // case-insensitive name
          'subject_name': 'English',
          'marks_obtained': 85,
          'total_marks': 100,
          'grade': 'A',
        },
        // Upload 3: Admin uploads Science again for same "Midterm Exam" (duplicate subject upload), but with a lower score
        {
          'exam_id': 'exam-2',
          'exams': {'name': 'Midterm Exam', 'exam_date': '2026-05-15'},
          'subject_name': 'science', // case-insensitive subject name
          'marks_obtained':
              70, // lower score, should be discarded in favor of 90
          'total_marks': 100,
          'grade': 'B',
        },
        // Upload 4: Admin uploads Science again, but with a higher score (e.g. grade update / correction)
        {
          'exam_id': 'exam-2',
          'exams': {'name': 'Midterm Exam', 'exam_date': '2026-05-15'},
          'subject_name': 'Science',
          'marks_obtained': 95, // higher score, should replace 90!
          'total_marks': 100,
          'grade': 'A',
        },
      ];

      // Apply the merging algorithm:
      final Map<String, List<ExamMark>> mergedMarksByExamName = {};
      final Map<String, Map<String, dynamic>> examDetailsByExamName = {};

      for (var item in mockDbData) {
        final examData = item['exams'] as Map<String, dynamic>? ?? item;
        final examName =
            (examData['name'] ?? examData['title'] ?? 'Examination')
                .toString()
                .trim();
        final examKey = examName.toLowerCase();

        if (!mergedMarksByExamName.containsKey(examKey)) {
          mergedMarksByExamName[examKey] = [];
          examDetailsByExamName[examKey] = item;
        }

        final newMark = ExamMark.fromMap(item);
        final subjectKey = newMark.subject.trim().toLowerCase();

        final existingIndex = mergedMarksByExamName[examKey]!.indexWhere(
          (m) => m.subject.trim().toLowerCase() == subjectKey,
        );

        if (existingIndex >= 0) {
          final existingMark = mergedMarksByExamName[examKey]![existingIndex];
          if (newMark.marksObtained > existingMark.marksObtained) {
            mergedMarksByExamName[examKey]![existingIndex] = newMark;
          }
        } else {
          mergedMarksByExamName[examKey]!.add(newMark);
        }
      }

      final List<ExamSession> mergedSessions = mergedMarksByExamName.entries
          .map((entry) {
            return ExamSession.fromMap(
              examDetailsByExamName[entry.key]!,
              entry.value,
            );
          })
          .toList();

      // Verify merging results
      expect(
        mergedSessions.length,
        1,
      ); // 2 different exam IDs representing "Midterm Exam" were merged into 1
      final midterm = mergedSessions.first;
      expect(midterm.title.toLowerCase(), 'midterm exam');
      expect(midterm.subjects.length, 3); // Science, Mathematics, English

      // Verify Science got merged and retained the highest mark (95)
      final scienceMark = midterm.subjects.firstWhere(
        (s) => s.subject.toLowerCase() == 'science',
      );
      expect(scienceMark.marksObtained, 95);

      // Verify Mathematics mark (80)
      final mathMark = midterm.subjects.firstWhere(
        (s) => s.subject.toLowerCase() == 'mathematics',
      );
      expect(mathMark.marksObtained, 80);

      // Verify English mark (85)
      final englishMark = midterm.subjects.firstWhere(
        (s) => s.subject.toLowerCase() == 'english',
      );
      expect(englishMark.marksObtained, 85);

      print('\n--- MERGING TEST PASSED ---');
      print('Merged Exam Sessions Count: ${mergedSessions.length}');
      print('Merged Exam Title: ${midterm.title}');
      print('Subjects included:');
      for (final s in midterm.subjects) {
        print(
          '  - ${s.subject}: ${s.marksObtained}/${s.totalMarks} (${s.grade})',
        );
      }
    },
  );
}
