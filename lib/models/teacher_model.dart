class TeacherModel {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? employeeId;
  final String? profilePhotoDriveId;
  final String? campusId;
  final String? campusName;
  final double? campusLatitude;
  final double? campusLongitude;
  final int geofenceRadiusMeters;
  final bool isActive;
  final String? fcmToken;
  final List<TeacherSubjectAssignment> subjects;
  final List<TeacherCourseAssignment> courses;

  const TeacherModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.employeeId,
    this.profilePhotoDriveId,
    this.campusId,
    this.campusName,
    this.campusLatitude,
    this.campusLongitude,
    this.geofenceRadiusMeters = 25,
    this.isActive = true,
    this.fcmToken,
    this.subjects = const [],
    this.courses = const [],
  });

  factory TeacherModel.fromMap(Map<String, dynamic> map, {Map<String, dynamic>? campusData}) {
    return TeacherModel(
      id: map['id'] as String,
      fullName: map['full_name'] as String? ?? map['name'] as String? ?? 'Teacher',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phone_number'] as String?,
      employeeId: map['employee_id'] as String?,
      profilePhotoDriveId: map['profile_photo_drive_id'] as String?,
      campusId: campusData?['id'] as String? ?? map['campus_id'] as String?,
      campusName: campusData?['name'] as String?,
      campusLatitude: (campusData?['latitude'] as num?)?.toDouble(),
      campusLongitude: (campusData?['longitude'] as num?)?.toDouble(),
      geofenceRadiusMeters: (campusData?['geofence_radius_meters'] as int?) ?? 25,
      isActive: map['is_active'] as bool? ?? true,
      fcmToken: map['fcm_token'] as String?,
    );
  }

  bool get hasCampusCoordinates =>
      campusLatitude != null && campusLongitude != null;

  TeacherModel copyWith({
    List<TeacherSubjectAssignment>? subjects,
    List<TeacherCourseAssignment>? courses,
  }) {
    return TeacherModel(
      id: id,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      employeeId: employeeId,
      profilePhotoDriveId: profilePhotoDriveId,
      campusId: campusId,
      campusName: campusName,
      campusLatitude: campusLatitude,
      campusLongitude: campusLongitude,
      geofenceRadiusMeters: geofenceRadiusMeters,
      isActive: isActive,
      fcmToken: fcmToken,
      subjects: subjects ?? this.subjects,
      courses: courses ?? this.courses,
    );
  }
}

class TeacherSubjectAssignment {
  final String id;
  final String subjectId;
  final String subjectName;
  final String? courseId;
  final String? courseName;
  final String? batchId;
  final String? batchName;
  final String? campusId;
  final bool isActive;

  const TeacherSubjectAssignment({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    this.courseId,
    this.courseName,
    this.batchId,
    this.batchName,
    this.campusId,
    this.isActive = true,
  });

  factory TeacherSubjectAssignment.fromMap(Map<String, dynamic> map) {
    final subject = map['subjects'] as Map<String, dynamic>?;
    final course  = map['courses']  as Map<String, dynamic>?;
    final batch   = map['batches']  as Map<String, dynamic>?;
    return TeacherSubjectAssignment(
      id:          map['id'] as String,
      subjectId:   map['subject_id'] as String,
      subjectName: subject?['name'] as String? ?? map['subject_id'] as String,
      courseId:    map['course_id'] as String?,
      courseName:  course?['name'] as String?,
      batchId:     map['batch_id'] as String?,
      batchName:   batch?['name'] as String?,
      campusId:    map['campus_id'] as String?,
      isActive:    map['is_active'] as bool? ?? true,
    );
  }

  @override
  String toString() => '$subjectName${batchName != null ? " · $batchName" : ""}';
}

class CampusLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  const CampusLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 25,
  });

  factory CampusLocation.fromMap(Map<String, dynamic> map) {
    return CampusLocation(
      id:           map['id'] as String,
      name:         map['name'] as String,
      latitude:     (map['latitude'] as num).toDouble(),
      longitude:    (map['longitude'] as num).toDouble(),
      radiusMeters: (map['geofence_radius_meters'] as int?) ?? 25,
    );
  }
}

class TeacherCourseAssignment {
  final String id;
  final String courseId;
  final String courseName;
  final String? campusId;

  const TeacherCourseAssignment({
    required this.id,
    required this.courseId,
    required this.courseName,
    this.campusId,
  });

  factory TeacherCourseAssignment.fromMap(Map<String, dynamic> map) {
    final course = map['courses'] as Map<String, dynamic>?;
    return TeacherCourseAssignment(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      courseName: course?['name'] as String? ?? map['course_id'] as String,
      campusId: map['campus_id'] as String?,
    );
  }

  @override
  String toString() => courseName;
}
