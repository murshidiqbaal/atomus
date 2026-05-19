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
  final String? courseId;

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
    this.courseId,
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
      courseId: map['course_id']?.toString(),
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
      'course_id': courseId,
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
  final String? subjectId;

  ExamMark({
    required this.subject,
    required this.marksObtained,
    required this.totalMarks,
    required this.grade,
    this.subjectId,
  });

  factory ExamMark.fromMap(Map<String, dynamic> map) {
    return ExamMark(
      subject: map['subjects']?['name'] ?? map['subjects']?['subject_name'] ?? map['subject_name'] ?? 'General',
      marksObtained: (map['marks_obtained'] ?? 0).toInt(),
      totalMarks: (map['total_marks'] ?? 100).toInt(),
      grade: map['grade'] ?? (map['remarks']?.toString().isNotEmpty == true ? map['remarks'] : 'N/A'),
      subjectId: map['subject_id']?.toString(),
    );
  }
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

  factory ExamSession.fromMap(Map<String, dynamic> map, List<ExamMark> subjects) {
    final examData = map['exams'] ?? map;
    return ExamSession(
      title: examData['name'] ?? examData['title'] ?? 'Examination',
      date: examData['exam_date'] ?? 'N/A',
      subjects: subjects,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String? batchId;
  final String? courseId;
  final String? subjectId;
  final DateTime date;
  final String status; // 'Present', 'Absent', 'Late'
  final int? periodNumber;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    this.batchId,
    this.courseId,
    this.subjectId,
    required this.date,
    required this.status,
    this.periodNumber,
  });

  bool get isPresent => status == 'Present' || status == 'Late';

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'].toString(),
      studentId: map['student_id'] ?? '',
      batchId: map['batch_id'],
      courseId: map['course_id'],
      subjectId: map['subject_id'],
      date: DateTime.parse(
        map['attendance_date'] ?? DateTime.now().toIso8601String(),
      ),
      status: map['status'] ?? 'Absent',
      periodNumber: map['period_number'] != null ? int.tryParse(map['period_number'].toString()) : null,
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
  final String? imageUrl;
  final String type;
  final String targetAudience;
  final String? courseId;
  final String? batchId;
  final bool isPopup;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.type = 'General Announcement',
    this.targetAudience = 'All',
    this.courseId,
    this.batchId,
    this.isPopup = false,
    this.isActive = true,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  // Helper for UI priority logic
  int get priority => type == 'Urgent' ? 10 : 0;

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'].toString(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'],
      type: map['type'] ?? 'General Announcement',
      targetAudience: map['target_audience'] ?? 'All',
      courseId: map['course_id']?.toString(),
      batchId: map['batch_id']?.toString(),
      isPopup: map['is_popup'] ?? false,
      isActive: map['is_active'] ?? true,
      startDate: DateTime.parse(
        map['start_date'] ?? DateTime.now().toIso8601String(),
      ),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class Course {
  final String id;
  final String name;
  final String? description;
  final int? durationMonths;
  final String courseType;
  final String? classLevel;
  final double feeAmount;
  final String mode;
  final String? thumbnailUrl;
  final bool isActive;

  Course({
    required this.id,
    required this.name,
    this.description,
    this.durationMonths,
    required this.courseType,
    this.classLevel,
    required this.feeAmount,
    required this.mode,
    this.thumbnailUrl,
    required this.isActive,
  });

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      durationMonths: map['duration_months'] != null 
          ? (map['duration_months'] as num).toInt() 
          : null,
      courseType: map['course_type'] ?? 'Regular',
      classLevel: map['class_level'],
      feeAmount: (map['fee_amount'] ?? 0.0).toDouble(),
      mode: map['mode'] ?? 'Offline',
      thumbnailUrl: map['thumbnail_url'],
      isActive: map['is_active'] ?? true,
    );
  }
}

class Subject {
  final String id;
  final String? courseId;
  final String name;
  final String? subjectCode;
  final String? subjectType;
  final String? classLevel;
  final bool isActive;

  Subject({
    required this.id,
    this.courseId,
    required this.name,
    this.subjectCode,
    this.subjectType,
    this.classLevel,
    this.isActive = true,
  });

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString(),
      name: map['name'] ?? '',
      subjectCode: map['subject_code'],
      subjectType: map['subject_type'],
      classLevel: map['class_level'],
      isActive: map['is_active'] ?? true,
    );
  }
}

class DummyData {
  static final List<Course> courses = [
    Course(
      id: '1',
      name: 'Advanced Mathematics',
      courseType: 'Regular',
      classLevel: 'Class 12',
      feeAmount: 150.0,
      mode: 'Offline',
      isActive: true,
      durationMonths: 6,
    ),
    Course(
      id: '2',
      name: 'Quantum Physics',
      courseType: 'Foundation',
      classLevel: 'Graduation',
      feeAmount: 200.0,
      mode: 'Hybrid',
      isActive: true,
      durationMonths: 4,
    ),
    Course(
      id: '3',
      name: 'Organic Chemistry',
      courseType: 'Crash Course',
      classLevel: 'Class 12',
      feeAmount: 120.0,
      mode: 'Online',
      isActive: true,
      durationMonths: 2,
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
      startDate: DateTime.now().add(const Duration(days: 5)),
      createdAt: DateTime.now(),
    ),
    Announcement(
      id: '2',
      title: 'Parent-Teacher Meeting',
      description:
          'Monthly PTM for discussing mid-term results will be held on Saturday from 9:00 AM to 1:00 PM.',
      startDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now(),
    ),
    Announcement(
      id: '3',
      title: 'Winter Vacation Update',
      description:
          'Winter vacations will commence from Dec 20th. School will reopen on Jan 5th, 2027.',
      startDate: DateTime.now().add(const Duration(days: 40)),
      createdAt: DateTime.now(),
    ),
  ];
}
