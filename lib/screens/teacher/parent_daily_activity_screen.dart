import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/parent_activity_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';

class ParentDailyActivityScreen extends StatefulWidget {
  const ParentDailyActivityScreen({super.key});

  @override
  State<ParentDailyActivityScreen> createState() =>
      _ParentDailyActivityScreenState();
}

class _ParentDailyActivityScreenState extends State<ParentDailyActivityScreen>
    with SingleTickerProviderStateMixin {
  late final ParentActivityRepository _repository;
  late final TabController _tabController;

  // Search & Filter State
  final _searchController = TextEditingController();
  String _searchText = '';
  String? _selectedCampusId;
  String? _selectedCourseId;
  String? _selectedBatchId;
  DateTime? _selectedDate;
  bool _onlyActiveToday = false;
  bool _onlyInactiveToday = false;

  // Metadata dropdown lists
  List<Map<String, dynamic>> _campuses = [];
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _batches = [];

  // Data lists & loading states
  List<Map<String, dynamic>> _logs = [];
  Map<String, dynamic> _stats = {
    'totalParents': 0,
    'todayActive': 0,
    'inactiveToday': 0,
    'weeklyActive': 0,
    'monthlyActive': 0,
    'engagementPercentage': 0,
  };
  List<Map<String, dynamic>> _campusActivity = [];
  List<Map<String, dynamic>> _dailyHistory = [];

  bool _isLoadingLogs = false;
  bool _isLoadingStats = false;
  int _offset = 0;
  final int _limit = 50;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _repository = ParentActivityRepository();
    _tabController = TabController(length: 2, vsync: this);

    // Load metadata and initial data
    _loadMetadata();
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    try {
      final client = Supabase.instance.client;

      final campusesRes = await client.from('campuses').select('id, name');
      final coursesRes = await client.from('courses').select('id, name');
      final batchesRes = await client.from('batches').select('id, name');

      setState(() {
        _campuses = List<Map<String, dynamic>>.from(campusesRes);
        _courses = List<Map<String, dynamic>>.from(coursesRes);
        _batches = List<Map<String, dynamic>>.from(batchesRes);
      });
    } catch (e) {
      print('Error loading metadata: $e');
    }
  }

  Future<void> _refreshData() async {
    _offset = 0;
    _hasMore = true;
    _logs.clear();
    await Future.wait([_loadStats(), _loadLogs(), _loadChartData()]);
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await _repository.getAdminDashboardStats();
      setState(() {
        _stats = stats;
        _isLoadingStats = false;
      });
    } catch (_) {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadLogs({bool loadMore = false}) async {
    if (_isLoadingLogs) return;
    setState(() => _isLoadingLogs = true);

    try {
      if (loadMore) {
        _offset += _limit;
      } else {
        _offset = 0;
        _logs.clear();
      }

      final newLogs = await _repository.getActivityLogs(
        limit: _limit,
        offset: _offset,
        searchText: _searchText,
        campusId: _selectedCampusId,
        courseId: _selectedCourseId,
        batchId: _selectedBatchId,
        date: _selectedDate,
        onlyActiveToday: _onlyActiveToday,
      );

      // If we are filtering by inactive today, fetch them separately
      List<Map<String, dynamic>> finalLogs = newLogs;
      if (_onlyInactiveToday) {
        final inactiveParents = await _repository.getInactiveParentsToday();

        // Map inactive parents to match log display
        finalLogs = inactiveParents.map((p) {
          final student = (p['students'] as List?)?.firstOrNull;
          return {
            'parents': {
              'full_name': p['full_name'],
              'phone_number': p['phone_number'],
              'email': p['email'],
            },
            'students': {'full_name': student?['full_name']},
            'campuses': student?['campuses'],
            'courses': student?['courses'],
            'batches': student?['batches'],
            'open_date': 'N/A',
            'first_opened_at': null,
            'last_opened_at': null,
            'open_count': 0,
          };
        }).toList();

        // Apply client-side text filtering if search is active
        if (_searchText.isNotEmpty) {
          final term = _searchText.toLowerCase();
          finalLogs = finalLogs.where((l) {
            final pName = (l['parents']?['full_name'] as String? ?? '')
                .toLowerCase();
            final pPhone = (l['parents']?['phone_number'] as String? ?? '')
                .toLowerCase();
            final sName = (l['students']?['full_name'] as String? ?? '')
                .toLowerCase();
            return pName.contains(term) ||
                pPhone.contains(term) ||
                sName.contains(term);
          }).toList();
        }
      }

      setState(() {
        if (loadMore) {
          _logs.addAll(finalLogs);
        } else {
          _logs = finalLogs;
        }
        _hasMore = finalLogs.length >= _limit;
        _isLoadingLogs = false;
      });
    } catch (_) {
      setState(() => _isLoadingLogs = false);
    }
  }

  Future<void> _loadChartData() async {
    try {
      final campusAct = await _repository.getCampusWiseActivity();
      final dailyHist = await _repository.getDailyActiveHistory();
      setState(() {
        _campusActivity = campusAct;
        _dailyHistory = dailyHist;
      });
    } catch (e) {
      print('Error loading chart data: $e');
    }
  }

  Future<void> _exportData(bool isExcel) async {
    HapticFeedback.mediumImpact();
    try {
      String content = '';
      if (isExcel) {
        // XML / Tab-separated for clean opening in Excel
        content =
            'Parent Name\tParent Phone\tStudent Name\tCampus\tCourse\tBatch\tOpen Date\tFirst Open\tLast Open\tOpen Count\n';
        for (final r in _logs) {
          final p = r['parents'];
          final s = r['students'];
          final firstOpen = r['first_opened_at'] != null
              ? DateFormat(
                  'hh:mm a',
                ).format(DateTime.parse(r['first_opened_at']).toLocal())
              : 'N/A';
          final lastOpen = r['last_opened_at'] != null
              ? DateFormat(
                  'hh:mm a',
                ).format(DateTime.parse(r['last_opened_at']).toLocal())
              : 'N/A';
          content +=
              '${p?['full_name'] ?? 'N/A'}\t${p?['phone_number'] ?? 'N/A'}\t${s?['full_name'] ?? 'N/A'}\t${r['campuses']?['name'] ?? 'N/A'}\t${r['courses']?['name'] ?? 'N/A'}\t${r['batches']?['name'] ?? 'N/A'}\t${r['open_date'] ?? 'N/A'}\t$firstOpen\t$lastOpen\t${r['open_count'] ?? 0}\n';
        }
      } else {
        // Standard CSV
        content =
            'Parent Name,Parent Phone,Student Name,Campus,Course,Batch,Open Date,First Open,Last Open,Open Count\n';
        for (final r in _logs) {
          final p = r['parents'];
          final s = r['students'];
          final firstOpen = r['first_opened_at'] != null
              ? DateFormat(
                  'hh:mm a',
                ).format(DateTime.parse(r['first_opened_at']).toLocal())
              : 'N/A';
          final lastOpen = r['last_opened_at'] != null
              ? DateFormat(
                  'hh:mm a',
                ).format(DateTime.parse(r['last_opened_at']).toLocal())
              : 'N/A';
          content +=
              '"${p?['full_name'] ?? 'N/A'}","${p?['phone_number'] ?? 'N/A'}","${s?['full_name'] ?? 'N/A'}","${r['campuses']?['name'] ?? 'N/A'}","${r['courses']?['name'] ?? 'N/A'}","${r['batches']?['name'] ?? 'N/A'}","${r['open_date'] ?? 'N/A'}","$firstOpen","$lastOpen",${r['open_count'] ?? 0}\n';
        }
      }

      final dir = await getTemporaryDirectory();
      final ext = isExcel ? 'tsv' : 'csv';
      final file = File(
        '${dir.path}/parent_daily_activity_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      await file.writeAsString(content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported successfully! File saved at: ${file.path}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Copy Path',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.path));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchText = '';
      _selectedCampusId = null;
      _selectedCourseId = null;
      _selectedBatchId = null;
      _selectedDate = null;
      _onlyActiveToday = false;
      _onlyInactiveToday = false;
    });
    _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Parent Activity Tracker',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.refreshCw),
              onPressed: _refreshData,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Segmented Tab bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: NeuBox(
                  padding: const EdgeInsets.all(4),
                  borderRadius: 16,
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Activity Log'),
                      Tab(text: 'Visual Charts'),
                    ],
                  ),
                ),
              ),

              // Main content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildActivityLogTab(isDark),
                    _buildChartsTab(isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────── ACTIVITY LOGS TAB ────────────────

  Widget _buildActivityLogTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Stats Row
          _buildStatsSummaryGrid(isDark),
          const SizedBox(height: 18),

          // Filters & Search
          _buildFiltersCard(isDark),
          const SizedBox(height: 18),

          // Log Header / Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ACTIVITY RECORDS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _exportData(false),
                    icon: const Icon(LucideIcons.fileSpreadsheet, size: 14),
                    label: const Text(
                      'CSV',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _exportData(true),
                    icon: const Icon(LucideIcons.fileSpreadsheet, size: 14),
                    label: const Text(
                      'Excel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Logs list
          _isLoadingLogs && _logs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _logs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Text(
                      'No records found.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _logs.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _logs.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () => _loadLogs(loadMore: true),
                            child: const Text('Load More'),
                          ),
                        ),
                      );
                    }

                    final item = _logs[index];
                    return _buildActivityCard(isDark, item);
                  },
                ),
        ],
      ),
    );
  }

  // ──────────────── STATS CARD COMPONENT ────────────────

  Widget _buildStatsSummaryGrid(bool isDark) {
    final todayActive = _stats['todayActive'] ?? 0;
    final inactiveToday = _stats['inactiveToday'] ?? 0;
    final weeklyActive = _stats['weeklyActive'] ?? 0;
    final monthlyActive = _stats['monthlyActive'] ?? 0;
    final totalParents = _stats['totalParents'] ?? 0;
    final engagement = _stats['engagementPercentage'] ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Today Active',
                todayActive.toString(),
                LucideIcons.userCheck,
                AppColors.success,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Inactive Today',
                inactiveToday.toString(),
                LucideIcons.userX,
                AppColors.error,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Weekly Active',
                weeklyActive.toString(),
                LucideIcons.calendarRange,
                AppColors.info,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Monthly Active',
                monthlyActive.toString(),
                LucideIcons.calendarDays,
                AppColors.accent,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Parents',
                totalParents.toString(),
                LucideIcons.users,
                AppColors.primary,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Engagement',
                '$engagement%',
                LucideIcons.activity,
                AppColors.warning,
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return NeuBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 18,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── FILTERS & SEARCH CARD ────────────────

  Widget _buildFiltersCard(bool isDark) {
    return NeuBox(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FILTER ACTIVITY LOGS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Search Input
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() => _searchText = val);
              _loadLogs();
            },
            decoration: InputDecoration(
              hintText: 'Search parent, phone, student...',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Campus and Course filter dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCampusId,
                  hint: const Text('Campus', style: TextStyle(fontSize: 12)),
                  items: _campuses.map((c) {
                    final rawName = c['name'] as String;
                    String formattedName = rawName;
                    final lower = rawName.toLowerCase();
                    if (lower.contains('aroor') || lower.contains('campus 1') || lower.contains('arr')) {
                      formattedName = 'ARR - Campus 1 Aroor';
                    } else if (lower.contains('piravom') || lower.contains('campus 2') || lower.contains('prv')) {
                      formattedName = 'PRV - Campus 2 Piravom';
                    } else if (lower.contains('main')) {
                      formattedName = 'MAIN - Main Campus';
                    }
                    return DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text(
                        formattedName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCampusId = val);
                    _loadLogs();
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCourseId,
                  hint: const Text('Course', style: TextStyle(fontSize: 12)),
                  items: _courses.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['id'] as String,
                      child: Text(
                        c['name'] as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCourseId = val);
                    _loadLogs();
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Batch and Date filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBatchId,
                  hint: const Text('Batch', style: TextStyle(fontSize: 12)),
                  items: _batches.map((b) {
                    return DropdownMenuItem<String>(
                      value: b['id'] as String,
                      child: Text(
                        b['name'] as String,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedBatchId = val);
                    _loadLogs();
                  },
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                      _loadLogs();
                    }
                  },
                  icon: const Icon(LucideIcons.calendar, size: 14),
                  label: Text(
                    _selectedDate != null
                        ? DateFormat('d MMM').format(_selectedDate!)
                        : 'Select Date',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Active / Inactive Toggles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Active Toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _onlyActiveToday = !_onlyActiveToday;
                    if (_onlyActiveToday) _onlyInactiveToday = false;
                  });
                  _loadLogs();
                },
                child: Row(
                  children: [
                    Icon(
                      _onlyActiveToday
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: _onlyActiveToday
                          ? AppColors.success
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Active Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Inactive Toggle
              GestureDetector(
                onTap: () {
                  setState(() {
                    _onlyInactiveToday = !_onlyInactiveToday;
                    if (_onlyInactiveToday) _onlyActiveToday = false;
                  });
                  _loadLogs();
                },
                child: Row(
                  children: [
                    Icon(
                      _onlyInactiveToday
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color: _onlyInactiveToday
                          ? AppColors.error
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Inactive Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Clear Button
              TextButton(
                onPressed: _clearFilters,
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────── ACTIVITY CARD COMPONENT (Mobile Table alternative) ────────────────

  Widget _buildActivityCard(bool isDark, Map<String, dynamic> item) {
    final parent = item['parents'] as Map?;
    final student = item['students'] as Map?;

    final parentName = parent?['full_name'] ?? 'Unknown Parent';
    final studentName = student?['full_name'] ?? 'No Student linked';
    final campus = item['campuses']?['name'] ?? 'N/A';
    final course = item['courses']?['name'] ?? 'N/A';
    final batch = item['batches']?['name'] ?? 'N/A';

    final openDate = item['open_date'] as String;
    final openCount = item['open_count'] as int? ?? 0;

    final bool isActiveToday =
        openDate == DateFormat('yyyy-MM-dd').format(DateTime.now());

    final firstOpen = item['first_opened_at'] != null
        ? DateFormat(
            'hh:mm a',
          ).format(DateTime.parse(item['first_opened_at']).toLocal())
        : 'N/A';
    final lastOpen = item['last_opened_at'] != null
        ? DateFormat(
            'hh:mm a',
          ).format(DateTime.parse(item['last_opened_at']).toLocal())
        : 'N/A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: NeuBox(
        padding: const EdgeInsets.all(14),
        borderRadius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    parentName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isActiveToday
                                ? AppColors.success
                                : AppColors.textSecondary)
                            .withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          (isActiveToday
                                  ? AppColors.success
                                  : AppColors.textSecondary)
                              .withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    isActiveToday ? 'ACTIVE TODAY' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isActiveToday
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Details Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailField('Student', studentName),
                      _detailField('Campus', campus),
                      _detailField('Course/Batch', '$course · $batch'),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _detailField('Open Date', openDate),
                      _detailField(
                        'First / Last Open',
                        '$firstOpen / $lastOpen',
                      ),
                      _detailField('Total Opens', '$openCount times'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ──────────────── CHARTS TAB ────────────────

  Widget _buildChartsTab(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        // Line Chart: Daily Active Parents (last 30 days)
        _buildLineChartCard(isDark),
        const SizedBox(height: 18),

        // Pie Chart: Engagement Ratio & Bar Chart: Campus Activity
        _buildPieAndBarCharts(isDark),
      ],
    );
  }

  Widget _buildLineChartCard(bool isDark) {
    final List<FlSpot> spots = [];
    for (int i = 0; i < _dailyHistory.length; i++) {
      final val = _dailyHistory[i]['count'] as int? ?? 0;
      spots.add(FlSpot(i.toDouble(), val.toDouble()));
    }

    return NeuBox(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DAILY ACTIVE PARENTS (LAST 30 DAYS)',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          spots.isEmpty
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: Text('No historical active data available yet.'),
                  ),
                )
              : SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 32,
                            getTitlesWidget: (val, _) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              final index = val.toInt();
                              if (index >= 0 && index < _dailyHistory.length) {
                                if (index % 5 == 0) {
                                  final dateStr =
                                      _dailyHistory[index]['date'] as String;
                                  final parsed = DateTime.parse(dateStr);
                                  return Text(
                                    DateFormat('d MMM').format(parsed),
                                    style: const TextStyle(
                                      fontSize: 8,
                                      color: AppColors.textSecondary,
                                    ),
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 4,
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withOpacity(0.08),
                          ),
                          dotData: const FlDotData(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPieAndBarCharts(bool isDark) {
    final todayActive = _stats['todayActive'] as int? ?? 0;
    final inactiveToday = _stats['inactiveToday'] as int? ?? 0;

    return Column(
      children: [
        // Pie Chart
        NeuBox(
          padding: const EdgeInsets.all(18),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TODAY ENGAGEMENT RATIO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              (todayActive == 0 && inactiveToday == 0)
                  ? const SizedBox(
                      height: 150,
                      child: Center(child: Text('No active parent log today.')),
                    )
                  : SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 4,
                          centerSpaceRadius: 40,
                          sections: [
                            PieChartSectionData(
                              color: AppColors.success,
                              value: todayActive.toDouble(),
                              title: '$todayActive',
                              radius: 46,
                              titleStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            PieChartSectionData(
                              color: isDark
                                  ? Colors.white.withOpacity(0.12)
                                  : AppColors.textSecondary.withOpacity(0.12),
                              value: inactiveToday.toDouble(),
                              title: '$inactiveToday',
                              radius: 46,
                              titleStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              // Legend
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _legendItem('Active Today', AppColors.success),
                  const SizedBox(width: 20),
                  _legendItem(
                    'Inactive Today',
                    isDark
                        ? Colors.white24
                        : AppColors.textSecondary.withOpacity(0.2),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Bar Chart (Campus-wise Activity)
        NeuBox(
          padding: const EdgeInsets.all(18),
          borderRadius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CAMPUS-WISE PARENT LOGS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _campusActivity.isEmpty
                  ? const SizedBox(
                      height: 150,
                      child: Center(
                        child: Text('No campus-wise active logs yet.'),
                      ),
                    )
                  : SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (val, _) => Text(
                                  val.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, _) {
                                  final index = val.toInt();
                                  if (index >= 0 &&
                                      index < _campusActivity.length) {
                                    final name =
                                        _campusActivity[index]['campus']
                                            as String;
                                    return Text(
                                      name.length > 8
                                          ? '${name.substring(0, 7)}..'
                                          : name,
                                      style: const TextStyle(
                                        fontSize: 8,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ),
                          ),
                          barGroups: List.generate(_campusActivity.length, (
                            index,
                          ) {
                            final count =
                                _campusActivity[index]['count'] as int;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: count.toDouble(),
                                  color: AppColors.primary,
                                  width: 14,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
