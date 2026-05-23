import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/student_attendance/student_attendance_cubit.dart';
import '../../blocs/student_attendance/student_attendance_state.dart';
import '../../blocs/teacher_session/teacher_session_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
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
  late String? _selectedCampusId;
  late DateTime _selectedDate;
  bool _showSetupPanel = false;

  late AnimationController _successController;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId  = widget.subjectId;
    _selectedBatchId    = widget.batchId;
    _selectedSubjectName = widget.subjectName;
    _selectedBatchName  = widget.batchName;
    _selectedCourseId   = widget.courseId;
    _selectedCampusId   = widget.campusId;
    _selectedDate       = DateTime.now();

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

  void _loadData() {
    context.read<StudentAttendanceCubit>().loadStudents(
          subjectId: _selectedSubjectId,
          batchId:   _selectedBatchId,
          courseId:  _selectedCourseId,
          campusId:  _selectedCampusId,
          date:      _selectedDate,
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
              title: GestureDetector(
                onTap: () => setState(() => _showSetupPanel = !_showSetupPanel),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _selectedSubjectName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedBatchName ?? 'All Students',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showSetupPanel
                                  ? LucideIcons.chevronUp
                                  : LucideIcons.chevronDown,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(LucideIcons.sliders, size: 20),
                  onPressed: () =>
                      setState(() => _showSetupPanel = !_showSetupPanel),
                ),
              ],
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
                          state.errorMessage ?? 'Error saving attendance'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              builder: (ctx, state) {
                if (state.status == StudentAttendanceLoadStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filtered = _filterEntries(state.entries);

                return Column(
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showSetupPanel
                          ? _buildSetupPanel(context)
                          : const SizedBox.shrink(),
                    ),
                    _buildSummaryBar(state),
                    _buildSearchBar(),
                    _buildBulkActionsBar(context),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 100),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) =>
                                  _buildStudentTile(ctx, filtered[i]),
                            ),
                    ),
                  ],
                );
              },
            ),
            floatingActionButton:
                BlocBuilder<StudentAttendanceCubit, StudentAttendanceState>(
              builder: (ctx, state) {
                final session = ctx.read<TeacherSessionCubit>().state;
                final isSaving =
                    state.status == StudentAttendanceLoadStatus.saving;
                final canSave = session.teacherId != null &&
                    !isSaving &&
                    state.entries.isNotEmpty;

                return FloatingActionButton.extended(
                  onPressed: canSave
                      ? () => ctx
                          .read<StudentAttendanceCubit>()
                          .saveAttendance(
                            session.teacherId!,
                            teacherName: session.teacherName,
                            campusId:    session.campusId,
                          )
                      : null,
                  backgroundColor:
                      canSave ? AppColors.primary : Colors.grey,
                  elevation: 6,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.checkSquare,
                          color: Colors.white),
                  label: Text(
                    isSaving ? 'Submitting...' : 'Submit Attendance',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
                            child: const Icon(LucideIcons.check,
                                color: Colors.white, size: 40),
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

  Widget _buildSetupPanel(BuildContext context) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    final assignments = teacher?.subjects ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: NeuBox(
        padding: const EdgeInsets.all(16),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ATTENDANCE SESSION SETUP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            if (assignments.isEmpty)
              const Text('No assignments found.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Subject / Batch',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSubjectId,
                    isExpanded: true,
                    items: assignments.map((s) {
                      return DropdownMenuItem<String>(
                        value: s.subjectId,
                        child: Text(
                          '${s.subjectName} · ${s.batchName ?? "All"}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final s = assignments
                          .firstWhere((x) => x.subjectId == val);
                      setState(() {
                        _selectedSubjectId   = s.subjectId;
                        _selectedBatchId     = s.batchId ?? '';
                        _selectedSubjectName = s.subjectName;
                        _selectedBatchName   = s.batchName;
                        _selectedCourseId    = s.courseId;
                      });
                      _loadData();
                    },
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Date Selector — restricted to today and past dates
            InkWell(
              onTap: () async {
                final now  = DateTime.now();
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
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('d MMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const Icon(LucideIcons.calendar,
                        size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => setState(() => _showSetupPanel = false),
                child: const Text(
                  'Close',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
      ),
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
          _summaryChip('Leave', '${summary['Leave']}', AppColors.info),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 16, color: color)),
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
            prefixIcon: const Icon(LucideIcons.search,
                size: 18, color: AppColors.primary),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.checkSquare,
                      size: 14, color: AppColors.success),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Widget _buildStudentTile(
      BuildContext context, StudentAttendanceEntry entry) {
    final cubit = context.read<StudentAttendanceCubit>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeuBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 20,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              child: Text(
                entry.studentName.isNotEmpty
                    ? entry.studentName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
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
                        fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  Row(
                    children: [
                      if (entry.rollNumber != null) ...[
                        Text(
                          'Roll: ${entry.rollNumber}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (entry.remarks != null)
                        const Icon(LucideIcons.messageSquare,
                            size: 10, color: AppColors.accent),
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
              onPressed: () => _showRemarksDialog(context, entry),
            ),
            const SizedBox(width: 4),
            _buildStatusButtons(context, entry, cubit),
          ],
        ),
      ),
    );
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
                  ? _statusColor(s)
                  : _statusColor(s).withValues(alpha: 0.06),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? _statusColor(s)
                    : _statusColor(s).withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _statusColor(s).withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.users,
              size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'No students found',
            style: TextStyle(
                color: AppColors.textSecondary, fontWeight: FontWeight.w700),
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

  void _showRemarksDialog(
      BuildContext context, StudentAttendanceEntry entry) {
    final ctrl = TextEditingController(text: entry.remarks ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remarks for ${entry.studentName}',
          style:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText:
                'e.g. Absent with permission, Medical leave, Late 10 mins',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
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
              context
                  .read<StudentAttendanceCubit>()
                  .setRemarks(entry.studentId, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save Remarks'),
          ),
        ],
      ),
    );
  }

  List<StudentAttendanceEntry> _filterEntries(
      List<StudentAttendanceEntry> entries) {
    if (_searchQuery.isEmpty) return entries;
    return entries.where((e) {
      return e.studentName.toLowerCase().contains(_searchQuery) ||
          (e.rollNumber?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  Color _statusColor(StudentAttendanceStatus s) {
    switch (s) {
      case StudentAttendanceStatus.present: return AppColors.success;
      case StudentAttendanceStatus.absent:  return AppColors.error;
      case StudentAttendanceStatus.late:    return AppColors.warning;
      case StudentAttendanceStatus.leave:   return AppColors.info;
    }
  }

  String _statusLabel(StudentAttendanceStatus s) {
    switch (s) {
      case StudentAttendanceStatus.present: return 'P';
      case StudentAttendanceStatus.absent:  return 'A';
      case StudentAttendanceStatus.late:    return 'L';
      case StudentAttendanceStatus.leave:   return 'LV';
    }
  }
}
