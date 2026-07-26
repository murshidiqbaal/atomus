import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class TeacherHiveService {
  static const String _profileBox          = 'teacher_profile';
  static const String _pendingAttendanceBox = 'teacher_pending_attendance';
  static const String _pendingMarksBox      = 'teacher_pending_marks';
  static const String _cachedStudentsBox    = 'teacher_cached_students';
  static const String _assignmentsBox       = 'teacher_assignments';
  static const String _activeSessionBox     = 'teacher_active_session';
  static const String _dailyReportsBox      = 'teacher_daily_reports';
  static const String _cachedExamsBox       = 'teacher_cached_exams';

  // Singleton instance
  static final TeacherHiveService _instance = TeacherHiveService._internal();
  factory TeacherHiveService() => _instance;
  TeacherHiveService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Concurrent, non-blocking box initialization
  Future<void> initBoxes() async {
    if (_initialized) return;
    await Future.wait([
      _openBox(_profileBox),
      _openBox(_pendingAttendanceBox),
      _openBox(_pendingMarksBox),
      _openBox(_cachedStudentsBox),
      _openBox(_assignmentsBox),
      _openBox(_activeSessionBox),
      _openBox(_dailyReportsBox),
      _openBox(_cachedExamsBox),
    ]);
    _initialized = true;
  }

  // Static method for backward compatibility
  static Future<void> initializeHive() async {
    await TeacherHiveService().initBoxes();
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
      throw StateError('Hive box $name is not open. You must call initBoxes() first.');
    }
    return Hive.box<String>(name);
  }

  // ── Teacher profile ───────────────────────────────────────────
  Future<void> saveTeacherProfile(Map<String, dynamic> profile) async {
    final box = _getBox(_profileBox);
    await box.put('profile', jsonEncode(profile));
  }

  Map<String, dynamic>? getTeacherProfile() {
    final box = _getBox(_profileBox);
    final raw = box.get('profile');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearTeacherProfile() async {
    final box = _getBox(_profileBox);
    await box.delete('profile');
  }

  // ── Teacher assignments (subjects/batches) ────────────────────
  Future<void> saveAssignments(List<Map<String, dynamic>> assignments) async {
    final box = _getBox(_assignmentsBox);
    await box.put('assignments', jsonEncode(assignments));
  }

  List<Map<String, dynamic>> getAssignments() {
    final box = _getBox(_assignmentsBox);
    final raw = box.get('assignments');
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Active class session (survive app restart) ────────────────
  Future<void> saveActiveSession(Map<String, dynamic> session) async {
    final box = _getBox(_activeSessionBox);
    await box.put('active', jsonEncode(session));
  }

  Map<String, dynamic>? getActiveSession() {
    final box = _getBox(_activeSessionBox);
    final raw = box.get('active');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearActiveSession() async {
    final box = _getBox(_activeSessionBox);
    await box.delete('active');
  }

  // ── Pending teacher attendance ────────────────────────────────
  Future<String> savePendingTeacherAttendance(Map<String, dynamic> payload) async {
    final box = _getBox(_pendingAttendanceBox);
    final key = 'ta_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, jsonEncode({'key': key, 'type': 'teacher_attendance', 'payload': payload}));
    return key;
  }

  Future<void> savePendingStudentAttendance(
    String batchKey,
    List<Map<String, dynamic>> entries,
  ) async {
    final box = _getBox(_pendingAttendanceBox);
    final key = 'sa_${DateTime.now().millisecondsSinceEpoch}_$batchKey';
    await box.put(key, jsonEncode({'key': key, 'type': 'student_attendance', 'payload': entries}));
  }

  List<Map<String, dynamic>> getAllPendingAttendance() {
    final box = _getBox(_pendingAttendanceBox);
    return box.values.map((v) => jsonDecode(v) as Map<String, dynamic>).toList();
  }

  Future<void> removePendingAttendance(String key) async {
    final box = _getBox(_pendingAttendanceBox);
    await box.delete(key);
  }

  // ── Pending marks ─────────────────────────────────────────────
  Future<void> savePendingMarks(
    String examId,
    List<Map<String, dynamic>> entries,
  ) async {
    final box = _getBox(_pendingMarksBox);
    final key = 'marks_${examId}_${DateTime.now().millisecondsSinceEpoch}';
    await box.put(key, jsonEncode({'key': key, 'exam_id': examId, 'entries': entries}));
  }

  List<Map<String, dynamic>> getAllPendingMarks() {
    final box = _getBox(_pendingMarksBox);
    return box.values.map((v) => jsonDecode(v) as Map<String, dynamic>).toList();
  }

  Future<void> removePendingMarks(String key) async {
    final box = _getBox(_pendingMarksBox);
    await box.delete(key);
  }

  // ── Cached students per batch ─────────────────────────────────
  Future<void> cacheStudents(String batchId, List<Map<String, dynamic>> students) async {
    final box = _getBox(_cachedStudentsBox);
    await box.put(batchId, jsonEncode(students));
  }

  List<Map<String, dynamic>>? getCachedStudents(String batchId) {
    final box = _getBox(_cachedStudentsBox);
    final raw = box.get(batchId);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as Map<String, dynamic>).toList();
  }

  int get pendingAttendanceCount =>
      _getBox(_pendingAttendanceBox).length;

  int get pendingMarksCount =>
      _getBox(_pendingMarksBox).length;

  // ── Daily reports ─────────────────────────────────────────────
  Future<void> saveDailyReport(String key, Map<String, dynamic> report) async {
    final box = _getBox(_dailyReportsBox);
    await box.put(key, jsonEncode(report));
  }

  Map<String, dynamic>? getDailyReport(String key) {
    final box = _getBox(_dailyReportsBox);
    final raw = box.get(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> deleteDailyReport(String key) async {
    final box = _getBox(_dailyReportsBox);
    await box.delete(key);
  }

  List<Map<String, dynamic>> getAllDailyReports() {
    final box = _getBox(_dailyReportsBox);
    return box.values.map((v) => jsonDecode(v) as Map<String, dynamic>).toList();
  }

  Future<void> clearAll() async {
    await Future.wait([
      _getBox(_profileBox).clear(),
      _getBox(_pendingAttendanceBox).clear(),
      _getBox(_pendingMarksBox).clear(),
      _getBox(_cachedStudentsBox).clear(),
      _getBox(_assignmentsBox).clear(),
      _getBox(_activeSessionBox).clear(),
      _getBox(_dailyReportsBox).clear(),
    ]);
  }
}
