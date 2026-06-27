import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'parent_identity_service.dart';

class ParentActivityService with WidgetsBindingObserver {
  ParentActivityService({
    SupabaseClient? client,
    ParentIdentityService? parentIdentityService,
  })  : _supabase = client ?? Supabase.instance.client,
        _parentIdentityService = parentIdentityService ?? ParentIdentityService();

  final SupabaseClient _supabase;
  final ParentIdentityService _parentIdentityService;

  String? _currentRecordId;
  DateTime? _sessionStart;
  bool _isTracking = false;

  void initialize() {
    if (_isTracking) return;
    WidgetsBinding.instance.addObserver(this);
    _isTracking = true;
  }

  void dispose() {
    if (!_isTracking) return;
    WidgetsBinding.instance.removeObserver(this);
    _isTracking = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isTracking || _currentRecordId == null) return;

    if (state == AppLifecycleState.resumed) {
      _sessionStart = DateTime.now();
      updateLastSeen();
    } else if (state == AppLifecycleState.paused) {
      updateSessionDuration();
    }
  }

  Future<void> trackAppOpen() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Resolve parent profile
      final parent = await _parentIdentityService.resolveCurrentParent();
      final String parentId = parent['id'] as String;
      final String parentName = parent['full_name'] as String;

      // App version
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = packageInfo.version;

      // Platform
      String devicePlatform = 'Unknown';
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          devicePlatform = 'Android';
        } else if (Platform.isIOS) {
          devicePlatform = 'iOS';
        }
      }

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);

      // Check if record exists for today
      final existingRecord = await _supabase
          .from('parent_app_activity_logs')
          .select('id, session_duration_minutes')
          .eq('parent_id', parentId)
          .eq('login_date', todayStr)
          .maybeSingle();

      _sessionStart = DateTime.now();

      if (existingRecord != null) {
        _currentRecordId = existingRecord['id'] as String;
        await _supabase
            .from('parent_app_activity_logs')
            .update({
              'last_seen_at': DateTime.now().toUtc().toIso8601String(),
              'parent_name': parentName,
              'app_version': appVersion,
              'device_platform': devicePlatform,
            })
            .eq('id', _currentRecordId!);
      } else {
        final inserted = await _supabase
            .from('parent_app_activity_logs')
            .insert({
              'parent_id': parentId,
              'parent_name': parentName,
              'device_platform': devicePlatform,
              'app_version': appVersion,
              'login_date': todayStr,
              'opened_at': DateTime.now().toUtc().toIso8601String(),
              'last_seen_at': DateTime.now().toUtc().toIso8601String(),
              'session_duration_minutes': 0.0,
            })
            .select('id')
            .single();
        _currentRecordId = inserted['id'] as String;
      }
    } catch (e) {
      debugPrint('Error tracking app open: $e');
    }
  }

  Future<void> updateLastSeen() async {
    if (_currentRecordId == null) return;
    try {
      await _supabase
          .from('parent_app_activity_logs')
          .update({
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _currentRecordId!);
    } catch (e) {
      debugPrint('Error updating last seen: $e');
    }
  }

  Future<void> updateSessionDuration() async {
    if (_currentRecordId == null || _sessionStart == null) return;
    try {
      final now = DateTime.now();
      final diff = now.difference(_sessionStart!);
      final segmentMinutes = diff.inSeconds / 60.0;

      _sessionStart = null; // reset session start since we paused

      // Fetch the current duration, add the segment, and save it back
      final record = await _supabase
          .from('parent_app_activity_logs')
          .select('session_duration_minutes')
          .eq('id', _currentRecordId!)
          .single();

      final double existingDuration = (record['session_duration_minutes'] as num?)?.toDouble() ?? 0.0;
      final newDuration = existingDuration + segmentMinutes;

      await _supabase
          .from('parent_app_activity_logs')
          .update({
            'session_duration_minutes': newDuration,
            'last_seen_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _currentRecordId!);
    } catch (e) {
      debugPrint('Error updating session duration: $e');
    }
  }
}
