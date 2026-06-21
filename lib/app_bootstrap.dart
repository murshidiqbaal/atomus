import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'firebase_options.dart';
import 'services/fee_hive_service.dart';
import 'services/hive_profile_cache_service.dart';
import 'services/teacher_hive_service.dart';
import 'services/teacher_profile_hive_service.dart';
import 'utils/logger.dart';

class AppBootstrapResult {
  final TeacherHiveService teacherHiveService;
  final HiveProfileCacheService hiveProfileCacheService;
  final TeacherProfileHiveService teacherProfileHiveService;

  const AppBootstrapResult({
    required this.teacherHiveService,
    required this.hiveProfileCacheService,
    required this.teacherProfileHiveService,
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
  late final TeacherProfileHiveService _teacherProfileHiveService;

  TeacherHiveService get teacherHiveService => _teacherHiveService;
  HiveProfileCacheService get hiveProfileCacheService =>
      _hiveProfileCacheService;
  TeacherProfileHiveService get teacherProfileHiveService =>
      _teacherProfileHiveService;

  Future<AppBootstrapResult> bootstrap() async {
    if (_initialized) {
      return AppBootstrapResult(
        teacherHiveService: _teacherHiveService,
        hiveProfileCacheService: _hiveProfileCacheService,
        teacherProfileHiveService: _teacherProfileHiveService,
      );
    }

    AppLogger.info('AppBootstrap', 'Starting core initializations...');

    // 1. Hive initialization (including Flutter adapter setups if needed, and Profile Cache)
    try {
      await HiveProfileCacheService.initializeHive();
      await TeacherProfileHiveService.initializeHive();
    } catch (e, stack) {
      AppLogger.critical(
        'AppBootstrap',
        'Hive initialization failed',
        e,
        stack,
      );
    }

    // 2. Supabase initialization
    try {
      await Supabase.initialize(
        url: SupabaseConstants.url,
        anonKey: SupabaseConstants.anonKey,
      );
    } catch (e, stack) {
      AppLogger.critical(
        'AppBootstrap',
        'Supabase initialization failed',
        e,
        stack,
      );
    }

    // 3. Register adapters & Lazy/Concurrent Box Openings
    _teacherHiveService = TeacherHiveService();
    _hiveProfileCacheService = HiveProfileCacheService();
    _teacherProfileHiveService = TeacherProfileHiveService();

    // Open Hive boxes asynchronously and concurrently to prevent blocking startup
    try {
      await Future.wait([
        _teacherHiveService.initBoxes(),
        FeeHiveService().initBoxes(),
      ]);
    } catch (e, stack) {
      AppLogger.critical('AppBootstrap', 'Opening Hive boxes failed', e, stack);
    }

    // 4. Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e, stack) {
      AppLogger.critical(
        'AppBootstrap',
        'Firebase initialization failed',
        e,
        stack,
      );
    }

    _initialized = true;
    AppLogger.info(
      'AppBootstrap',
      'All core systems bootstrapped successfully.',
    );

    return AppBootstrapResult(
      teacherHiveService: _teacherHiveService,
      hiveProfileCacheService: _hiveProfileCacheService,
      teacherProfileHiveService: _teacherProfileHiveService,
    );
  }
}
