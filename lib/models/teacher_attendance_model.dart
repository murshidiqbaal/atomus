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
  final double? punchOutLatitude;
  final double? punchOutLongitude;
  final String? punchInLocation;
  final String? punchOutLocation;
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
    this.punchOutLatitude,
    this.punchOutLongitude,
    this.punchInLocation,
    this.punchOutLocation,
    this.status = TeacherAttendanceStatus.active,
    DateTime? createdAt,
    this.sessionType = 'session',
  })  : totalDurationMinutes = (startTime != null && endTime != null
            ? endTime.difference(startTime).inMinutes
            : totalDurationMinutes),
        createdAt = createdAt ?? DateTime.now();

  DateTime? get punchIn => startTime;
  DateTime? get punchOut => endTime;

  factory TeacherAttendanceModel.fromMap(Map<String, dynamic> map) {
    final subject = map['subjects'] as Map<String, dynamic>?;
    final start = map['start_time'] != null
        ? _parseDateTime(map['start_time'])
        : (map['punch_in'] != null ? _parseDateTime(map['punch_in']) : null);
    final end = map['end_time'] != null
        ? _parseDateTime(map['end_time'])
        : (map['punch_out'] != null ? _parseDateTime(map['punch_out']) : null);
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
      attendanceDate:       _parseDateTime(map['attendance_date']),
      startTime:            start,
      endTime:              end,
      totalDurationMinutes: duration,
      latitude:             (map['latitude'] as num?)?.toDouble() ?? (map['punch_in_latitude'] as num?)?.toDouble(),
      longitude:            (map['longitude'] as num?)?.toDouble() ?? (map['punch_in_longitude'] as num?)?.toDouble(),
      punchOutLatitude:     (map['punch_out_latitude'] as num?)?.toDouble(),
      punchOutLongitude:    (map['punch_out_longitude'] as num?)?.toDouble(),
      punchInLocation:      map['punch_in_location'] as String?,
      punchOutLocation:     map['punch_out_location'] as String?,
      status:               TeacherAttendanceStatusX.fromString(
                              map['attendance_status'] as String? ?? (end != null ? 'Completed' : 'Active')),
      createdAt:            map['created_at'] != null
                              ? _parseDateTime(map['created_at'])
                              : DateTime.now(),
      sessionType:          map['session_type'] as String? ?? 'session',
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value.toLocal();
    final str = value as String;
    final parsed = DateTime.parse(str);
    // Auto-detect timezone mismatch (legacy local times stored as UTC)
    if (parsed.isUtc &&
        parsed.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5)))) {
      return DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
      );
    }
    return parsed.toLocal();
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'teacher_id':          teacherId,
      if (campusId  != null) 'campus_id':          campusId,
      if (subjectId != null) 'subject_id':         subjectId,
      if (courseId  != null) 'course_id':          courseId,
      if (batchId   != null) 'batch_id':           batchId,
      'attendance_date':     attendanceDate.toIso8601String().split('T').first,
      if (startTime != null) 'start_time':         startTime!.toUtc().toIso8601String(),
      if (endTime   != null) 'end_time':           endTime!.toUtc().toIso8601String(),
      if (latitude  != null) 'latitude':           latitude,
      if (longitude != null) 'longitude':          longitude,
      if (punchOutLatitude  != null) 'punch_out_latitude':  punchOutLatitude,
      if (punchOutLongitude != null) 'punch_out_longitude': punchOutLongitude,
      if (punchInLocation   != null) 'punch_in_location':   punchInLocation,
      if (punchOutLocation  != null) 'punch_out_location':  punchOutLocation,
      'attendance_status':   status.value,
      'session_type':        sessionType,
    };
  }

  bool get isActive    => status == TeacherAttendanceStatus.active && endTime == null;
  bool get isCompleted => status == TeacherAttendanceStatus.completed || endTime != null;

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
    double? punchOutLatitude,
    double? punchOutLongitude,
    String? punchOutLocation,
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
      punchOutLatitude:     punchOutLatitude ?? this.punchOutLatitude,
      punchOutLongitude:    punchOutLongitude ?? this.punchOutLongitude,
      punchInLocation:      punchInLocation,
      punchOutLocation:     punchOutLocation ?? this.punchOutLocation,
      status:               status ?? this.status,
      createdAt:            createdAt,
      sessionType:          sessionType ?? this.sessionType,
    );
  }
}
