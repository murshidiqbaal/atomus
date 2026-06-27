enum TeacherAttendanceStatus { active, completed, missed }

extension TeacherAttendanceStatusX on TeacherAttendanceStatus {
  String get value {
    switch (this) {
      case TeacherAttendanceStatus.active:    return 'Active';
      case TeacherAttendanceStatus.completed: return 'Completed';
      case TeacherAttendanceStatus.missed:    return 'Missed';
    }
  }

  static TeacherAttendanceStatus fromString(String s) {
    switch (s) {
      case 'Active':    return TeacherAttendanceStatus.active;
      case 'Completed': return TeacherAttendanceStatus.completed;
      default:          return TeacherAttendanceStatus.missed;
    }
  }
}

class TeacherAttendanceModel {
  final String? id;
  final String teacherId;
  final String? campusId;
  final String? subjectId;
  final String? subjectName;
  final String? courseId;
  final String? batchId;
  final DateTime attendanceDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? totalDurationMinutes;
  final double? latitude;
  final double? longitude;
  final TeacherAttendanceStatus status;
  final DateTime createdAt;
  final String sessionType;

  TeacherAttendanceModel({
    this.id,
    required this.teacherId,
    this.campusId,
    this.subjectId,
    this.subjectName,
    this.courseId,
    this.batchId,
    required this.attendanceDate,
    this.startTime,
    this.endTime,
    int? totalDurationMinutes,
    this.latitude,
    this.longitude,
    this.status = TeacherAttendanceStatus.active,
    DateTime? createdAt,
    this.sessionType = 'forenoon',
  })  : totalDurationMinutes = (startTime != null && endTime != null
            ? endTime.difference(startTime).inMinutes
            : totalDurationMinutes),
        createdAt = createdAt ?? DateTime.now();

  factory TeacherAttendanceModel.fromMap(Map<String, dynamic> map) {
    final subject = map['subjects'] as Map<String, dynamic>?;
    final start = map['start_time'] != null
        ? DateTime.parse(map['start_time'] as String)
        : null;
    final end = map['end_time'] != null
        ? DateTime.parse(map['end_time'] as String)
        : null;
    final duration = (start != null && end != null)
        ? end.difference(start).inMinutes
        : (map['total_duration_minutes'] as int?);

    return TeacherAttendanceModel(
      id:                   map['id'] as String?,
      teacherId:            map['teacher_id'] as String,
      campusId:             map['campus_id'] as String?,
      subjectId:            map['subject_id'] as String?,
      subjectName:          subject?['name'] as String?,
      courseId:             map['course_id'] as String?,
      batchId:              map['batch_id'] as String?,
      attendanceDate:       DateTime.parse(map['attendance_date'] as String),
      startTime:            start,
      endTime:              end,
      totalDurationMinutes: duration,
      latitude:             (map['latitude'] as num?)?.toDouble(),
      longitude:            (map['longitude'] as num?)?.toDouble(),
      status:               TeacherAttendanceStatusX.fromString(
                              map['attendance_status'] as String? ?? 'Active'),
      createdAt:            map['created_at'] != null
                              ? DateTime.parse(map['created_at'] as String)
                              : DateTime.now(),
      sessionType:          map['session_type'] as String? ?? 'forenoon',
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'teacher_id':       teacherId,
      if (campusId  != null) 'campus_id':  campusId,
      if (subjectId != null) 'subject_id': subjectId,
      if (courseId  != null) 'course_id':  courseId,
      if (batchId   != null) 'batch_id':   batchId,
      'attendance_date':  attendanceDate.toIso8601String().split('T').first,
      if (startTime != null) 'start_time': startTime!.toIso8601String(),
      if (endTime   != null) 'end_time':   endTime!.toIso8601String(),
      if (latitude  != null) 'latitude':   latitude,
      if (longitude != null) 'longitude':  longitude,
      'attendance_status': status.value,
      'session_type':     sessionType,
    };
  }

  bool get isActive    => status == TeacherAttendanceStatus.active;
  bool get isCompleted => status == TeacherAttendanceStatus.completed;

  bool get isLate {
    if (startTime == null) return false;
    final localStart = startTime!.toLocal();
    final limit = DateTime(
      localStart.year,
      localStart.month,
      localStart.day,
      10,
      0,
    );
    return localStart.isAfter(limit);
  }

  String get durationLabel {
    if (startTime == null || endTime == null) {
      final minutes = totalDurationMinutes;
      if (minutes == null) return '--';
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }
    final diff = endTime!.difference(startTime!);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;

    if (h > 0) {
      return '${h}h ${m}m';
    } else if (m > 0) {
      return '${m}m ${s}s';
    } else {
      return '${s}s';
    }
  }

  TeacherAttendanceModel copyWith({
    String? id,
    DateTime? endTime,
    TeacherAttendanceStatus? status,
    int? totalDurationMinutes,
    String? sessionType,
  }) {
    return TeacherAttendanceModel(
      id:                   id ?? this.id,
      teacherId:            teacherId,
      campusId:             campusId,
      subjectId:            subjectId,
      subjectName:          subjectName,
      courseId:             courseId,
      batchId:              batchId,
      attendanceDate:       attendanceDate,
      startTime:            startTime,
      endTime:              endTime ?? this.endTime,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      latitude:             latitude,
      longitude:            longitude,
      status:               status ?? this.status,
      createdAt:            createdAt,
      sessionType:          sessionType ?? this.sessionType,
    );
  }
}
