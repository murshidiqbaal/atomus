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
  final String? qualification;
  final int? experienceYears;
  final String? gender;
  final String? address;

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
    this.qualification,
    this.experienceYears,
    this.gender,
    this.address,
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
      qualification: map['qualification'] as String?,
      experienceYears: (map['experience_years'] as num?)?.toInt(),
      gender: map['gender'] as String?,
      address: map['address'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'employee_id': employeeId,
      'profile_photo_drive_id': profilePhotoDriveId,
      'campus_id': campusId,
      'is_active': isActive,
      'fcm_token': fcmToken,
      'qualification': qualification,
      'experience_years': experienceYears,
      'gender': gender,
      'address': address,
    };
  }

  bool get hasCampusCoordinates =>
      campusLatitude != null && campusLongitude != null;

  TeacherModel copyWith({
    String? fullName,
    String? phoneNumber,
    String? address,
    String? qualification,
    int? experienceYears,
    String? gender,
    String? profilePhotoDriveId,
    List<TeacherSubjectAssignment>? subjects,
    List<TeacherCourseAssignment>? courses,
  }) {
    return TeacherModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      employeeId: employeeId,
      profilePhotoDriveId: profilePhotoDriveId ?? this.profilePhotoDriveId,
      campusId: campusId,
      campusName: campusName,
      campusLatitude: campusLatitude,
      campusLongitude: campusLongitude,
      geofenceRadiusMeters: geofenceRadiusMeters,
      isActive: isActive,
      fcmToken: fcmToken,
      subjects: subjects ?? this.subjects,
      courses: courses ?? this.courses,
      qualification: qualification ?? this.qualification,
      experienceYears: experienceYears ?? this.experienceYears,
      gender: gender ?? this.gender,
      address: address ?? this.address,
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
