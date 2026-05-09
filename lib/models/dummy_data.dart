class StudentInfo {
  final String name;
  final String grade;
  final String profileUrl;
  final double overallProgress; // 0.0 to 1.0

  StudentInfo({
    required this.name,
    required this.grade,
    required this.profileUrl,
    required this.overallProgress,
  });
}

class ExamMark {
  final String subject;
  final int marksObtained;
  final int totalMarks;
  final String grade;

  ExamMark({
    required this.subject,
    required this.marksObtained,
    required this.totalMarks,
    required this.grade,
  });
}

class ExamSession {
  final String title;
  final String date;
  final List<ExamMark> subjects;

  ExamSession({
    required this.title,
    required this.date,
    required this.subjects,
  });
}

class AttendanceRecord {
  final DateTime date;
  final bool isPresent;

  AttendanceRecord({required this.date, required this.isPresent});
}

class FeeRecord {
  final String title;
  final double amount;
  final DateTime dueDate;
  final bool isPaid;
  final String receiptId;

  FeeRecord({
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.isPaid,
    this.receiptId = '',
  });
}

class Announcement {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final bool isActive;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.isActive = true,
  });
}

class DummyData {
  static final StudentInfo currentStudent = StudentInfo(
    name: 'Alexander Davis',
    grade: 'Grade 10 - Science',
    profileUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
    overallProgress: 0.85,
  );

  static final List<ExamSession> exams = [
    ExamSession(
      title: 'Mid-Term Examination',
      date: 'Oct 15, 2026',
      subjects: [
        ExamMark(
          subject: 'Mathematics',
          marksObtained: 92,
          totalMarks: 100,
          grade: 'A',
        ),
        ExamMark(
          subject: 'Physics',
          marksObtained: 88,
          totalMarks: 100,
          grade: 'A',
        ),
        ExamMark(
          subject: 'Chemistry',
          marksObtained: 76,
          totalMarks: 100,
          grade: 'B+',
        ),
        ExamMark(
          subject: 'English',
          marksObtained: 95,
          totalMarks: 100,
          grade: 'A+',
        ),
      ],
    ),
    ExamSession(
      title: 'Unit Test 1',
      date: 'Aug 20, 2026',
      subjects: [
        ExamMark(
          subject: 'Mathematics',
          marksObtained: 45,
          totalMarks: 50,
          grade: 'A',
        ),
        ExamMark(
          subject: 'Physics',
          marksObtained: 42,
          totalMarks: 50,
          grade: 'A',
        ),
        ExamMark(
          subject: 'Chemistry',
          marksObtained: 38,
          totalMarks: 50,
          grade: 'B+',
        ),
        ExamMark(
          subject: 'English',
          marksObtained: 48,
          totalMarks: 50,
          grade: 'A+',
        ),
      ],
    ),
  ];

  static List<AttendanceRecord> get recentAttendance {
    final now = DateTime.now();
    return List.generate(14, (index) {
      final date = now.subtract(Duration(days: index));
      // Randomly make some absent, but mostly present
      final isPresent = index != 3 && index != 8;
      return AttendanceRecord(date: date, isPresent: isPresent);
    });
  }

  static final List<FeeRecord> fees = [
    FeeRecord(
      title: 'Term 2 Tuition Fee',
      amount: 1500.00,
      dueDate: DateTime.now().add(const Duration(days: 15)),
      isPaid: false,
    ),
    FeeRecord(
      title: 'Term 1 Tuition Fee',
      amount: 1500.00,
      dueDate: DateTime.now().subtract(const Duration(days: 75)),
      isPaid: true,
      receiptId: 'TXN-849201',
    ),
    FeeRecord(
      title: 'Annual Library Fee',
      amount: 250.00,
      dueDate: DateTime.now().subtract(const Duration(days: 120)),
      isPaid: true,
      receiptId: 'TXN-738192',
    ),
  ];

  static final List<Announcement> announcements = [
    Announcement(
      id: '1',
      title: 'Annual Sports Day 2026',
      description: 'The annual sports meet is scheduled for next Friday. All students are requested to participate in their respective house colors.',
      date: DateTime.now().add(const Duration(days: 5)),
    ),
    Announcement(
      id: '2',
      title: 'Parent-Teacher Meeting',
      description: 'Monthly PTM for discussing mid-term results will be held on Saturday from 9:00 AM to 1:00 PM.',
      date: DateTime.now().add(const Duration(days: 2)),
    ),
    Announcement(
      id: '3',
      title: 'Winter Vacation Update',
      description: 'Winter vacations will commence from Dec 20th. School will reopen on Jan 5th, 2027.',
      date: DateTime.now().add(const Duration(days: 40)),
    ),
  ];
}
