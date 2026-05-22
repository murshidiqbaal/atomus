import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'teacher_hive_service.dart';

class AttendanceSyncService {
  final TeacherHiveService _hive;
  final SupabaseClient _supabase = Supabase.instance.client;

  AttendanceSyncService({required TeacherHiveService hive}) : _hive = hive;

  // Call this whenever connectivity is restored.
  Future<SyncResult> syncPending() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return SyncResult(synced: 0, failed: 0, skipped: true);
    }

    int synced = 0;
    int failed  = 0;

    // ── Sync pending teacher attendance ──────────────────────────
    final pendingAttendance = _hive.getAllPendingAttendance();
    for (final item in pendingAttendance) {
      try {
        final type    = item['type'] as String;
        final key     = item['key']  as String;
        final payload = item['payload'];

        if (type == 'teacher_attendance') {
          await _supabase
              .from('teacher_attendance')
              .upsert(payload as Map<String, dynamic>);
          await _hive.removePendingAttendance(key);
          synced++;
        } else if (type == 'student_attendance') {
          final entries = (payload as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
          await _supabase
              .from('attendance')
              .upsert(entries);
          await _hive.removePendingAttendance(key);
          synced++;
        }
      } catch (_) {
        failed++;
      }
    }

    // ── Sync pending marks ────────────────────────────────────────
    final pendingMarks = _hive.getAllPendingMarks();
    for (final item in pendingMarks) {
      try {
        final key     = item['key']  as String;
        final entries = (item['entries'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        await _supabase.from('exam_results').upsert(entries);
        await _hive.removePendingMarks(key);
        synced++;
      } catch (_) {
        failed++;
      }
    }

    return SyncResult(synced: synced, failed: failed);
  }

  // Stream: auto-syncs when connection is restored.
  Stream<SyncResult> connectivitySyncStream() async* {
    await for (final result in Connectivity().onConnectivityChanged) {
      if (!result.contains(ConnectivityResult.none)) {
        yield await syncPending();
      }
    }
  }
}

class SyncResult {
  final int synced;
  final int failed;
  final bool skipped;

  const SyncResult({
    required this.synced,
    required this.failed,
    this.skipped = false,
  });
}
