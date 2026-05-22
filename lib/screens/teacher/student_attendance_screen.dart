import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/student_attendance/student_attendance_cubit.dart';
import '../../blocs/student_attendance/student_attendance_state.dart';
import '../../blocs/teacher_session/teacher_session_cubit.dart';
import '../../models/student_attendance_entry_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String batchId;
  final String? batchName;
  final String? courseId;

  const StudentAttendanceScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.batchId,
    this.batchName,
    this.courseId,
  });

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends State<StudentAttendanceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<StudentAttendanceCubit>().loadStudents(
          subjectId: widget.subjectId,
          batchId:   widget.batchId,
          courseId:  widget.courseId,
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.subjectName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
              if (widget.batchName != null)
                Text(widget.batchName!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(LucideIcons.checkSquare, size: 16),
              label: const Text('All Present'),
              onPressed: () =>
                  context.read<StudentAttendanceCubit>().markAllPresent(),
            ),
          ],
        ),
        body: BlocConsumer<StudentAttendanceCubit, StudentAttendanceState>(
          listener: (ctx, state) {
            if (state.saved) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Attendance saved successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
            if (state.status == StudentAttendanceLoadStatus.failure) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Error saving attendance'),
                  backgroundColor: AppColors.error,
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
                _buildSummaryBar(state),
                _buildSearchBar(),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              _buildStudentTile(ctx, filtered[i]),
                        ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: _buildSaveBar(),
      ),
    );
  }

  Widget _buildSummaryBar(StudentAttendanceState state) {
    final summary = state.summary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _summaryChip('Total', '${state.totalStudents}', AppColors.info),
          _summaryChip('Present', '${summary['Present']}', AppColors.success),
          _summaryChip('Absent', '${summary['Absent']}', AppColors.error),
          _summaryChip('Late', '${summary['Late']}', AppColors.warning),
          _summaryChip('Leave', '${summary['Leave']}', AppColors.textSecondary),
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
        Text(label,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search student...',
          prefixIcon: const Icon(LucideIcons.search, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          filled: true,
        ),
      ),
    );
  }

  Widget _buildStudentTile(BuildContext context, StudentAttendanceEntry entry) {
    final cubit = context.read<StudentAttendanceCubit>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CustomCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                entry.studentName.isNotEmpty
                    ? entry.studentName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
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
                  Text(entry.studentName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (entry.rollNumber != null)
                    Text('Roll: ${entry.rollNumber}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isSelected
                  ? _statusColor(s)
                  : _statusColor(s).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? _statusColor(s)
                    : _statusColor(s).withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                _statusLabel(s),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.white : _statusColor(s),
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveBar() {
    return BlocBuilder<StudentAttendanceCubit, StudentAttendanceState>(
      builder: (ctx, state) {
        final session  = ctx.read<TeacherSessionCubit>().state;
        final isSaving = state.status == StudentAttendanceLoadStatus.saving;
        final canSave  = session.teacherId != null && !isSaving;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LucideIcons.save, size: 18),
                  label: Text(isSaving ? 'Saving...' : 'Save Attendance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: canSave
                      ? () => ctx.read<StudentAttendanceCubit>().saveAttendance(
                            session.teacherId!,
                            teacherName: session.teacherName,
                            campusId:    session.campusId,
                          )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.users, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text('No students found',
              style: TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
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
