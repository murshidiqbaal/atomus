class StudentInfo {
  final String id;
  final String fullName;
  final String? admissionNumber;
  final String? rollNumber;
  final String? gender;
  final String? dateOfBirth;
  final String? grade;
  final double attendancePercentage;
  final String? progressStatus;
  final String? email;
  final String? phoneNumber;
  final String? relationship;
  final String? avatarUrl;

  StudentInfo({
    required this.id,
    required this.fullName,
    this.admissionNumber,
    this.rollNumber,
    this.gender,
    this.dateOfBirth,
    this.grade,
    this.attendancePercentage = 0.0,
    this.progressStatus = 'Average',
    this.email,
    this.phoneNumber,
    this.relationship,
    this.avatarUrl,
  });

  factory StudentInfo.fromMap(Map<String, dynamic> map) {
    return StudentInfo(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      admissionNumber: map['admission_number']?.toString(),
      rollNumber: map['roll_number']?.toString(),
      gender: map['gender'],
      dateOfBirth: map['date_of_birth']?.toString(),
      grade: map['grade'], // Fallback if grade is needed elsewhere
      attendancePercentage: (map['attendance_percentage'] ?? 0.0).toDouble(),
      progressStatus: map['progress_status'] ?? 'Average',
      email: map['email'],
      phoneNumber: map['phone_number']?.toString(),
      relationship: map['relationship'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'email': email,
      'phone_number': phoneNumber != null
          ? double.tryParse(phoneNumber!)
          : null,
      'relationship': relationship,
    };
  }

  String get name => fullName; // For backward compatibility
  double get overallProgress => attendancePercentage / 100.0;
  String get profileUrl => avatarUrl ?? 'https://i.pravatar.cc/150?u=$id';
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
  final String id;
  final String studentId;
  final String? batchId;
  final DateTime date;
  final String status; // 'Present', 'Absent', 'Late'

  AttendanceRecord({
    required this.id,
    required this.studentId,
    this.batchId,
    required this.date,
    required this.status,
  });

  bool get isPresent => status == 'Present' || status == 'Late';

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'].toString(),
      studentId: map['student_id'] ?? '',
      batchId: map['batch_id'],
      date: DateTime.parse(
        map['attendance_date'] ?? DateTime.now().toIso8601String(),
      ),
      status: map['status'] ?? 'Absent',
    );
  }
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
  final int priority; // Higher means more important

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.isActive = true,
    this.priority = 0,
  });

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      isActive: map['is_active'] ?? true,
      priority: map['priority'] ?? 0,
    );
  }
}

class Course {
  final String title;
  final String code;
  final String duration;
  final String instructor;

  Course({
    required this.title,
    required this.code,
    required this.duration,
    required this.instructor,
  });
}

class DummyData {
  static final List<Course> courses = [
    Course(
      title: 'Advanced Mathematics',
      code: 'MATH401',
      duration: '6 Months',
      instructor: 'Dr. Sarah Jenkins',
    ),
    Course(
      title: 'Quantum Physics',
      code: 'PHYS302',
      duration: '4 Months',
      instructor: 'Prof. Michael Chen',
    ),
    Course(
      title: 'Organic Chemistry',
      code: 'CHEM205',
      duration: '5 Months',
      instructor: 'Dr. Elena Rodriguez',
    ),
    Course(
      title: 'Computer Science',
      code: 'CS101',
      duration: '1 Year',
      instructor: 'James Wilson',
    ),
  ];

  static final StudentInfo currentStudent = StudentInfo(
    id: 'dummy-id-123',
    fullName: 'Alexander Davis',
    grade: 'Grade 10 - Science',
    avatarUrl: 'https://i.pravatar.cc/150?u=a042581f4e29026704d',
    attendancePercentage: 85.0,
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
      return AttendanceRecord(
        id: '',
        studentId: '',
        date: date,
        status: isPresent ? 'Present' : 'Absent',
      );
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
      description:
          'The annual sports meet is scheduled for next Friday. All students are requested to participate in their respective house colors.',
      date: DateTime.now().add(const Duration(days: 5)),
    ),
    Announcement(
      id: '2',
      title: 'Parent-Teacher Meeting',
      description:
          'Monthly PTM for discussing mid-term results will be held on Saturday from 9:00 AM to 1:00 PM.',
      date: DateTime.now().add(const Duration(days: 2)),
    ),
    Announcement(
      id: '3',
      title: 'Winter Vacation Update',
      description:
          'Winter vacations will commence from Dec 20th. School will reopen on Jan 5th, 2027.',
      date: DateTime.now().add(const Duration(days: 40)),
    ),
  ];
}
