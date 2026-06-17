import 'package:hive_flutter/hive_flutter.dart';

import '../models/profile_models.dart';

class HiveProfileCacheService {
  static const String _profileBoxName = 'profile_cache';
  static const String _pendingUploadBoxName = 'profile_pending_uploads';
  static const String _metaBoxName = 'profile_meta';

  static Future<void> initializeHive() async {
    await Hive.initFlutter();
    await _openSafeBox(_profileBoxName);
    await _openSafeBox(_pendingUploadBoxName);
    await _openSafeBox(_metaBoxName);
  }

  static Future<Box<dynamic>> _openSafeBox(String name) async {
    try {
      if (!Hive.isBoxOpen(name)) {
        return await Hive.openBox<dynamic>(name);
      }
      return Hive.box<dynamic>(name);
    } catch (e) {
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<dynamic>(name);
      } catch (_) {
        rethrow;
      }
    }
  }

  Box<dynamic> get _profiles => Hive.box<dynamic>(_profileBoxName);
  Box<dynamic> get _pendingUploads => Hive.box<dynamic>(_pendingUploadBoxName);
  Box<dynamic> get _meta => Hive.box<dynamic>(_metaBoxName);

  Future<ProfileSnapshot?> getProfile(String parentId) async {
    final raw = _profiles.get(parentId);
    if (raw == null) return null;
    return ProfileSnapshot.fromJson(_stringMap(raw));
  }

  Future<ProfileSnapshot?> getLastProfileForAuth(String authUserId) async {
    final parentId = getParentIdForAuth(authUserId);
    if (parentId == null) return null;
    return getProfile(parentId);
  }

  String? getParentIdForAuth(String authUserId) {
    return _meta.get(_authParentKey(authUserId))?.toString();
  }

  Future<void> saveParentForAuth({
    required String authUserId,
    required String parentId,
  }) async {
    await _meta.put(_authParentKey(authUserId), parentId);
  }

  Future<void> saveProfile(
    ProfileSnapshot snapshot, {
    String? authUserId,
  }) async {
    await _profiles.put(snapshot.parent.id, snapshot.toJson());
    if (authUserId != null) {
      await saveParentForAuth(
        authUserId: authUserId,
        parentId: snapshot.parent.id,
      );
    }
  }

  Future<void> upsertPendingUpload(PendingProfileUpload upload) async {
    await _pendingUploads.put(upload.id, upload.toJson());
  }

  Future<List<PendingProfileUpload>> getPendingUploads({
    String? parentId,
  }) async {
    final uploads = <PendingProfileUpload>[];
    for (final raw in _pendingUploads.values) {
      final upload = PendingProfileUpload.fromJson(_stringMap(raw));
      if (parentId == null || upload.parentId == parentId) {
        uploads.add(upload);
      }
    }
    uploads.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return uploads;
  }

  Future<void> removePendingUpload(String uploadId) async {
    await _pendingUploads.delete(uploadId);
  }

  Future<void> markPendingUploadFailed(
    PendingProfileUpload upload,
    Object error,
  ) async {
    await upsertPendingUpload(
      upload.copyWith(
        attemptCount: upload.attemptCount + 1,
        lastError: error.toString(),
      ),
    );
  }

  Map<String, dynamic> _stringMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), _stringMap(value));
        }
        if (value is List) {
          return MapEntry(
            key.toString(),
            value.map((item) => item is Map ? _stringMap(item) : item).toList(),
          );
        }
        return MapEntry(key.toString(), value);
      });
    }
    return <String, dynamic>{};
  }

  String _authParentKey(String authUserId) => 'auth_parent:$authUserId';
}
