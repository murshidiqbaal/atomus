import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/marks/marks_cubit.dart';
import '../../blocs/marks/marks_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../models/exam_marks_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  @override
  void initState() {
    super.initState();
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher != null) {
      final subjectIds = teacher.subjects.map((s) => s.subjectId).toList();
      final batchIds   = teacher.subjects
          .where((s) => s.batchId != null)
          .map((s) => s.batchId!)
          .toSet()
          .toList();
      context.read<MarksCubit>().loadExams(
            subjectIds: subjectIds,
            batchId:    batchIds.isNotEmpty ? batchIds.first : null,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Marks Entry',
              style: TextStyle(fontWeight: FontWeight.w800)),
          centerTitle: true,
        ),
        body: BlocConsumer<MarksCubit, MarksState>(
          listener: (ctx, state) {
            if (state.saved) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Marks saved successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
            if (state.status == MarksLoadStatus.failure) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Error saving marks'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (ctx, state) {
            if (state.status == MarksLoadStatus.loading &&
                state.selectedExam == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.selectedExam != null) {
              return _buildMarksEntryView(ctx, state);
            }

            return _buildExamList(ctx, state);
          },
        ),
      ),
    );
  }

  // ── Exam list ─────────────────────────────────────────────────
  Widget _buildExamList(BuildContext context, MarksState state) {
    if (state.exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.fileX, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('No exams assigned',
                style: TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Exams appear here once assigned to your subjects.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: state.exams.length,
      separatorBuilder: (context, i) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _buildExamCard(ctx, state.exams[i]),
    );
  }

  Widget _buildExamCard(BuildContext context, TeacherExam exam) {
    return GestureDetector(
      onTap: () => context.read<MarksCubit>().selectExam(exam),
      child: CustomCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.fileText, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exam.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(
                    exam.subjectName +
                        (exam.batchName != null ? ' · ${exam.batchName}' : ''),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (exam.examDate != null)
                    Text(
                      DateFormat('d MMM yyyy').format(exam.examDate!),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.accent),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: exam.isMarksEntered
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    exam.isMarksEntered ? 'Done' : 'Pending',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: exam.isMarksEntered
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('/${exam.totalMarks.toInt()} marks',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Marks entry grid ──────────────────────────────────────────
  Widget _buildMarksEntryView(BuildContext context, MarksState state) {
    final exam = state.selectedExam!;
    return Column(
      children: [
        _buildExamHeader(context, exam, state),
        Expanded(
          child: state.status == MarksLoadStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : _buildStudentMarksGrid(context, state),
        ),
        _buildSaveBar(context, state),
      ],
    );
  }

  Widget _buildExamHeader(
      BuildContext context, TeacherExam exam, MarksState state) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
            onPressed: () => context.read<MarksCubit>().clearSelection(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                  '${exam.subjectName} · Total: ${exam.totalMarks.toInt()}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Avg: ${state.classAverage.toStringAsFixed(1)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: AppColors.info),
              ),
              Text(
                '${state.pendingCount} pending',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentMarksGrid(BuildContext context, MarksState state) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: state.entries.length,
      itemBuilder: (ctx, i) {
        final entry = state.entries[i];
        return _buildMarksTile(ctx, entry, state.selectedExam!);
      },
    );
  }

  Widget _buildMarksTile(
      BuildContext context, StudentMarksEntry entry, TeacherExam exam) {
    final ctrl = TextEditingController(
      text: entry.isAbsent ? '' : (entry.marksObtained?.toString() ?? ''),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CustomCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                entry.studentName.isNotEmpty
                    ? entry.studentName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 12,
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
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  if (entry.rollNumber != null)
                    Text('Roll: ${entry.rollNumber}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Absent toggle
                GestureDetector(
                  onTap: () => context
                      .read<MarksCubit>()
                      .toggleAbsent(entry.studentId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: entry.isAbsent
                          ? AppColors.error.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: entry.isAbsent
                            ? AppColors.error
                            : AppColors.textSecondary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'AB',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: entry.isAbsent
                            ? AppColors.error
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Marks field
                SizedBox(
                  width: 68,
                  child: TextFormField(
                    controller: ctrl,
                    enabled: !entry.isAbsent,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: entry.isAbsent ? 'AB' : '0',
                      hintStyle:
                          const TextStyle(color: AppColors.textSecondary),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      suffixText: '/${exam.totalMarks.toInt()}',
                      suffixStyle: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary),
                    ),
                    onChanged: (v) {
                      final marks = double.tryParse(v);
                      context.read<MarksCubit>().updateMarks(
                            entry.studentId,
                            marks != null && marks <= exam.totalMarks
                                ? marks
                                : null,
                          );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context, MarksState state) {
    final isSaving = state.status == MarksLoadStatus.saving;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
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
          label: Text(
            isSaving
                ? 'Saving...'
                : 'Save Marks (${state.entries.length - state.pendingCount}/${state.entries.length})',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isSaving ? null : () => context.read<MarksCubit>().saveMarks(),
        ),
      ),
    );
  }
}
