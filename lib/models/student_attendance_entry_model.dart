enum StudentAttendanceStatus { present, absent, late, leave }

extension StudentAttendanceStatusX on StudentAttendanceStatus {
  String get value {
    switch (this) {
      case StudentAttendanceStatus.present:
        return 'Present';
      case StudentAttendanceStatus.absent:
        return 'Absent';
      case StudentAttendanceStatus.late:
        return 'Late';
      case StudentAttendanceStatus.leave:
        return 'Leave';
    }
  }

  static StudentAttendanceStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'present':
        return StudentAttendanceStatus.present;
      case 'absent':
        return StudentAttendanceStatus.absent;
      case 'late':
        return StudentAttendanceStatus.late;
      case 'leave':
        return StudentAttendanceStatus.leave;
      default:
        return StudentAttendanceStatus.present;
    }
  }
}

class StudentAttendanceEntry {
  final String? id;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final String? admissionNumber;
  final String? profilePhotoDriveId;
  final String subjectId;
  final String? courseId;
  final String? batchId;
  final DateTime attendanceDate;
  final StudentAttendanceStatus status;
  final String? markedBy;
  final DateTime? markedAt;
  final String? remarks;
  final int? periodNumber;
  final String? periodLabel;

  StudentAttendanceEntry({
    this.id,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    this.admissionNumber,
    this.profilePhotoDriveId,
    required this.subjectId,
    this.courseId,
    this.batchId,
    required this.attendanceDate,
    this.status = StudentAttendanceStatus.present,
    this.markedBy,
    this.markedAt,
    this.remarks,
    this.periodNumber,
    this.periodLabel,
  });

  factory StudentAttendanceEntry.fromStudentMap(
    Map<String, dynamic> studentMap, {
    required String subjectId,
    required DateTime date,
    Map<String, dynamic>? existingRecord,
  }) {
    return StudentAttendanceEntry(
      id: existingRecord?['id'] as String?,
      studentId: studentMap['id'] as String,
      studentName: studentMap['full_name'] as String? ?? 'Student',
      rollNumber: studentMap['roll_number'] as String?,
      admissionNumber: studentMap['admission_number'] as String?,
      profilePhotoDriveId: studentMap['profile_photo_drive_id'] as String?,
      subjectId: subjectId,
      courseId: studentMap['course_id'] as String?,
      batchId: studentMap['batch_id'] as String?,
      attendanceDate: date,
      status: existingRecord != null
          ? StudentAttendanceStatusX.fromString(
              existingRecord['status'] as String? ?? 'Present',
            )
          : StudentAttendanceStatus.present,
      markedBy: existingRecord?['marked_by'] as String?,
      markedAt: existingRecord?['marked_at'] != null
          ? DateTime.parse(existingRecord!['marked_at'] as String)
          : null,
      remarks: existingRecord?['remarks'] as String?,
      periodNumber: existingRecord?['period_number'] as int?,
      periodLabel: existingRecord?['period_label'] as String?,
    );
  }

  Map<String, dynamic> toUpsertMap(
    String teacherId, {
    String? teacherName,
    String? campusId,
  }) {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      if (subjectId.isNotEmpty) 'subject_id': subjectId,
      if (courseId != null && courseId!.isNotEmpty) 'course_id': courseId,
      if (batchId != null && batchId!.isNotEmpty) 'batch_id': batchId,
      if (campusId != null) 'campus_id': campusId,
      'attendance_date': attendanceDate.toIso8601String().split('T').first,
      'status': status.value,
      'marked_by': teacherId,
      'marked_at': DateTime.now().toIso8601String(),
      'attendance_marker_role': 'Teacher',
      if (teacherName != null) 'attendance_marker_name': teacherName,
      if (remarks != null) 'remarks': remarks,
      if (periodNumber != null) 'period_number': periodNumber,
      if (periodLabel != null) 'period_label': periodLabel,
    };
  }

  StudentAttendanceEntry copyWith({
    StudentAttendanceStatus? status,
    String? remarks,
    int? periodNumber,
    String? periodLabel,
  }) {
    return StudentAttendanceEntry(
      id: id,
      studentId: studentId,
      studentName: studentName,
      rollNumber: rollNumber,
      admissionNumber: admissionNumber,
      profilePhotoDriveId: profilePhotoDriveId,
      subjectId: subjectId,
      courseId: courseId,
      batchId: batchId,
      attendanceDate: attendanceDate,
      status: status ?? this.status,
      markedBy: markedBy,
      markedAt: markedAt,
      remarks: remarks ?? this.remarks,
      periodNumber: periodNumber ?? this.periodNumber,
      periodLabel: periodLabel ?? this.periodLabel,
    );
  }
}
