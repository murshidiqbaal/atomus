import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../blocs/student_attendance/student_attendance_cubit.dart';
import '../../blocs/student_attendance/student_attendance_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_session/teacher_session_cubit.dart';
import '../../models/student_attendance_entry_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String batchId;
  final String? batchName;
  final String? courseId;
  final String? campusId;

  const StudentAttendanceScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.batchId,
    this.batchName,
    this.courseId,
    this.campusId,
  });

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  late String _selectedSubjectId;
  late String _selectedBatchId;
  late String _selectedSubjectName;
  late String? _selectedBatchName;
  late String? _selectedCourseId;
  late String? _selectedCourseName;
  late String? _selectedCampusId;
  late DateTime _selectedDate;

  late AnimationController _successController;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.subjectId;
    _selectedBatchId = widget.batchId;
    _selectedSubjectName = widget.subjectName;
    _selectedBatchName = widget.batchName;
    _selectedCourseId = widget.courseId;
    _selectedCourseName = null; // resolved in initState from teacher data
    _selectedCampusId = widget.campusId;
    _selectedDate = DateTime.now();

    // Resolve course name + lock the campus filter to the teacher's
    // assigned campus so only that campus's students are listed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacher = context.read<TeacherDashboardCubit>().state.teacher;
      if (teacher == null) return;

      var needsReload = false;
      if (_selectedCourseId != null) {
        final match = teacher.courses.where(
          (c) => c.courseId == _selectedCourseId,
        );
        if (match.isNotEmpty) {
          _selectedCourseName = match.first.courseName;
        }
      }
      // Always scope to the teacher's campus. Ignore any campusId passed
      // in via widget if it doesn't match -- a teacher must not be able
      // to view students from another campus.
      if (teacher.campusId != null && teacher.campusId!.isNotEmpty) {
        if (_selectedCampusId != teacher.campusId) {
          _selectedCampusId = teacher.campusId;
          needsReload = true;
        }
      }
      if (mounted) {
        setState(() {});
        if (needsReload) _loadData();
      }
    });

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _loadData();
  }

  Future<void> _loadData() async {
    await context.read<StudentAttendanceCubit>().loadStudents(
      subjectId: _selectedSubjectId,
      batchId: _selectedBatchId,
      courseId: _selectedCourseId,
      campusId: _selectedCampusId,
      date: _selectedDate,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'Mark Attendance',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              centerTitle: true,
            ),
            body: BlocConsumer<StudentAttendanceCubit, StudentAttendanceState>(
              listener: (ctx, state) {
                if (state.saved) {
                  _successController.forward().then((_) {
                    Future.delayed(const Duration(seconds: 1), () {
                      if (mounted) _successController.reverse();
                    });
                  });
                }
                if (state.status == StudentAttendanceLoadStatus.failure) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.errorMessage ?? 'Error saving attendance',
                      ),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
              builder: (ctx, state) {
                if (state.status == StudentAttendanceLoadStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = _filterEntries(state.entries);

                final listWidget = filtered.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: _buildEmptyState(),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final entry = filtered[i];
                          return StudentAttendanceTile(
                            key: ValueKey(
                              '${entry.studentId}_${entry.status.name}_${entry.remarks ?? ""}',
                            ),
                            entry: entry,
                            cubit: ctx.read<StudentAttendanceCubit>(),
                          );
                        },
                      );

                return Column(
                  children: [
                    _buildInlineFilters(context),
                    _buildSummaryBar(state),
                    _buildSearchBar(),
                    _buildBulkActionsBar(context),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        child: listWidget,
                      ),
                    ),
                  ],
                );
              },
            ),
            bottomNavigationBar:
                BlocBuilder<StudentAttendanceCubit, StudentAttendanceState>(
                  builder: (ctx, state) {
                    // Resolve teacher identity. Prefer TeacherSessionCubit if it
                    // has loaded; otherwise fall back to TeacherDashboardCubit
                    // (which is always populated on teacher screens). This is
                    // why the submit button was previously stuck disabled.
                    final sessionState = ctx.read<TeacherSessionCubit>().state;
                    final dashTeacher = ctx
                        .read<TeacherDashboardCubit>()
                        .state
                        .teacher;
                    final String? teacherId =
                        sessionState.teacherId ?? dashTeacher?.id;
                    final String? teacherName = sessionState.teacherId != null
                        ? sessionState.teacherName
                        : dashTeacher?.fullName;
                    final String? campusId =
                        sessionState.campusId ?? dashTeacher?.campusId;

                    final isSaving =
                        state.status == StudentAttendanceLoadStatus.saving;
                    final hasModified = state.entries.any(
                      (e) => e.id == null || e.status != e.originalStatus,
                    );
                    final canSave =
                        teacherId != null &&
                        !isSaving &&
                        state.entries.isNotEmpty &&
                        hasModified;

                    String label;
                    if (isSaving) {
                      label = 'Submitting...';
                    } else if (state.entries.isEmpty) {
                      label = 'No Students to Submit';
                    } else if (teacherId == null) {
                      label = 'Teacher Not Loaded';
                    } else if (hasModified) {
                      label = 'Submit Attendance';
                    } else {
                      label = 'Already Submitted';
                    }

                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: canSave
                                ? () => ctx
                                      .read<StudentAttendanceCubit>()
                                      .saveAttendance(
                                        teacherId,
                                        teacherName: teacherName,
                                        campusId: campusId,
                                      )
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.textSecondary
                                  .withValues(alpha: 0.4),
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    hasModified
                                        ? LucideIcons.checkSquare
                                        : LucideIcons.checkCircle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                            label: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
          // Success overlay
          IgnorePointer(
            child: FadeTransition(
              opacity: _successController,
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: ScaleTransition(
                    scale: _successScale,
                    child: NeuBox(
                      width: 180,
                      height: 180,
                      borderRadius: 30,
                      padding: EdgeInsets.zero,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.check,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Saved Successfully!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineFilters(BuildContext context) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    final allCourses = teacher?.courses ?? [];
    final allSubjects = teacher?.subjects ?? [];

    // Deduplicate courses from both teacher.courses and teacher.subjects.
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

    final currentSubjectKey = '${_selectedSubjectId}_$_selectedBatchId';
    final subjectStillValid = filteredSubjects.any(
      (s) => '${s.subjectId}_${s.batchId ?? ''}' == currentSubjectKey,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 4,
            child: _filterDropdown<String>(
              label: 'COURSE',
              value: _selectedCourseId,
              hint: 'Select course',
              items: courseEntries
                  .map(
                    (e) => DropdownMenuItem<String>(
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
                  )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                final name = courseMap[val] ?? '';
                final subsForCourse = allSubjects
                    .where((s) => s.courseId == val)
                    .toList();
                setState(() {
                  _selectedCourseId = val;
                  _selectedCourseName = name;
                  if (subsForCourse.isNotEmpty) {
                    final first = subsForCourse.first;
                    _selectedSubjectId = first.subjectId;
                    _selectedSubjectName = first.subjectName;
                    _selectedBatchId = first.batchId ?? '';
                    _selectedBatchName = first.batchName;
                  }
                });
                _loadData();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _filterDropdown<String>(
              label: 'SUBJECT',
              value: subjectStillValid ? currentSubjectKey : null,
              hint: _selectedCourseId == null
                  ? 'Pick course first'
                  : 'Select subject',
              items: filteredSubjects
                  .map(
                    (s) => DropdownMenuItem<String>(
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
                  )
                  .toList(),
              onChanged: filteredSubjects.isEmpty
                  ? null
                  : (val) {
                      if (val == null) return;
                      final s = filteredSubjects.firstWhere(
                        (x) => '${x.subjectId}_${x.batchId ?? ''}' == val,
                      );
                      setState(() {
                        _selectedSubjectId = s.subjectId;
                        _selectedBatchId = s.batchId ?? '';
                        _selectedSubjectName = s.subjectName;
                        _selectedBatchName = s.batchName;
                      });
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

  Widget _filterDropdown<T>({
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
            color: AppColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
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
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
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

  Widget _buildSummaryBar(StudentAttendanceState state) {
    final summary = state.summary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryChip('Total', '${state.totalStudents}', AppColors.primary),
          _summaryChip('Present', '${summary['Present']}', AppColors.success),
          _summaryChip('Absent', '${summary['Absent']}', AppColors.error),
          _summaryChip('Late', '${summary['Late']}', AppColors.warning),
          _summaryChip(
            'Unmarked',
            '${summary['Unmarked'] ?? 0}',
            AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: NeuInset(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        borderRadius: 14,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search student or roll number...',
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

  Widget _buildBulkActionsBar(BuildContext context) {
    final cubit = context.read<StudentAttendanceCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => cubit.markAllPresent(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    LucideIcons.checkSquare,
                    size: 14,
                    color: AppColors.success,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Mark All Present',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => cubit.clearAll(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.trash2, size: 14, color: AppColors.error),
                  SizedBox(width: 6),
                  Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<StudentAttendanceEntry> _filterEntries(
    List<StudentAttendanceEntry> entries,
  ) {
    if (_searchQuery.isEmpty) return entries;
    return entries.where((e) {
      return e.studentName.toLowerCase().contains(_searchQuery) ||
          (e.rollNumber?.toLowerCase().contains(_searchQuery) ?? false);
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
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }
}

class StudentAttendanceTile extends StatelessWidget {
  final StudentAttendanceEntry entry;
  final StudentAttendanceCubit cubit;

  const StudentAttendanceTile({
    super.key,
    required this.entry,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    final isMarked = entry.status != StudentAttendanceStatus.unmarked;
    final tileColor = isMarked
        ? _statusColor(entry.status).withValues(alpha: 0.12)
        : null;

    final tile = NeuBox(
      color: tileColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: 20,
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isMarked
                ? _statusColor(entry.status).withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.08),
            child: Text(
              entry.studentName.isNotEmpty
                  ? entry.studentName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isMarked
                    ? _statusColor(entry.status)
                    : AppColors.primary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.studentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (entry.rollNumber != null) ...[
                      Text(
                        'Roll: ${entry.rollNumber}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (entry.remarks != null)
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          LucideIcons.messageSquare,
                          size: 12,
                          color: AppColors.accent,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.edit3,
              size: 15,
              color: entry.remarks != null
                  ? AppColors.accent
                  : AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            tooltip: 'Add remarks',
            onPressed: () => _showRemarksDialog(context, entry),
          ),
          const SizedBox(width: 4),
          _buildStatusButtons(context, entry, cubit),
        ],
      ),
    );

    return Padding(padding: const EdgeInsets.only(bottom: 8), child: tile);
  }

  Widget _buildStatusButtons(
    BuildContext context,
    StudentAttendanceEntry entry,
    StudentAttendanceCubit cubit,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: StudentAttendanceStatus.values.map((s) {
        final isSelected = entry.status == s;
        return GestureDetector(
          onTap: () => cubit.setStatus(entry.studentId, s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(left: 4),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? _statusColor(s).withValues(alpha: 1.0)
                  : _statusColor(s).withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? _statusColor(s).withValues(alpha: 1.0)
                    : _statusColor(s).withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _statusColor(s).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                _statusLabel(s),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : _statusColor(s),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _statusColor(StudentAttendanceStatus s) {
    switch (s) {
      case StudentAttendanceStatus.present:
        return AppColors.success;
      case StudentAttendanceStatus.absent:
        return AppColors.error;
      case StudentAttendanceStatus.late:
        return AppColors.warning;
      case StudentAttendanceStatus.unmarked:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(StudentAttendanceStatus s) {
    switch (s) {
      case StudentAttendanceStatus.present:
        return 'P';
      case StudentAttendanceStatus.absent:
        return 'A';
      case StudentAttendanceStatus.late:
        return 'L';
      case StudentAttendanceStatus.unmarked:
        return 'U';
    }
  }

  void _showRemarksDialog(BuildContext context, StudentAttendanceEntry entry) {
    final ctrl = TextEditingController(text: entry.remarks ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remarks for ${entry.studentName}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText:
                'e.g. Absent with permission, Medical leave, Late 10 mins',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              cubit.setRemarks(entry.studentId, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save Remarks'),
          ),
        ],
      ),
    );
  }
}
