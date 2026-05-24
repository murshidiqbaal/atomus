import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/teacher_model.dart';

class TeacherProfileHiveService {
  static const String _boxName = 'teacher_profile_cache_v2';

  static Future<void> initializeHive() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<dynamic>(_boxName);
    }
  }

  Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  Future<void> saveProfile(TeacherModel teacher) async {
    await _box.put('profile_data', jsonEncode(teacher.toMap()));
  }

  TeacherModel? getProfile() {
    final raw = _box.get('profile_data');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TeacherModel.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLocalImagePath(String path) async {
    await _box.put('local_image_path', path);
  }

  String? getLocalImagePath() {
    return _box.get('local_image_path') as String?;
  }

  Future<void> clearLocalImagePath() async {
    await _box.delete('local_image_path');
  }

  Future<void> savePendingUpdate(Map<String, dynamic> update) async {
    await _box.put('pending_update', jsonEncode(update));
  }

  Map<String, dynamic>? getPendingUpdate() {
    final raw = _box.get('pending_update');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPendingUpdate() async {
    await _box.delete('pending_update');
  }

  Future<void> savePendingImageUpload(String localPath) async {
    await _box.put('pending_image_upload', localPath);
  }

  String? getPendingImageUpload() {
    return _box.get('pending_image_upload') as String?;
  }

  Future<void> clearPendingImageUpload() async {
    await _box.delete('pending_image_upload');
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
