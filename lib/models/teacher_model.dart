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
  final List<CampusLocation> campuses;
  final List<String> assignedCampuses;

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
    this.campuses = const [],
    this.assignedCampuses = const [],
  });

  factory TeacherModel.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? campusData,
    List<CampusLocation>? campuses,
  }) {
    List<CampusLocation> parsedCampuses = [];
    if (campuses != null) {
      parsedCampuses = campuses;
    } else if (map['campuses_list'] != null) {
      final list = map['campuses_list'] as List;
      parsedCampuses = list
          .map(
            (c) => CampusLocation.fromMap(Map<String, dynamic>.from(c as Map)),
          )
          .toList();
    }

    // Fallback: If parsedCampuses is empty, but we have primary campus coordinates on teacher, use that.
    if (parsedCampuses.isEmpty) {
      final pId = campusData?['id'] as String? ?? map['campus_id'] as String?;
      final pLat =
          (campusData?['latitude'] as num?)?.toDouble() ??
          (map['campus_latitude'] as num?)?.toDouble();
      final pLon =
          (campusData?['longitude'] as num?)?.toDouble() ??
          (map['campus_longitude'] as num?)?.toDouble();
      final pName =
          campusData?['name'] as String? ??
          map['campus_name'] as String? ??
          'Primary Campus';
      final pRad =
          (campusData?['geofence_radius_meters'] as int?) ??
          (map['geofence_radius_meters'] as int?) ??
          25;

      if (pId != null && pLat != null && pLon != null) {
        parsedCampuses = [
          CampusLocation(
            id: pId,
            name: pName,
            latitude: pLat,
            longitude: pLon,
            radiusMeters: pRad,
          ),
        ];
      }
    }

    final assignedCampusesRaw = map['assigned_campuses'];
    final List<String> assignedCampuses = assignedCampusesRaw is List
        ? assignedCampusesRaw.map((e) => e.toString()).toList()
        : [];

    final subjectsRaw = map['subjects'];
    final List<TeacherSubjectAssignment> subjects = subjectsRaw is List
        ? subjectsRaw
              .map(
                (e) => TeacherSubjectAssignment.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
        : [];

    final coursesRaw = map['courses'];
    final List<TeacherCourseAssignment> courses = coursesRaw is List
        ? coursesRaw
              .map(
                (e) => TeacherCourseAssignment.fromMap(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
        : [];

    return TeacherModel(
      id: map['id'] as String,
      fullName:
          map['full_name'] as String? ?? map['name'] as String? ?? 'Teacher',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phone_number'] as String?,
      employeeId: map['employee_id'] as String?,
      profilePhotoDriveId: map['profile_photo_drive_id'] as String?,
      campusId: campusData?['id'] as String? ?? map['campus_id'] as String?,
      campusName: campusData?['name'] as String?,
      campusLatitude:
          (campusData?['latitude'] as num?)?.toDouble() ??
          (map['campus_latitude'] as num?)?.toDouble(),
      campusLongitude:
          (campusData?['longitude'] as num?)?.toDouble() ??
          (map['campus_longitude'] as num?)?.toDouble(),
      geofenceRadiusMeters:
          (campusData?['geofence_radius_meters'] as int?) ??
          (map['geofence_radius_meters'] as int?) ??
          25,
      isActive: map['is_active'] as bool? ?? true,
      fcmToken: map['fcm_token'] as String?,
      subjects: subjects,
      courses: courses,
      qualification: map['qualification'] as String?,
      experienceYears: (map['experience_years'] as num?)?.toInt(),
      gender: map['gender'] as String?,
      address: map['address'] as String?,
      campuses: parsedCampuses,
      assignedCampuses: assignedCampuses,
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
      'campus_name': campusName,
      'campus_latitude': campusLatitude,
      'campus_longitude': campusLongitude,
      'geofence_radius_meters': geofenceRadiusMeters,
      'assigned_campuses': assignedCampuses,
      'campuses_list': campuses
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'latitude': c.latitude,
              'longitude': c.longitude,
              'geofence_radius_meters': c.radiusMeters,
            },
          )
          .toList(),
      'subjects': subjects.map((s) => s.toMap()).toList(),
      'courses': courses.map((c) => c.toMap()).toList(),
    };
  }

  bool get hasCampusCoordinates =>
      (campusLatitude != null && campusLongitude != null) ||
      (campuses.isNotEmpty && campuses.any((c) => c.hasCoordinates));

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
    List<CampusLocation>? campuses,
    List<String>? assignedCampuses,
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
      campuses: campuses ?? this.campuses,
      assignedCampuses: assignedCampuses ?? this.assignedCampuses,
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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'course_id': courseId,
      'course_name': courseName,
      'batch_id': batchId,
      'batch_name': batchName,
      'campus_id': campusId,
      'is_active': isActive,
    };
  }

  factory TeacherSubjectAssignment.fromMap(Map<String, dynamic> map) {
    final subject = map['subjects'] as Map<String, dynamic>?;
    final course = map['courses'] as Map<String, dynamic>?;
    final batch = map['batches'] as Map<String, dynamic>?;
    return TeacherSubjectAssignment(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String,
      subjectName:
          subject?['name'] as String? ??
          map['subject_name'] as String? ??
          map['subject_id'] as String,
      courseId: map['course_id'] as String?,
      courseName: course?['name'] as String? ?? map['course_name'] as String?,
      batchId: map['batch_id'] as String?,
      batchName: batch?['name'] as String? ?? map['batch_name'] as String?,
      campusId: map['campus_id'] as String?,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      '$subjectName${batchName != null ? " · $batchName" : ""}';
}

class CampusLocation {
  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;

  const CampusLocation({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.radiusMeters = 25,
  });

  factory CampusLocation.fromMap(Map<String, dynamic> map) {
    return CampusLocation(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      radiusMeters: (map['geofence_radius_meters'] as int?) ?? 25,
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  String get shortCode {
    final lower = name.toLowerCase();
    if (lower.contains('aroor') || lower.contains('campus 1') || lower.contains('arr')) {
      return 'ARR';
    } else if (lower.contains('piravom') || lower.contains('campus 2') || lower.contains('prv')) {
      return 'PRV';
    } else if (lower.contains('main')) {
      return 'MAIN';
    }
    return name.toUpperCase();
  }

  String get displayName {
    final lower = name.toLowerCase();
    if (lower.contains('aroor') || lower.contains('campus 1') || lower.contains('arr')) {
      return 'ARR - Campus 1 Aroor';
    } else if (lower.contains('piravom') || lower.contains('campus 2') || lower.contains('prv')) {
      return 'PRV - Campus 2 Piravom';
    } else if (lower.contains('main')) {
      return 'MAIN - Main Campus';
    }
    return name;
  }

  bool get isMain => name.toLowerCase().contains('main');
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
    required String teacherId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'course_name': courseName,
      'campus_id': campusId,
    };
  }

  factory TeacherCourseAssignment.fromMap(Map<String, dynamic> map) {
    final course = map['courses'] as Map<String, dynamic>?;
    return TeacherCourseAssignment(
      id: map['id'] as String,
      courseId: map['course_id'] as String,
      courseName:
          course?['name'] as String? ??
          map['course_name'] as String? ??
          map['course_id'] as String,
      campusId: map['campus_id'] as String?,
      teacherId: map['teacher_id'],
    );
  }

  @override
  String toString() => courseName;
}
