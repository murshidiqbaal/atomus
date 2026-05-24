import 'package:supabase_flutter/supabase_flutter.dart';

enum StudentAttendanceStatus { present, absent, late, unmarked }

extension StudentAttendanceStatusX on StudentAttendanceStatus {
  String get value {
    switch (this) {
      case StudentAttendanceStatus.present:
        return 'Present';
      case StudentAttendanceStatus.absent:
        return 'Absent';
      case StudentAttendanceStatus.late:
        return 'Late';
      case StudentAttendanceStatus.unmarked:
        return 'Unmarked';
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
      case 'unmarked':
        return StudentAttendanceStatus.unmarked;
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
  final StudentAttendanceStatus? originalStatus;
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
    this.status = StudentAttendanceStatus.unmarked,
    StudentAttendanceStatus? originalStatus,
    this.markedBy,
    this.markedAt,
    this.remarks,
    this.periodNumber,
    this.periodLabel,
  }) : originalStatus = originalStatus ?? status;

  factory StudentAttendanceEntry.fromStudentMap(
    Map<String, dynamic> studentMap, {
    required String subjectId,
    required DateTime date,
    Map<String, dynamic>? existingRecord,
  }) {
    final status = existingRecord != null
        ? StudentAttendanceStatusX.fromString(
            existingRecord['status'] as String? ?? 'Present',
          )
        : StudentAttendanceStatus.unmarked;
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
      status: status,
      originalStatus: status,
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
    // marked_by FK references auth.users(id), NOT teachers(id). The
    // teacher row id and the auth user id are different identifiers, so
    // sending the teacher id as marked_by raises a foreign-key violation
    // and the whole upsert is rejected.
    final authUserId = Supabase.instance.client.auth.currentUser?.id;
    return {
      // Intentionally omit `id`. A teacher writing from this screen must
      // never UPDATE-by-id over a row created by another teacher or an
      // admin. The unique index on (student_id, subject_id,
      // attendance_date) plus upsert ensures existing rows are updated.
      'student_id': studentId,
      if (subjectId.isNotEmpty) 'subject_id': subjectId,
      if (courseId != null && courseId!.isNotEmpty) 'course_id': courseId,
      if (batchId != null && batchId!.isNotEmpty) 'batch_id': batchId,
      if (campusId != null) 'campus_id': campusId,
      'attendance_date': attendanceDate.toIso8601String().split('T').first,
      'status': status.value,
      'marked_by': authUserId,
      'teacher_id': teacherId,
      'marked_at': DateTime.now().toIso8601String(),
      'attendance_marker_role': 'Teacher',
      if (teacherName != null) 'attendance_marker_name': teacherName,
      if (remarks != null) 'remarks': remarks,
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
      originalStatus: originalStatus,
      markedBy: markedBy,
      markedAt: markedAt,
      remarks: remarks ?? this.remarks,
      periodNumber: periodNumber ?? this.periodNumber,
      periodLabel: periodLabel ?? this.periodLabel,
    );
  }
}
