import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-based local cache for courses and subjects.
///
/// Courses and subjects change infrequently, so the cache TTL is generous
/// (60 minutes). This prevents redundant Supabase queries when navigating
/// between screens.
class CourseHiveService {
  static const String _coursesBox = 'courses_cache';
  static const String _subjectsBox = 'subjects_cache';

  /// Cache TTL in minutes.
  static const int cacheTtlMinutes = 60;

  // Singleton
  static final CourseHiveService _instance = CourseHiveService._internal();
  factory CourseHiveService() => _instance;
  CourseHiveService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initBoxes() async {
    if (_initialized) return;
    await Future.wait([
      _openBox(_coursesBox),
      _openBox(_subjectsBox),
    ]);
    _initialized = true;
  }

  Future<Box<String>> _openBox(String name) async {
    try {
      if (!Hive.isBoxOpen(name)) {
        return await Hive.openBox<String>(name);
      }
      return Hive.box<String>(name);
    } catch (e) {
      try {
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<String>(name);
      } catch (_) {
        rethrow;
      }
    }
  }

  Box<String> _getBox(String name) {
    if (!Hive.isBoxOpen(name)) {
      throw StateError('Hive box $name is not open. Call initBoxes() first.');
    }
    return Hive.box<String>(name);
  }

  bool _isFresh(Box<String> box, [String cachedAtKey = 'cached_at']) {
    final cachedAt = box.get(cachedAtKey);
    if (cachedAt == null) return false;
    final ts = DateTime.tryParse(cachedAt);
    if (ts == null) return false;
    return DateTime.now().difference(ts).inMinutes <= cacheTtlMinutes;
  }

  // ── Courses ────────────────────────────────────────────────────

  Future<void> saveCourses(List<Map<String, dynamic>> courses) async {
    final box = _getBox(_coursesBox);
    await box.put('data', jsonEncode(courses));
    await box.put('cached_at', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>>? getCachedCourses({bool allowStale = true}) {
    final box = _getBox(_coursesBox);
    final raw = box.get('data');
    if (raw == null) return null;
    if (!allowStale && !_isFresh(box)) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Subjects (keyed by courseId) ───────────────────────────────

  Future<void> saveSubjects(
    String courseId,
    List<Map<String, dynamic>> subjects,
  ) async {
    final box = _getBox(_subjectsBox);
    await box.put('data_$courseId', jsonEncode(subjects));
    await box.put(
      'cached_at_$courseId',
      DateTime.now().toIso8601String(),
    );
  }

  List<Map<String, dynamic>>? getCachedSubjects(
    String courseId, {
    bool allowStale = true,
  }) {
    final box = _getBox(_subjectsBox);
    final raw = box.get('data_$courseId');
    if (raw == null) return null;
    if (!allowStale) {
      final cachedAt = box.get('cached_at_$courseId');
      if (cachedAt == null) return null;
      final ts = DateTime.tryParse(cachedAt);
      if (ts == null ||
          DateTime.now().difference(ts).inMinutes > cacheTtlMinutes) {
        return null;
      }
    }
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Clear ──────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _getBox(_coursesBox).clear();
    await _getBox(_subjectsBox).clear();
  }
}
