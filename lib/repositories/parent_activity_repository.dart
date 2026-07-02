import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/parent_daily_activity_model.dart';
import 'package:intl/intl.dart';

class ParentActivityRepository {
  final _supabase = Supabase.instance.client;

  String? get _uid => _supabase.auth.currentUser?.id;

  /// Fetches today's app open record for the currently logged-in parent
  Future<ParentDailyActivityModel?> getTodayActivity(String parentId) async {
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final data = await _supabase
          .from('parent_daily_app_opens')
          .select()
          .eq('parent_id', parentId)
          .eq('open_date', todayStr)
          .maybeSingle();

      if (data == null) return null;
      return ParentDailyActivityModel.fromJson(data);
    } catch (e) {
      print('ParentActivityRepository.getTodayActivity error: $e');
      return null;
    }
  }

  /// Inserts a new daily activity record
  Future<void> insertActivity(ParentDailyActivityModel activity) async {
    try {
      await _supabase
          .from('parent_daily_app_opens')
          .insert(activity.toJson());
    } catch (e) {
      print('ParentActivityRepository.insertActivity error: $e');
      rethrow;
    }
  }

  /// Updates an existing daily activity record (increments count, updates last_opened_at)
  Future<void> updateActivity(ParentDailyActivityModel activity) async {
    try {
      if (activity.id == null) return;
      await _supabase
          .from('parent_daily_app_opens')
          .update({
            'last_opened_at': activity.lastOpenedAt.toUtc().toIso8601String(),
            'open_count': activity.openCount,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', activity.id!);
    } catch (e) {
      print('ParentActivityRepository.updateActivity error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Admin Panel Queries
  // ─────────────────────────────────────────────────────────────────────────────

  /// Fetch overview metrics for dashboard cards
  Future<Map<String, dynamic>> getAdminDashboardStats() async {
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final sevenDaysAgoStr = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 7)),
      );
      final thirtyDaysAgoStr = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      // 1. Get total number of parents
      final parentsRes = await _supabase
          .from('parents')
          .select('id');
      final totalParents = parentsRes.length;

      // 2. Get today's active parents (unique parent_id counts due to constraint)
      final todayActiveRes = await _supabase
          .from('parent_daily_app_opens')
          .select('parent_id')
          .eq('open_date', todayStr);
      final todayActive = todayActiveRes.length;

      // 3. Get weekly active parents (unique count)
      final weeklyRows = await _supabase
          .from('parent_daily_app_opens')
          .select('parent_id')
          .gte('open_date', sevenDaysAgoStr);
      final weeklyActive = (weeklyRows as List)
          .map((row) => row['parent_id'] as String)
          .toSet()
          .length;

      // 4. Get monthly active parents (unique count)
      final monthlyRows = await _supabase
          .from('parent_daily_app_opens')
          .select('parent_id')
          .gte('open_date', thirtyDaysAgoStr);
      final monthlyActive = (monthlyRows as List)
          .map((row) => row['parent_id'] as String)
          .toSet()
          .length;

      final inactiveToday = (totalParents - todayActive).clamp(0, totalParents);
      final engagementPct = totalParents > 0 
          ? ((todayActive / totalParents) * 100).round() 
          : 0;

      return {
        'totalParents': totalParents,
        'todayActive': todayActive,
        'inactiveToday': inactiveToday,
        'weeklyActive': weeklyActive,
        'monthlyActive': monthlyActive,
        'engagementPercentage': engagementPct,
      };
    } catch (e) {
      print('ParentActivityRepository.getAdminDashboardStats error: $e');
      return {
        'totalParents': 0,
        'todayActive': 0,
        'inactiveToday': 0,
        'weeklyActive': 0,
        'monthlyActive': 0,
        'engagementPercentage': 0,
      };
    }
  }

  /// Get paginated and filtered parent daily activity records
  Future<List<Map<String, dynamic>>> getActivityLogs({
    int limit = 50,
    int offset = 0,
    String? searchText,
    String? campusId,
    String? courseId,
    String? batchId,
    DateTime? date,
    bool? onlyActiveToday,
  }) async {
    try {
      dynamic query = _supabase.from('parent_daily_app_opens').select('''
        *,
        parents:parent_id (id, full_name, phone_number, email),
        students:student_id (id, full_name),
        campuses:campus_id (id, name),
        courses:course_id (id, name),
        batches:batch_id (id, name)
      ''');

      // Server-side filters
      if (campusId != null && campusId.isNotEmpty) {
        query = query.eq('campus_id', campusId);
      }
      if (courseId != null && courseId.isNotEmpty) {
        query = query.eq('course_id', courseId);
      }
      if (batchId != null && batchId.isNotEmpty) {
        query = query.eq('batch_id', batchId);
      }
      if (date != null) {
        final dateStr = DateFormat('yyyy-MM-dd').format(date);
        query = query.eq('open_date', dateStr);
      }
      
      // Order by last open time descending
      query = query.order('last_opened_at', ascending: false);

      // Pagination
      query = query.range(offset, offset + limit - 1);

      final List<dynamic> data = await query;
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(data);

      // Apply client-side text search (to allow search over nested parent/student properties)
      if (searchText != null && searchText.trim().isNotEmpty) {
        final term = searchText.toLowerCase().trim();
        results = results.where((item) {
          final parent = item['parents'] as Map?;
          final student = item['students'] as Map?;
          
          final pName = (parent?['full_name'] as String? ?? '').toLowerCase();
          final pPhone = (parent?['phone_number'] as String? ?? '').toLowerCase();
          final sName = (student?['full_name'] as String? ?? '').toLowerCase();
          
          return pName.contains(term) || pPhone.contains(term) || sName.contains(term);
        }).toList();
      }

      // Filter active status
      if (onlyActiveToday == true) {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        results = results.where((item) => item['open_date'] == todayStr).toList();
      }

      return results;
    } catch (e) {
      print('ParentActivityRepository.getActivityLogs error: $e');
      return [];
    }
  }

  /// Get list of parents who have NOT opened the app today
  Future<List<Map<String, dynamic>>> getInactiveParentsToday() async {
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. Get parents who did open today
      final activeParentsRes = await _supabase
          .from('parent_daily_app_opens')
          .select('parent_id')
          .eq('open_date', todayStr);
      
      final activeParentIds = (activeParentsRes as List)
          .map((row) => row['parent_id'] as String)
          .toList();

      // 2. Fetch parents who are not in the active list
      var query = _supabase.from('parents').select('''
        id,
        full_name,
        phone_number,
        email,
        students (
          id,
          full_name,
          campuses (id, name),
          courses (id, name),
          batches (id, name)
        )
      ''');

      if (activeParentIds.isNotEmpty) {
        query = query.not('id', 'in', '(${activeParentIds.join(",")})');
      }

      final List<dynamic> inactiveParents = await query;
      return List<Map<String, dynamic>>.from(inactiveParents);
    } catch (e) {
      print('ParentActivityRepository.getInactiveParentsToday error: $e');
      return [];
    }
  }

  /// Query campus-wise parent activity details for charts
  Future<List<Map<String, dynamic>>> getCampusWiseActivity() async {
    try {
      // Fetches and groups campus counts
      final data = await _supabase
          .from('parent_daily_app_opens')
          .select('campus_id, campuses (name)');
      
      final Map<String, int> counts = {};
      for (final row in (data as List)) {
        final campus = row['campuses'] as Map?;
        final campusName = campus?['name'] as String? ?? 'Unknown';
        counts[campusName] = (counts[campusName] ?? 0) + 1;
      }

      return counts.entries.map((e) => {'campus': e.key, 'count': e.value}).toList();
    } catch (e) {
      print('ParentActivityRepository.getCampusWiseActivity error: $e');
      return [];
    }
  }

  /// Query daily active parent counts for the last 30 days
  Future<List<Map<String, dynamic>>> getDailyActiveHistory() async {
    try {
      final thirtyDaysAgoStr = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 30)),
      );

      final data = await _supabase
          .from('parent_daily_app_opens')
          .select('open_date')
          .gte('open_date', thirtyDaysAgoStr);

      final Map<String, int> counts = {};
      for (final row in (data as List)) {
        final date = row['open_date'] as String;
        counts[date] = (counts[date] ?? 0) + 1;
      }

      final sortedDates = counts.keys.toList()..sort();
      return sortedDates.map((date) => {
        'date': date,
        'count': counts[date],
      }).toList();
    } catch (e) {
      print('ParentActivityRepository.getDailyActiveHistory error: $e');
      return [];
    }
  }
}
