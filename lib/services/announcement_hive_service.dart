import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-based local cache for announcements.
///
/// Announcements are time-sensitive so the cache TTL is shorter (10 min).
/// Stale data is still returned for instant display while fresh data is
/// fetched from Supabase in the background.
class AnnouncementHiveService {
  static const String _boxName = 'announcement_cache';

  /// Cache TTL in minutes.
  static const int cacheTtlMinutes = 10;

  // Singleton
  static final AnnouncementHiveService _instance =
      AnnouncementHiveService._internal();
  factory AnnouncementHiveService() => _instance;
  AnnouncementHiveService._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> initBoxes() async {
    if (_initialized) return;
    await _openBox(_boxName);
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

  Box<String> _getBox() {
    if (!Hive.isBoxOpen(_boxName)) {
      throw StateError(
        'Hive box $_boxName is not open. Call initBoxes() first.',
      );
    }
    return Hive.box<String>(_boxName);
  }

  // ── Save / Load ────────────────────────────────────────────────

  Future<void> saveAnnouncements(
    List<Map<String, dynamic>> announcements,
  ) async {
    final box = _getBox();
    await box.put('data', jsonEncode(announcements));
    await box.put('cached_at', DateTime.now().toIso8601String());
  }

  /// Returns cached announcements, or null if no cache exists.
  /// When [allowStale] is true, returns data even if the TTL has expired
  /// (useful for instant display before a background refresh completes).
  List<Map<String, dynamic>>? getCachedAnnouncements({
    bool allowStale = true,
  }) {
    final box = _getBox();
    final raw = box.get('data');
    if (raw == null) return null;

    if (!allowStale) {
      final cachedAt = box.get('cached_at');
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
    await _getBox().clear();
  }
}
