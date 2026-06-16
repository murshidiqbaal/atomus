import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../blocs/daily_report/daily_report_cubit.dart';
import '../../blocs/daily_report/daily_report_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_session/teacher_session_cubit.dart';
import '../../models/daily_report_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/drive_network_image.dart';

class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  String? _selectedCourseId;
  String? _selectedCourseName;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedBatchId;
  String? _selectedBatchName;
  String? _selectedCampusId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacher = context.read<TeacherDashboardCubit>().state.teacher;
      if (teacher == null) return;

      setState(() {
        _selectedCampusId = teacher.campusId;
        _selectedCourseId = null; // Default to showing all courses
        _selectedSubjectId = null; // Default to showing all subjects
        _selectedBatchId = null;
      });
      _loadData();
    });
  }

  void _loadData() {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;

    // Extract all course IDs assigned to the teacher
    final assignedCourseIds = teacher.subjects
        .map((s) => s.courseId)
        .whereType<String>()
        .toSet()
        .union(teacher.courses.map((c) => c.courseId).toSet())
        .toList();

    context.read<DailyReportCubit>().loadStudentsAndReports(
          batchId: _selectedBatchId,
          subjectId: _selectedSubjectId,
          date: _selectedDate,
          courseIds: _selectedCourseId != null ? [_selectedCourseId!] : assignedCourseIds,
          campusId: _selectedCampusId,
        );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Daily Reports',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocConsumer<DailyReportCubit, DailyReportState>(
          listener: (context, state) {
            if (state.status == DailyReportStatus.failure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'An error occurred'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            final filteredStudents = _filterStudents(state.students);

            return Column(
              children: [
                _buildFilters(context),
                _buildSearchBar(),
                Expanded(
                  child: state.status == DailyReportStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () async => _loadData(),
                          child: filteredStudents.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredStudents.length,
                                  itemBuilder: (context, index) {
                                    final student = filteredStudents[index];
                                    final studentId = student['id'] as String;
                                    final report = state.reports[studentId];

                                    return _StudentReportCard(
                                      student: student,
                                      report: report,
                                      onTap: () => _openReportSetupSheet(
                                        context,
                                        student,
                                        report,
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return const SizedBox.shrink();

    final allCourses = teacher.courses;
    final allSubjects = teacher.subjects;

    // Deduplicate courses
    final courseMap = <String, String>{};
    for (final c in allCourses) {
      courseMap[c.courseId] = c.courseName;
    }
    for (final s in allSubjects) {
      if (s.courseId != null && s.courseName != null) {
        courseMap.putIfAbsent(s.courseId!, () => s.courseName!);
      }
    }
    final courseEntries = courseMap.entries.toList();

    final filteredSubjects = _selectedCourseId != null
        ? allSubjects.where((s) => s.courseId == _selectedCourseId).toList()
        : allSubjects;

    final currentSubjectKey = _selectedSubjectId != null && _selectedBatchId != null
        ? '${_selectedSubjectId}_$_selectedBatchId'
        : null;

    final subjectStillValid = currentSubjectKey == null || filteredSubjects.any(
      (s) => '${s.subjectId}_${s.batchId ?? ''}' == currentSubjectKey,
    );

    if (!subjectStillValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedSubjectId = null;
          _selectedSubjectName = null;
          _selectedBatchId = null;
          _selectedBatchName = null;
        });
        _loadData();
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 4,
            child: _buildFilterDropdown<String?>(
              label: 'COURSE',
              value: _selectedCourseId,
              hint: 'All Courses',
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'All Courses',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...courseEntries.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(
                      e.value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedCourseId = val;
                  _selectedCourseName = val != null ? courseMap[val] : null;
                  // Reset subject filter when course changes
                  _selectedSubjectId = null;
                  _selectedSubjectName = null;
                  _selectedBatchId = null;
                  _selectedBatchName = null;
                });
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _buildFilterDropdown<String?>(
              label: 'SUBJECT',
              value: currentSubjectKey,
              hint: 'All Subjects',
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    'All Subjects',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ...filteredSubjects.map(
                  (s) => DropdownMenuItem<String?>(
                    value: '${s.subjectId}_${s.batchId ?? ''}',
                    child: Text(
                      '${s.subjectName}${s.batchName != null ? " · ${s.batchName}" : ""}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val == null) {
                  setState(() {
                    _selectedSubjectId = null;
                    _selectedSubjectName = null;
                    _selectedBatchId = null;
                    _selectedBatchName = null;
                  });
                } else {
                  final match = filteredSubjects.firstWhere(
                    (x) => '${x.subjectId}_${x.batchId ?? ''}' == val,
                  );
                  setState(() {
                    _selectedSubjectId = match.subjectId;
                    _selectedSubjectName = match.subjectName;
                    _selectedBatchId = match.batchId;
                    _selectedBatchName = match.batchName;
                  });
                }
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 8),
          _buildDateChip(context),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.15),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(
                hint,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateChip(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'DATE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final now = DateTime.now();
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(now.year - 1),
              lastDate: now,
            );
            if (date != null) {
              setState(() => _selectedDate = date);
              _loadData();
            }
          },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.calendar,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('d MMM').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: NeuInset(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        borderRadius: 14,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search student...',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(
              LucideIcons.search,
              size: 18,
              color: AppColors.primary,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 16),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filterStudents(List<Map<String, dynamic>> students) {
    if (_searchQuery.isEmpty) return students;
    return students.where((s) {
      final name = (s['full_name'] as String? ?? '').toLowerCase();
      final roll = (s['roll_number'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery) || roll.contains(_searchQuery);
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            LucideIcons.users,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No students found',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _openReportSetupSheet(
    BuildContext context,
    Map<String, dynamic> student,
    DailyReportModel? existingReport,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ReportSetupSheet(
          student: student,
          existingReport: existingReport,
          subjectId: _selectedSubjectId,
          subjectName: _selectedSubjectName,
          date: _selectedDate,
          cubit: context.read<DailyReportCubit>(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Report Tile Card
// ─────────────────────────────────────────────────────────────────────────────

class _StudentReportCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final DailyReportModel? report;
  final VoidCallback onTap;

  const _StudentReportCard({
    required this.student,
    required this.report,
    required this.onTap,
  });

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = student['full_name'] as String? ?? 'Student';
    final roll = student['roll_number'] as String? ?? 'N/A';
    final driveId = student['profile_photo_drive_id'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeuBox(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 18,
        onTap: onTap,
        child: Row(
          children: [
            DriveAvatarImage(
              driveId: driveId,
              radius: 24,
              initials: _getInitials(name),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Roll No: $roll',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusBadge(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final isReportSet = report != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isReportSet
            ? AppColors.success.withOpacity(isDark ? 0.15 : 0.08)
            : AppColors.textSecondary.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isReportSet
              ? AppColors.success.withOpacity(0.25)
              : AppColors.textSecondary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReportSet ? LucideIcons.checkCircle2 : LucideIcons.circleDot,
            size: 12,
            color: isReportSet ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            isReportSet ? 'Report Set' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isReportSet ? AppColors.success : AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily Report Setup Dialog/Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReportSetupSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final DailyReportModel? existingReport;
  final String? subjectId;
  final String? subjectName;
  final DateTime date;
  final DailyReportCubit cubit;

  const _ReportSetupSheet({
    required this.student,
    required this.existingReport,
    this.subjectId,
    this.subjectName,
    required this.date,
    required this.cubit,
  });

  @override
  State<_ReportSetupSheet> createState() => _ReportSetupSheetState();
}

class _ReportSetupSheetState extends State<_ReportSetupSheet> {
  late String _selectedBehavior;
  late String _selectedEngagement;
  late String _selectedHomework;
  final TextEditingController _remarksCtrl = TextEditingController();

  final List<Map<String, String>> _behaviorRatings = [
    {'emoji': '😠', 'label': 'Poor'},
    {'emoji': '😟', 'label': 'Needs Imp.'},
    {'emoji': '😐', 'label': 'Average'},
    {'emoji': '😊', 'label': 'Good'},
    {'emoji': '🌟', 'label': 'Excellent'},
  ];

  final List<String> _engagementOptions = ['Active', 'Passive', 'Distracted'];
  final List<String> _homeworkOptions = ['Completed', 'Partial', 'Not Completed', 'N/A'];

  @override
  void initState() {
    super.initState();
    if (widget.existingReport != null) {
      _selectedBehavior = widget.existingReport!.behaviorRating;
      _selectedEngagement = widget.existingReport!.studyEngagement;
      _selectedHomework = widget.existingReport!.homeworkStatus;
      _remarksCtrl.text = widget.existingReport!.remarks;
    } else {
      _selectedBehavior = 'Good';
      _selectedEngagement = 'Active';
      _selectedHomework = 'Completed';
    }
  }

  @override
  void dispose() {
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _onSave(BuildContext context) {
    final sessionState = context.read<TeacherSessionCubit>().state;
    final dashTeacher = context.read<TeacherDashboardCubit>().state.teacher;

    final String teacherId = sessionState.teacherId ?? dashTeacher?.id ?? 'unknown';
    final String teacherName = sessionState.teacherId != null
        ? (sessionState.teacherName ?? 'Teacher')
        : (dashTeacher?.fullName ?? 'Teacher');

    final report = DailyReportModel(
      id: widget.existingReport?.id ?? const Uuid().v4(),
      studentId: widget.student['id'] as String,
      subjectId: widget.subjectId,
      dateStr: widget.date.toIso8601String().split('T').first,
      behaviorRating: _selectedBehavior,
      studyEngagement: _selectedEngagement,
      homeworkStatus: _selectedHomework,
      remarks: _remarksCtrl.text.trim(),
      teacherId: teacherId,
      teacherName: teacherName,
      createdAt: widget.existingReport?.createdAt ?? DateTime.now(),
    );

    widget.cubit.saveReport(report);
    Navigator.of(context).pop();
  }

  void _onDelete(BuildContext context) {
    widget.cubit.deleteReport(
      studentId: widget.student['id'] as String,
      subjectId: widget.subjectId,
      date: widget.date,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studentName = widget.student['full_name'] as String? ?? 'Student';
    final titleLabel = widget.subjectName != null
        ? 'Report for ${widget.subjectName}'
        : 'General Daily Report';

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : AppColors.neuBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Setup Daily Report',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        studentName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        titleLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(widget.date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Section 1: Behavior Rating
            const Text(
              'BEHAVIOR RATING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _behaviorRatings.map((br) {
                final isSel = _selectedBehavior == br['label'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedBehavior = br['label']!),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel
                              ? AppColors.primary.withOpacity(0.12)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSel ? AppColors.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          br['emoji']!,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        br['label']!,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Section 2: Study Engagement
            const Text(
              'CLASS ENGAGEMENT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: _engagementOptions.map((opt) {
                final isSel = _selectedEngagement == opt;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(opt),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) setState(() => _selectedEngagement = opt);
                      },
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSel
                            ? Colors.white
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                      ),
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isSel ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Section 3: Homework Completion
            const Text(
              'HOMEWORK STATUS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _homeworkOptions.map((opt) {
                final isSel = _selectedHomework == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSel,
                  onSelected: (val) {
                    if (val) setState(() => _selectedHomework = opt);
                  },
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSel
                        ? Colors.white
                        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary),
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isSel ? AppColors.primary : Colors.transparent,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Section 4: Remarks
            const Text(
              'REMARKS / OBSERVATIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            NeuInset(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              borderRadius: 14,
              child: TextField(
                controller: _remarksCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: 'Enter teacher observations or remarks...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Actions
            Row(
              children: [
                if (widget.existingReport != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _onDelete(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _onSave(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(LucideIcons.save, size: 16, color: Colors.white),
                    label: const Text(
                      'Save Report',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
