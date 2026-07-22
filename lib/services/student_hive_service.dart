import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-based local cache for parent-side student data.
///
/// Caches student info, exam sessions, and attendance records so the app
/// can display data instantly on launch, then refresh from Supabase in
/// the background.
class StudentHiveService {
  static const String _studentInfoBox = 'student_info';
  static const String _examSessionsBox = 'student_exams';
  static const String _attendanceBox = 'student_attendance';

  /// Cache TTL in minutes — data older than this is considered stale.
  /// Stale data is still returned for instant display, but a background
  /// refresh is triggered.
  static const int cacheTtlMinutes = 15;

  // Singleton
  static final StudentHiveService _instance = StudentHiveService._internal();
  factory StudentHiveService() => _instance;
  StudentHiveService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initBoxes() async {
    if (_initialized) return;
    await Future.wait([
      _openBox(_studentInfoBox),
      _openBox(_examSessionsBox),
      _openBox(_attendanceBox),
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

  bool _isFresh(Box<String> box) {
    final cachedAt = box.get('cached_at');
    if (cachedAt == null) return false;
    final ts = DateTime.tryParse(cachedAt);
    if (ts == null) return false;
    return DateTime.now().difference(ts).inMinutes <= cacheTtlMinutes;
  }

  // ── Student Info ────────────────────────────────────────────────

  Future<void> saveStudentInfo(Map<String, dynamic> data) async {
    final box = _getBox(_studentInfoBox);
    await box.put('data', jsonEncode(data));
    await box.put('cached_at', DateTime.now().toIso8601String());
  }

  /// Returns cached student info map, or null if no cache / stale.
  /// When [allowStale] is true, returns data even if expired (for instant display).
  Map<String, dynamic>? getCachedStudentInfo({bool allowStale = true}) {
    final box = _getBox(_studentInfoBox);
    final raw = box.get('data');
    if (raw == null) return null;
    if (!allowStale && !_isFresh(box)) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ── Exam Sessions ──────────────────────────────────────────────

  Future<void> saveExamSessions(List<Map<String, dynamic>> exams) async {
    final box = _getBox(_examSessionsBox);
    await box.put('data', jsonEncode(exams));
    await box.put('cached_at', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>>? getCachedExamSessions({bool allowStale = true}) {
    final box = _getBox(_examSessionsBox);
    final raw = box.get('data');
    if (raw == null) return null;
    if (!allowStale && !_isFresh(box)) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Attendance Records ─────────────────────────────────────────

  /// Attendance is cached per key (e.g. "all" or "2026-07" for monthly).
  Future<void> saveAttendance(
    String key,
    List<Map<String, dynamic>> records,
  ) async {
    final box = _getBox(_attendanceBox);
    await box.put('data_$key', jsonEncode(records));
    await box.put('cached_at_$key', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>>? getCachedAttendance(
    String key, {
    bool allowStale = true,
  }) {
    final box = _getBox(_attendanceBox);
    final raw = box.get('data_$key');
    if (raw == null) return null;
    if (!allowStale) {
      final cachedAt = box.get('cached_at_$key');
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
    await _getBox(_studentInfoBox).clear();
    await _getBox(_examSessionsBox).clear();
    await _getBox(_attendanceBox).clear();
  }
}
