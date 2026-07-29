class TeacherExam {
  final String id;
  final String name;
  final String? description;
  final DateTime? examDate;
  final String? courseId;
  final String? courseName;
  final String? batchId;
  final String? batchName;
  final String? subjectId;
  final String subjectName;
  final double totalMarks;
  final double? passingMarks;
  final bool isMarksEntered;
  final int pendingCount;
  final String? createdBy;
  final String? creatorRole;
  final String? creatorId;
  final bool isDaily;
  final DateTime? createdAt;
  final String? campusId;

  const TeacherExam({
    required this.id,
    required this.name,
    this.description,
    this.examDate,
    this.courseId,
    this.courseName,
    this.batchId,
    this.batchName,
    this.subjectId,
    required this.subjectName,
    required this.totalMarks,
    this.passingMarks,
    this.isMarksEntered = false,
    this.pendingCount = 0,
    this.createdBy,
    this.creatorRole,
    this.creatorId,
    this.isDaily = false,
    this.createdAt,
    this.campusId,
  });

  factory TeacherExam.fromMap(Map<String, dynamic> map) {
    final subject = map['subjects'] as Map<String, dynamic>?;
    final course = map['courses'] as Map<String, dynamic>?;
    final batch = map['batches'] as Map<String, dynamic>?;

    final marksList = map['marks'] as List?;
    final targetSubjectId = map['subject_id'] as String?;
    final marksForThisSubject =
        marksList?.where((m) {
          final ms = m as Map<String, dynamic>;
          return ms['subject_id'] == targetSubjectId;
        }) ??
        [];
    final isEntered = marksForThisSubject.isNotEmpty;

    return TeacherExam(
      id: map['id'] as String,
      name: map['name'] as String? ?? map['exam_name'] as String? ?? 'Exam',
      description: map['description'] as String?,
      examDate: map['exam_date'] != null
          ? DateTime.tryParse(map['exam_date'] as String)
          : null,
      courseId: map['course_id'] as String?,
      courseName: course?['name'] as String?,
      batchId: map['batch_id'] as String?,
      batchName: batch?['name'] as String?,
      subjectId: map['subject_id'] as String?,
      subjectName: subject?['name'] as String? ?? 'Course-Wide',
      totalMarks: (map['total_marks'] as num?)?.toDouble() ?? 100,
      passingMarks: (map['passing_marks'] as num?)?.toDouble(),
      isMarksEntered: isEntered,
      pendingCount: map['pending_count'] as int? ?? 0,
      createdBy: map['created_by'] as String?,
      creatorRole: map['creator_role'] as String?,
      creatorId: map['creator_id'] as String?,
      isDaily: map['is_daily'] as bool? ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      campusId: map['campus_id'] as String?,
    );
  }
}

class StudentMarksEntry {
  final String? id;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final String? admissionNumber;
  final String? profilePhotoDriveId;
  final String examId;
  final String? subjectId;
  final double? marksObtained;
  final double totalMarks;
  final bool isAbsent;
  final String? remarks;
  // The calendar day this entry's marks apply to. For regular exams
  // this equals the exam date; for daily exams it is the day the
  // marks were entered. Persisted as `marks.mark_date`.
  final DateTime markDate;

  StudentMarksEntry({
    this.id,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    this.admissionNumber,
    this.profilePhotoDriveId,
    required this.examId,
    this.subjectId,
    this.marksObtained,
    required this.totalMarks,
    this.isAbsent = false,
    this.remarks,
    required this.markDate,
  });

  factory StudentMarksEntry.fromStudentMap(
    Map<String, dynamic> studentMap, {
    required String examId,
    required String? subjectId,
    required double totalMarks,
    required DateTime markDate,
    Map<String, dynamic>? existingMarks,
  }) {
    final existingMarkDate = existingMarks?['mark_date'] != null
        ? DateTime.tryParse(existingMarks!['mark_date'] as String)
        : null;
    return StudentMarksEntry(
      id: existingMarks?['id'] as String?,
      studentId: studentMap['id'] as String,
      studentName: studentMap['full_name'] as String? ?? 'Student',
      rollNumber: studentMap['roll_number'] as String?,
      admissionNumber: studentMap['admission_number'] as String?,
      profilePhotoDriveId: (studentMap['profile_photo_drive_id'] ?? studentMap['image_url']) as String?,
      examId: examId,
      subjectId: subjectId ?? existingMarks?['subject_id'] as String?,
      marksObtained: (existingMarks?['marks_obtained'] as num?)?.toDouble(),
      totalMarks: totalMarks,
      isAbsent: existingMarks?['remarks'] == 'Absent',
      remarks: existingMarks?['remarks'] as String?,
      markDate: existingMarkDate ?? markDate,
    );
  }

  Map<String, dynamic> toUpsertMap({String? teacherId}) {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      'exam_id': examId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'marks_obtained': isAbsent ? 0 : marksObtained,
      'total_marks': totalMarks,
      'remarks': isAbsent ? 'Absent' : remarks,
      'mark_date': markDate.toIso8601String().split('T').first,
    };
  }

  double? get percentage =>
      (!isAbsent && marksObtained != null && totalMarks > 0)
      ? (marksObtained! / totalMarks) * 100
      : null;

  static const _unsetMarks = Object();

  StudentMarksEntry copyWith({
    Object? marksObtained = _unsetMarks,
    bool? isAbsent,
    String? remarks,
    DateTime? markDate,
  }) {
    return StudentMarksEntry(
      id: id,
      studentId: studentId,
      studentName: studentName,
      rollNumber: rollNumber,
      admissionNumber: admissionNumber,
      profilePhotoDriveId: profilePhotoDriveId,
      examId: examId,
      subjectId: subjectId,
      marksObtained: identical(marksObtained, _unsetMarks)
          ? this.marksObtained
          : marksObtained as double?,
      totalMarks: totalMarks,
      isAbsent: isAbsent ?? this.isAbsent,
      remarks: remarks ?? this.remarks,
      markDate: markDate ?? this.markDate,
    );
  }
}

class TeacherDashboardStats {
  final int todayClassCount;
  final double attendancePercentage;
  final bool hasActiveSession;
  final int upcomingExamCount;
  final int pendingMarksCount;
  final int weakStudentCount;
  final int unreadNotificationCount;
  final int monthlyAttendanceCount;

  const TeacherDashboardStats({
    this.todayClassCount = 0,
    this.attendancePercentage = 0,
    this.hasActiveSession = false,
    this.upcomingExamCount = 0,
    this.pendingMarksCount = 0,
    this.weakStudentCount = 0,
    this.unreadNotificationCount = 0,
    this.monthlyAttendanceCount = 0,
  });
}
