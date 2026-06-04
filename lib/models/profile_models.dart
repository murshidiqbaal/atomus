import '../utils/drive_image_helper.dart';

enum ProfileUploadTarget { parent, student, teacher }

extension ProfileUploadTargetX on ProfileUploadTarget {
  String get apiValue {
    switch (this) {
      case ProfileUploadTarget.parent:
        return 'parent';
      case ProfileUploadTarget.student:
        return 'student';
      case ProfileUploadTarget.teacher:
        return 'teacher';
    }
  }

  String get displayName {
    switch (this) {
      case ProfileUploadTarget.parent:
        return 'Parent';
      case ProfileUploadTarget.student:
        return 'Student';
      case ProfileUploadTarget.teacher:
        return 'Teacher';
    }
  }

  static ProfileUploadTarget fromApiValue(String value) {
    switch (value) {
      case 'student':
        return ProfileUploadTarget.student;
      case 'teacher':
        return ProfileUploadTarget.teacher;
      default:
        return ProfileUploadTarget.parent;
    }
  }
}

class ParentProfile {
  const ParentProfile({
    required this.id,
    required this.fullName,
    this.authUserId,
    this.email,
    this.phoneNumber,
    this.address,
    this.profilePhotoDriveId,
    this.accountStatus,
    this.secondaryContactName,
    this.secondaryContactPhone,
    this.secondaryContactEmail,
    this.secondaryContactRelationship,
  });

  final String id;
  final String? authUserId;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? profilePhotoDriveId;
  final String? accountStatus;
  final String? secondaryContactName;
  final String? secondaryContactPhone;
  final String? secondaryContactEmail;
  final String? secondaryContactRelationship;

  factory ParentProfile.fromMap(Map<String, dynamic> map) {
    final driveId = map['profile_photo_drive_id']?.toString() ?? 
                    DriveImageHelper.extractDriveId(map['profile_photo_url']?.toString());
    return ParentProfile(
      id: map['id']?.toString() ?? '',
      authUserId: map['auth_user_id']?.toString() ?? map['auth_id']?.toString(),
      fullName: map['full_name']?.toString() ?? '',
      email: map['email']?.toString(),
      phoneNumber: map['phone_number']?.toString(),
      address: map['address']?.toString(),
      profilePhotoDriveId: driveId,
      accountStatus: map['account_status']?.toString(),
      secondaryContactName: map['secondary_contact_name']?.toString(),
      secondaryContactPhone: map['secondary_contact_phone']?.toString(),
      secondaryContactEmail: map['secondary_contact_email']?.toString(),
      secondaryContactRelationship: map['secondary_contact_relationship']
          ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_user_id': authUserId,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'address': address,
      'profile_photo_drive_id': profilePhotoDriveId,
      'account_status': accountStatus,
      'secondary_contact_name': secondaryContactName,
      'secondary_contact_phone': secondaryContactPhone,
      'secondary_contact_email': secondaryContactEmail,
      'secondary_contact_relationship': secondaryContactRelationship,
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'full_name': fullName.trim(),
      'phone_number': phoneNumber?.trim(),
      'address': address?.trim(),
      'secondary_contact_name': secondaryContactName?.trim(),
      'secondary_contact_phone': secondaryContactPhone?.trim(),
      'secondary_contact_email': secondaryContactEmail?.trim(),
      'secondary_contact_relationship': secondaryContactRelationship?.trim(),
    };
  }

  ParentProfile copyWith({
    String? id,
    String? authUserId,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? address,
    String? profilePhotoDriveId,
    String? accountStatus,
    String? secondaryContactName,
    String? secondaryContactPhone,
    String? secondaryContactEmail,
    String? secondaryContactRelationship,
  }) {
    return ParentProfile(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      profilePhotoDriveId: profilePhotoDriveId ?? this.profilePhotoDriveId,
      accountStatus: accountStatus ?? this.accountStatus,
      secondaryContactName: secondaryContactName ?? this.secondaryContactName,
      secondaryContactPhone:
          secondaryContactPhone ?? this.secondaryContactPhone,
      secondaryContactEmail:
          secondaryContactEmail ?? this.secondaryContactEmail,
      secondaryContactRelationship:
          secondaryContactRelationship ?? this.secondaryContactRelationship,
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}

class LinkedStudentProfile {
  const LinkedStudentProfile({
    required this.id,
    required this.parentId,
    required this.fullName,
    this.admissionNumber,
    this.rollNumber,
    this.courseId,
    this.batchId,
    this.campusId,
    this.courseName,
    this.batchName,
    this.campusName,
    this.email,
    this.phoneNumber,
    this.profilePhotoDriveId,
    this.bloodGroup,
    this.allergies,
    this.medicalConditions,
    this.dob,
  });

  final String id;
  final String parentId;
  final String fullName;
  final String? admissionNumber;
  final String? rollNumber;
  final String? courseId;
  final String? batchId;
  final String? campusId;
  final String? courseName;
  final String? batchName;
  final String? campusName;
  final String? email;
  final String? phoneNumber;
  final String? profilePhotoDriveId;
  final String? bloodGroup;
  final String? allergies;
  final String? medicalConditions;
  final String? dob;

  factory LinkedStudentProfile.fromMap(Map<String, dynamic> map) {
    final course = map['courses'] is Map<String, dynamic>
        ? map['courses'] as Map<String, dynamic>
        : null;
    final batch = map['batches'] is Map<String, dynamic>
        ? map['batches'] as Map<String, dynamic>
        : null;
    final campus = map['campuses'] is Map<String, dynamic>
        ? map['campuses'] as Map<String, dynamic>
        : null;

    final driveId = map['profile_photo_drive_id']?.toString() ?? 
                    DriveImageHelper.extractDriveId(map['profile_photo_url']?.toString());

    return LinkedStudentProfile(
      id: map['id']?.toString() ?? '',
      parentId: map['parent_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      admissionNumber: map['admission_number']?.toString(),
      rollNumber: map['roll_number']?.toString(),
      courseId: map['course_id']?.toString(),
      batchId: map['batch_id']?.toString(),
      campusId: map['campus_id']?.toString(),
      courseName: course?['name']?.toString() ?? map['course_name']?.toString(),
      batchName: batch?['name']?.toString() ?? map['batch_name']?.toString(),
      campusName: campus?['name']?.toString() ?? map['campus_name']?.toString(),
      email: map['student_email']?.toString() ?? map['email']?.toString(),
      phoneNumber:
          map['student_phone']?.toString() ?? map['phone_number']?.toString(),
      profilePhotoDriveId: driveId,
      bloodGroup: map['blood_group']?.toString(),
      allergies: map['allergies']?.toString(),
      medicalConditions: map['medical_conditions']?.toString(),
      dob: map['dob']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'full_name': fullName,
      'admission_number': admissionNumber,
      'roll_number': rollNumber,
      'course_id': courseId,
      'batch_id': batchId,
      'campus_id': campusId,
      'course_name': courseName,
      'batch_name': batchName,
      'campus_name': campusName,
      'email': email,
      'phone_number': phoneNumber,
      'profile_photo_drive_id': profilePhotoDriveId,
      'blood_group': bloodGroup,
      'allergies': allergies,
      'medical_conditions': medicalConditions,
      'dob': dob,
    };
  }

  LinkedStudentProfile copyWith({
    String? id,
    String? parentId,
    String? fullName,
    String? admissionNumber,
    String? rollNumber,
    String? courseId,
    String? batchId,
    String? campusId,
    String? courseName,
    String? batchName,
    String? campusName,
    String? email,
    String? phoneNumber,
    String? profilePhotoDriveId,
    String? bloodGroup,
    String? allergies,
    String? medicalConditions,
    String? dob,
  }) {
    return LinkedStudentProfile(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      fullName: fullName ?? this.fullName,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      rollNumber: rollNumber ?? this.rollNumber,
      courseId: courseId ?? this.courseId,
      batchId: batchId ?? this.batchId,
      campusId: campusId ?? this.campusId,
      courseName: courseName ?? this.courseName,
      batchName: batchName ?? this.batchName,
      campusName: campusName ?? this.campusName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoDriveId: profilePhotoDriveId ?? this.profilePhotoDriveId,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      dob: dob ?? this.dob,
    );
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  String get courseLabel =>
      courseName?.isNotEmpty == true ? courseName! : 'Course not assigned';
  String get batchLabel =>
      batchName?.isNotEmpty == true ? batchName! : 'Batch not assigned';
  String get campusLabel =>
      campusName?.isNotEmpty == true ? campusName! : 'Campus not assigned';
}

class ProfileSnapshot {
  const ProfileSnapshot({
    required this.parent,
    required this.students,
    this.parentLocalImagePath,
    this.studentLocalImagePaths = const {},
    required this.updatedAt,
  });

  final ParentProfile parent;
  final List<LinkedStudentProfile> students;
  final String? parentLocalImagePath;
  final Map<String, String> studentLocalImagePaths;
  final DateTime updatedAt;

  factory ProfileSnapshot.fromJson(Map<String, dynamic> json) {
    final studentsJson = json['students'] as List<dynamic>? ?? const [];
    final localPathsJson =
        json['student_local_image_paths'] as Map<dynamic, dynamic>? ?? const {};

    return ProfileSnapshot(
      parent: ParentProfile.fromMap(
        Map<String, dynamic>.from(json['parent'] as Map? ?? const {}),
      ),
      students: studentsJson
          .map(
            (item) => LinkedStudentProfile.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      parentLocalImagePath: json['parent_local_image_path']?.toString(),
      studentLocalImagePaths: localPathsJson.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parent': parent.toJson(),
      'students': students.map((student) => student.toJson()).toList(),
      'parent_local_image_path': parentLocalImagePath,
      'student_local_image_paths': studentLocalImagePaths,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProfileSnapshot copyWith({
    ParentProfile? parent,
    List<LinkedStudentProfile>? students,
    String? parentLocalImagePath,
    bool clearParentLocalImagePath = false,
    Map<String, String>? studentLocalImagePaths,
    DateTime? updatedAt,
  }) {
    return ProfileSnapshot(
      parent: parent ?? this.parent,
      students: students ?? this.students,
      parentLocalImagePath: clearParentLocalImagePath
          ? null
          : parentLocalImagePath ?? this.parentLocalImagePath,
      studentLocalImagePaths:
          studentLocalImagePaths ?? this.studentLocalImagePaths,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ProfileSnapshot withLocalImage({
    required ProfileUploadTarget target,
    required String targetId,
    required String localPath,
  }) {
    if (target == ProfileUploadTarget.parent) {
      return copyWith(
        parentLocalImagePath: localPath,
        updatedAt: DateTime.now(),
      );
    }

    final nextPaths = Map<String, String>.from(studentLocalImagePaths);
    nextPaths[targetId] = localPath;
    return copyWith(
      studentLocalImagePaths: nextPaths,
      updatedAt: DateTime.now(),
    );
  }

  ProfileSnapshot withDriveId({
    required ProfileUploadTarget target,
    required String targetId,
    required String driveId,
  }) {
    if (target == ProfileUploadTarget.parent) {
      return copyWith(
        parent: parent.copyWith(profilePhotoDriveId: driveId),
        clearParentLocalImagePath: true,
        updatedAt: DateTime.now(),
      );
    }

    final nextPaths = Map<String, String>.from(studentLocalImagePaths)
      ..remove(targetId);
    return copyWith(
      students: students
          .map(
            (student) => student.id == targetId
                ? student.copyWith(profilePhotoDriveId: driveId)
                : student,
          )
          .toList(),
      studentLocalImagePaths: nextPaths,
      updatedAt: DateTime.now(),
    );
  }
}

class PendingProfileUpload {
  const PendingProfileUpload({
    required this.id,
    required this.parentId,
    required this.target,
    required this.targetId,
    required this.localPath,
    required this.createdAt,
    this.attemptCount = 0,
    this.lastError,
  });

  final String id;
  final String parentId;
  final ProfileUploadTarget target;
  final String targetId;
  final String localPath;
  final DateTime createdAt;
  final int attemptCount;
  final String? lastError;

  factory PendingProfileUpload.create({
    required String parentId,
    required ProfileUploadTarget target,
    required String targetId,
    required String localPath,
  }) {
    return PendingProfileUpload(
      id: '$parentId:${target.apiValue}:$targetId',
      parentId: parentId,
      target: target,
      targetId: targetId,
      localPath: localPath,
      createdAt: DateTime.now(),
    );
  }

  factory PendingProfileUpload.fromJson(Map<String, dynamic> json) {
    return PendingProfileUpload(
      id: json['id']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? '',
      target: ProfileUploadTargetX.fromApiValue(
        json['target']?.toString() ?? 'parent',
      ),
      targetId: json['target_id']?.toString() ?? '',
      localPath: json['local_path']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      attemptCount: int.tryParse(json['attempt_count']?.toString() ?? '') ?? 0,
      lastError: json['last_error']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'target': target.apiValue,
      'target_id': targetId,
      'local_path': localPath,
      'created_at': createdAt.toIso8601String(),
      'attempt_count': attemptCount,
      'last_error': lastError,
    };
  }

  PendingProfileUpload copyWith({int? attemptCount, String? lastError}) {
    return PendingProfileUpload(
      id: id,
      parentId: parentId,
      target: target,
      targetId: targetId,
      localPath: localPath,
      createdAt: createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
