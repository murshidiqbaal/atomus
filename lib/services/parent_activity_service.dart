import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/parent_daily_activity_model.dart';
import '../repositories/parent_activity_repository.dart';
import '../repositories/student_repository.dart';
import 'parent_identity_service.dart';

class ParentActivityService {
  final SupabaseClient _supabase;
  final ParentIdentityService _identityService;
  final ParentActivityRepository _activityRepository;
  final StudentRepository _studentRepository;

  bool hasTrackedToday = false;

  ParentActivityService({
    required SupabaseClient client,
    required ParentIdentityService parentIdentityService,
    required ParentActivityRepository activityRepository,
    required StudentRepository studentRepository,
  })  : _supabase = client,
        _identityService = parentIdentityService,
        _activityRepository = activityRepository,
        _studentRepository = studentRepository;

  /// Entry point to check and record parent app open activity
  Future<void> trackDailyAppOpen() async {
    if (hasTrackedToday) return;

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final parent = await _identityService.resolveCurrentParent();
      final parentId = parent['id'] as String;

      final todayActivity = await _activityRepository.getTodayActivity(parentId);
      if (todayActivity != null) {
        await updateTodayRecord(todayActivity);
      } else {
        await createTodayRecord(parentId);
      }

      hasTrackedToday = true;
    } catch (e) {
      // Do not block app execution or throw runtime errors
      print('Parent activity tracking failed: $e');
    }
  }

  /// Checks if the parent has already opened the app today
  Future<bool> hasOpenedToday() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final parent = await _identityService.resolveCurrentParent();
      final parentId = parent['id'] as String;

      final todayActivity = await _activityRepository.getTodayActivity(parentId);
      return todayActivity != null;
    } catch (e) {
      print('Error checking daily app open status: $e');
      return false;
    }
  }

  /// Inserts a new record for today
  Future<void> createTodayRecord(String parentId) async {
    // Fetch student info to link campus, course, batch
    final studentInfo = await _studentRepository.getStudentInfo(parentId);
    String? batchId;
    if (studentInfo != null) {
      batchId = await _fetchStudentBatchId(studentInfo.id);
    }

    final activity = ParentDailyActivityModel(
      parentId: parentId,
      studentId: studentInfo?.id,
      campusId: studentInfo?.campusId,
      courseId: studentInfo?.courseId,
      batchId: batchId,
      openDate: DateTime.now(),
      firstOpenedAt: DateTime.now(),
      lastOpenedAt: DateTime.now(),
      openCount: 1,
    );

    await _activityRepository.insertActivity(activity);
  }

  /// Updates the open count and timestamp for an existing record
  Future<void> updateTodayRecord(ParentDailyActivityModel existing) async {
    final updated = existing.copyWith(
      lastOpenedAt: DateTime.now(),
      openCount: existing.openCount + 1,
    );
    await _activityRepository.updateActivity(updated);
  }

  /// Local helper to resolve batch_id from the student record
  Future<String?> _fetchStudentBatchId(String studentId) async {
    try {
      final res = await _supabase
          .from('students')
          .select('batch_id')
          .eq('id', studentId)
          .maybeSingle();
      return res?['batch_id'] as String?;
    } catch (_) {
      return null;
    }
  }
}
