import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'firebase_options.dart';
import 'services/hive_profile_cache_service.dart';
import 'services/teacher_hive_service.dart';

class AppBootstrapResult {
  final TeacherHiveService teacherHiveService;
  final HiveProfileCacheService hiveProfileCacheService;

  const AppBootstrapResult({
    required this.teacherHiveService,
    required this.hiveProfileCacheService,
  });
}

class AppBootstrap {
  static final AppBootstrap _instance = AppBootstrap._internal();
  factory AppBootstrap() => _instance;
  AppBootstrap._internal();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  late final TeacherHiveService _teacherHiveService;
  late final HiveProfileCacheService _hiveProfileCacheService;

  TeacherHiveService get teacherHiveService => _teacherHiveService;
  HiveProfileCacheService get hiveProfileCacheService => _hiveProfileCacheService;

  Future<AppBootstrapResult> bootstrap() async {
    if (_initialized) {
      return AppBootstrapResult(
        teacherHiveService: _teacherHiveService,
        hiveProfileCacheService: _hiveProfileCacheService,
      );
    }

    debugPrint('AppBootstrap: Starting core initializations...');

    // 1. Hive initialization (including Flutter adapter setups if needed, and Profile Cache)
    await HiveProfileCacheService.initializeHive();
    
    // 2. Supabase initialization
    await Supabase.initialize(
      url: SupabaseConstants.url,
      anonKey: SupabaseConstants.anonKey,
    );

    // 3. Register adapters & Lazy/Concurrent Box Openings
    _teacherHiveService = TeacherHiveService();
    _hiveProfileCacheService = HiveProfileCacheService();
    
    // Open Teacher Hive boxes asynchronously and concurrently to prevent blocking startup
    await _teacherHiveService.initBoxes();

    // 4. Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    _initialized = true;
    debugPrint('AppBootstrap: All core systems bootstrapped successfully.');

    return AppBootstrapResult(
      teacherHiveService: _teacherHiveService,
      hiveProfileCacheService: _hiveProfileCacheService,
    );
  }
}
