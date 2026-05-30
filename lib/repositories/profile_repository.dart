import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_models.dart';
import '../services/google_drive_profile_upload_service.dart';
import '../services/hive_profile_cache_service.dart';
import '../services/parent_identity_service.dart';
import '../services/profile_image_service.dart';

class ProfileRepository {
  ProfileRepository({
    required HiveProfileCacheService cache,
    required GoogleDriveProfileUploadService driveUploader,
    required ProfileImageService imageService,
    ParentIdentityService? parentIdentityService,
    SupabaseClient? client,
  }) : _cache = cache,
       _driveUploader = driveUploader,
       _imageService = imageService,
       _parentIdentityService =
           parentIdentityService ?? ParentIdentityService(client: client),
       _supabase = client ?? Supabase.instance.client;

  final HiveProfileCacheService _cache;
  final GoogleDriveProfileUploadService _driveUploader;
  final ProfileImageService _imageService;
  final ParentIdentityService _parentIdentityService;
  final SupabaseClient _supabase;

  Future<ProfileSnapshot?> getCachedProfileForCurrentUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return _cache.getLastProfileForAuth(user.id);
  }

  Future<ProfileSnapshot> fetchProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User session not found. Please log in again.');
    }

    final parentMap = await _parentIdentityService.resolveCurrentParent();
    final parent = ParentProfile.fromMap(parentMap);
    final students = await _getLinkedStudents(parent.id);
    final cached = await _cache.getProfile(parent.id);

    final snapshot = ProfileSnapshot(
      parent: parent,
      students: students,
      parentLocalImagePath: cached?.parentLocalImagePath,
      studentLocalImagePaths: cached?.studentLocalImagePaths ?? const {},
      updatedAt: DateTime.now(),
    );

    await _cache.saveProfile(snapshot, authUserId: user.id);
    return snapshot;
  }

  Future<ProfileSnapshot> updateParentDetails(
    ProfileSnapshot current,
    ParentProfile updatedParent,
  ) async {
    await _ensureParentAccess(current.parent.id);

    try {
      await _supabase
          .from('parents')
          .update(updatedParent.toUpdateMap())
          .eq('id', current.parent.id);
    } catch (error) {
      if (!error.toString().toLowerCase().contains('address')) rethrow;
      await _supabase
          .from('parents')
          .update({
            'full_name': updatedParent.fullName.trim(),
            'phone_number': updatedParent.phoneNumber?.trim(),
          })
          .eq('id', current.parent.id);
    }

    final snapshot = current.copyWith(
      parent: current.parent.copyWith(
        fullName: updatedParent.fullName.trim(),
        phoneNumber: updatedParent.phoneNumber?.trim(),
        address: updatedParent.address?.trim(),
        secondaryContactName: updatedParent.secondaryContactName?.trim(),
        secondaryContactPhone: updatedParent.secondaryContactPhone?.trim(),
        secondaryContactEmail: updatedParent.secondaryContactEmail?.trim(),
        secondaryContactRelationship: updatedParent.secondaryContactRelationship?.trim(),
      ),
      updatedAt: DateTime.now(),
    );
    await _saveSnapshot(snapshot);
    return snapshot;
  }

  Future<ProfileSnapshot> updateStudentDetails(
    ProfileSnapshot current,
    LinkedStudentProfile updatedStudent,
  ) async {
    await _validateTargetAccess(current, ProfileUploadTarget.student, updatedStudent.id);

    await _supabase
        .from('students')
        .update({
          'blood_group': updatedStudent.bloodGroup?.trim(),
          'allergies': updatedStudent.allergies?.trim(),
          'medical_conditions': updatedStudent.medicalConditions?.trim(),
          'dob': updatedStudent.dob,
        })
        .eq('id', updatedStudent.id);

    final snapshot = current.copyWith(
      students: current.students
          .map((s) => s.id == updatedStudent.id ? updatedStudent : s)
          .toList(),
      updatedAt: DateTime.now(),
    );
    await _saveSnapshot(snapshot);
    return snapshot;
  }

  Future<String?> pickAndPersistImage({
    required ImageSource source,
    required String filePrefix,
  }) {
    return _imageService.pickAndPersistImage(
      source: source,
      filePrefix: filePrefix,
    );
  }

  Future<ProfileSnapshot> cacheLocalImage({
    required ProfileSnapshot current,
    required ProfileUploadTarget target,
    required String targetId,
    required String localPath,
  }) async {
    final snapshot = current.withLocalImage(
      target: target,
      targetId: targetId,
      localPath: localPath,
    );
    await _saveSnapshot(snapshot);
    return snapshot;
  }

  Future<ProfileSnapshot> uploadImage({
    required ProfileSnapshot current,
    required ProfileUploadTarget target,
    required String targetId,
    required String localPath,
  }) async {
    await _validateTargetAccess(current, target, targetId);
    final driveId = await _driveUploader.uploadProfileImage(
      target: target,
      targetId: targetId,
      localPath: localPath,
    );

    final snapshot = current.withDriveId(
      target: target,
      targetId: targetId,
      driveId: driveId,
    );
    await _cache.removePendingUpload(
      PendingProfileUpload.create(
        parentId: current.parent.id,
        target: target,
        targetId: targetId,
        localPath: localPath,
      ).id,
    );
    await _saveSnapshot(snapshot);
    return snapshot;
  }

  Future<void> enqueueUpload({
    required ProfileSnapshot current,
    required ProfileUploadTarget target,
    required String targetId,
    required String localPath,
    Object? error,
  }) async {
    final upload = PendingProfileUpload.create(
      parentId: current.parent.id,
      target: target,
      targetId: targetId,
      localPath: localPath,
    );
    await _cache.upsertPendingUpload(
      error == null ? upload : upload.copyWith(lastError: error.toString()),
    );
  }

  Future<List<PendingProfileUpload>> pendingUploads(String parentId) {
    return _cache.getPendingUploads(parentId: parentId);
  }

  Future<ProfileSnapshot> syncPendingUploads(ProfileSnapshot current) async {
    final uploads = await _cache.getPendingUploads(parentId: current.parent.id);
    var snapshot = current;

    for (final upload in uploads) {
      if (!File(upload.localPath).existsSync()) {
        await _cache.markPendingUploadFailed(
          upload,
          'Local image file is missing.',
        );
        continue;
      }

      try {
        await _validateTargetAccess(snapshot, upload.target, upload.targetId);
        final driveId = await _driveUploader.uploadProfileImage(
          target: upload.target,
          targetId: upload.targetId,
          localPath: upload.localPath,
        );
        snapshot = snapshot.withDriveId(
          target: upload.target,
          targetId: upload.targetId,
          driveId: driveId,
        );
        await _cache.removePendingUpload(upload.id);
        await _saveSnapshot(snapshot);
      } catch (error) {
        await _cache.markPendingUploadFailed(upload, error);
      }
    }

    return snapshot;
  }

  Future<void> _saveSnapshot(ProfileSnapshot snapshot) async {
    final user = _supabase.auth.currentUser;
    await _cache.saveProfile(snapshot, authUserId: user?.id);
  }

  Future<List<LinkedStudentProfile>> _getLinkedStudents(String parentId) async {
    try {
      final response = await _supabase
          .from('students')
          .select('*, courses(name), batches(name), campuses(name)')
          .eq('parent_id', parentId)
          .order('full_name', ascending: true);

      return (response as List<dynamic>)
          .map(
            (item) =>
                LinkedStudentProfile.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      final response = await _supabase
          .from('students')
          .select()
          .eq('parent_id', parentId)
          .order('full_name', ascending: true);
      final rows = (response as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      return _hydrateStudentLabels(rows);
    }
  }

  Future<List<LinkedStudentProfile>> _hydrateStudentLabels(
    List<Map<String, dynamic>> rows,
  ) async {
    final courseNames = await _lookupNames(
      'courses',
      rows.map((row) => row['course_id']?.toString()),
    );
    final batchNames = await _lookupNames(
      'batches',
      rows.map((row) => row['batch_id']?.toString()),
    );
    final campusNames = await _lookupNames(
      'campuses',
      rows.map((row) => row['campus_id']?.toString()),
    );

    return rows.map((row) {
      final enriched = Map<String, dynamic>.from(row)
        ..['course_name'] = courseNames[row['course_id']?.toString()]
        ..['batch_name'] = batchNames[row['batch_id']?.toString()]
        ..['campus_name'] = campusNames[row['campus_id']?.toString()];
      return LinkedStudentProfile.fromMap(enriched);
    }).toList();
  }

  Future<Map<String, String>> _lookupNames(
    String table,
    Iterable<String?> ids,
  ) async {
    final filteredIds = ids
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    if (filteredIds.isEmpty) return const {};

    try {
      final response = await _supabase
          .from(table)
          .select('id, name')
          .inFilter('id', filteredIds);
      return {
        for (final item in response as List<dynamic>)
          item['id'].toString(): item['name']?.toString() ?? '',
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> _ensureParentAccess(String parentId) async {
    final resolved = await _parentIdentityService.resolveCurrentParent();
    if (resolved['id']?.toString() != parentId) {
      throw Exception('You can only update your own parent profile.');
    }
  }

  Future<void> _validateTargetAccess(
    ProfileSnapshot snapshot,
    ProfileUploadTarget target,
    String targetId,
  ) async {
    await _ensureParentAccess(snapshot.parent.id);
    if (target == ProfileUploadTarget.parent) {
      if (targetId != snapshot.parent.id) {
        throw Exception('You can only update your own parent profile photo.');
      }
      return;
    }

    final localMatch = snapshot.students.any(
      (student) => student.id == targetId,
    );
    if (!localMatch) {
      throw Exception('This student is not linked to your parent profile.');
    }

    final student = await _supabase
        .from('students')
        .select('id, parent_id')
        .eq('id', targetId)
        .maybeSingle();

    if (student == null ||
        student['parent_id']?.toString() != snapshot.parent.id) {
      throw Exception('This student is not linked to your parent profile.');
    }
  }
}
