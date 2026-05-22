import 'dart:async';
import 'package:flutter/foundation.dart';
import 'attendance_sync_service.dart';
import 'teacher_hive_service.dart';

class AutoSyncManager {
  final TeacherHiveService _hive;
  late final AttendanceSyncService _syncService;
  StreamSubscription<SyncResult>? _connectivitySub;
  bool _isSyncing = false;

  AutoSyncManager({required TeacherHiveService hive}) : _hive = hive {
    _syncService = AttendanceSyncService(hive: _hive);
  }

  bool get isSyncing => _isSyncing;
  bool get isRunning => _connectivitySub != null;

  void start() {
    if (_connectivitySub != null) return; // Already running

    debugPrint('AutoSyncManager: Starting connectivity monitoring...');
    _connectivitySub = _syncService.connectivitySyncStream().listen(
      (result) {
        debugPrint(
          'AutoSyncManager: Connection-triggered sync completed. '
          'Synced: ${result.synced}, Failed: ${result.failed}',
        );
      },
      onError: (e) {
        debugPrint('AutoSyncManager Stream Error: $e');
      },
    );
  }

  void stop() {
    debugPrint('AutoSyncManager: Stopping connectivity monitoring...');
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<SyncResult> triggerSyncNow() async {
    if (_isSyncing) {
      return const SyncResult(synced: 0, failed: 0, skipped: true);
    }
    _isSyncing = true;
    try {
      debugPrint('AutoSyncManager: Triggering manual sync...');
      final result = await _syncService.syncPending();
      debugPrint(
        'AutoSyncManager: Manual sync completed. '
        'Synced: ${result.synced}, Failed: ${result.failed}',
      );
      return result;
    } catch (e) {
      debugPrint('AutoSyncManager Manual Sync Error: $e');
      return const SyncResult(synced: 0, failed: 0);
    } finally {
      _isSyncing = false;
    }
  }
}
