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
import '../../widgets/neu_box.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  // Track validation error states in real-time
  final Map<String, String?> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  void _loadExams() {
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
          title: const Text(
            'Academics & Exams',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
        ),
        body: BlocConsumer<MarksCubit, MarksState>(
          listener: (ctx, state) {
            if (state.saved) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                  content: Text('Operation completed successfully!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            if (state.status == MarksLoadStatus.failure) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Operation failed'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (ctx, state) {
            if (state.status == MarksLoadStatus.loading && state.selectedExam == null) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.selectedExam != null) {
              return _buildMarksEntryView(ctx, state);
            }

            return _buildExamList(ctx, state);
          },
        ),
        floatingActionButton: BlocBuilder<MarksCubit, MarksState>(
          builder: (ctx, state) {
            // Only show FAB when viewing the exam list, not the marks grid
            if (state.selectedExam != null) return const SizedBox.shrink();

            return FloatingActionButton.extended(
              onPressed: () => _showCreateExamSheet(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(LucideIcons.plus, color: Colors.white),
              label: const Text(
                'Create Exam',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Exam List ─────────────────────────────────────────────────
  Widget _buildExamList(BuildContext context, MarksState state) {
    if (state.exams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.fileText, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text(
              'No active exams found',
              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Create Exam" to schedule a new assessment.',
              style: TextStyle(color: AppColors.textSecondary.withOpacity(0.8), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: state.exams.length,
      separatorBuilder: (context, i) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _buildExamCard(ctx, state.exams[i]),
    );
  }

  Widget _buildExamCard(BuildContext context, TeacherExam exam) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    final subjectIds = teacher?.subjects.map((s) => s.subjectId).toList() ?? [];

    return NeuBox(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      onTap: () => context.read<MarksCubit>().selectExam(exam),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(LucideIcons.clipboardCheck, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  '${exam.subjectName}${exam.batchName != null ? ' · ${exam.batchName}' : ''}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                ),
                if (exam.examDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.calendar, size: 10, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('d MMM yyyy').format(exam.examDate!),
                        style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: exam.isMarksEntered ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      exam.isMarksEntered ? 'Done' : 'Pending',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: exam.isMarksEntered ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Premium Exam Deletion Lock Icon Trigger
                  GestureDetector(
                    onTap: () => _confirmDeleteExam(context, exam, subjectIds),
                    child: Icon(
                      LucideIcons.trash2,
                      size: 15,
                      color: AppColors.error.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '/${exam.totalMarks.toInt()} Marks',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Marks Entry View ──────────────────────────────────────────
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

  Widget _buildExamHeader(BuildContext context, TeacherExam exam, MarksState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.01),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
            onPressed: () {
              setState(() => _validationErrors.clear());
              context.read<MarksCubit>().clearSelection();
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                Text(
                  '${exam.subjectName} · Max Marks: ${exam.totalMarks.toInt()}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Avg: ${state.classAverage.toStringAsFixed(1)}%',
                style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.info, fontSize: 14),
              ),
              Text(
                '${state.pendingCount} Pending',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
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

  Widget _buildMarksTile(BuildContext context, StudentMarksEntry entry, TeacherExam exam) {
    final validationError = _validationErrors[entry.studentId];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeuBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  child: Text(
                    entry.studentName.isNotEmpty ? entry.studentName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
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
                      Text(
                        entry.studentName,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      if (entry.rollNumber != null)
                        Text(
                          'Roll: ${entry.rollNumber}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Absent Toggle
                    GestureDetector(
                      onTap: () {
                        setState(() => _validationErrors[entry.studentId] = null);
                        context.read<MarksCubit>().toggleAbsent(entry.studentId);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: entry.isAbsent ? AppColors.error.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: entry.isAbsent ? AppColors.error : AppColors.textSecondary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          'ABSENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: entry.isAbsent ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Marks Input Range-validated Field
                    SizedBox(
                      width: 90,
                      child: NeuInset(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        borderRadius: 10,
                        child: TextFormField(
                          initialValue: entry.isAbsent ? '' : (entry.marksObtained?.toString() ?? ''),
                          enabled: !entry.isAbsent,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: entry.isAbsent ? 'AB' : '0.0',
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
                            border: InputBorder.none,
                            suffixText: '/${exam.totalMarks.toInt()}',
                            suffixStyle: const TextStyle(fontSize: 9, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onChanged: (v) {
                            if (v.isEmpty) {
                              setState(() => _validationErrors[entry.studentId] = null);
                              context.read<MarksCubit>().updateMarks(entry.studentId, null);
                              return;
                            }
                            final marks = double.tryParse(v);
                            if (marks == null) {
                              setState(() => _validationErrors[entry.studentId] = "Numeric only");
                            } else if (marks < 0 || marks > exam.totalMarks) {
                              setState(() => _validationErrors[entry.studentId] = "Out of range");
                            } else {
                              setState(() => _validationErrors[entry.studentId] = null);
                              context.read<MarksCubit>().updateMarks(entry.studentId, marks);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (validationError != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 42.0),
                child: Text(
                  validationError == "Out of range"
                      ? 'Error: Marks must be between 0 and ${exam.totalMarks.toInt()}'
                      : 'Error: Please enter a valid number',
                  style: const TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context, MarksState state) {
    final isSaving = state.status == MarksLoadStatus.saving;
    final hasErrors = _validationErrors.values.any((e) => e != null);
    final canSave = !isSaving && !hasErrors;

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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(LucideIcons.save, size: 18, color: Colors.white),
          label: Text(
            isSaving
                ? 'Saving...'
                : 'Save Marks (${state.entries.length - state.pendingCount}/${state.entries.length})',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canSave ? AppColors.primary : Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: canSave ? () => context.read<MarksCubit>().saveMarks() : null,
        ),
      ),
    );
  }

  // ── Create Exam sheet ─────────────────────────────────────────
  void _showCreateExamSheet(BuildContext context) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    final assignments = teacher?.subjects ?? [];

    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assigned subjects found to create exams.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final marksCtrl = TextEditingController();
    DateTime examDate = DateTime.now();
    
    // Default subject/batch mappings
    String selSubjectId = assignments.first.subjectId;
    String selBatchId = assignments.first.batchId ?? '';
    String? selCourseId = assignments.first.courseId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (sheetCtx, setSheetState) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CREATE NEW EXAM',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Subject pre-filtered selector
                    DropdownButtonFormField<String>(
                      value: selSubjectId,
                      decoration: InputDecoration(
                        labelText: 'Subject / Batch Class',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: assignments.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.subjectId,
                          child: Text('${s.subjectName} · ${s.batchName ?? "All"}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        final s = assignments.firstWhere((x) => x.subjectId == val);
                        setSheetState(() {
                          selSubjectId = s.subjectId;
                          selBatchId = s.batchId ?? '';
                          selCourseId = s.courseId;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Exam Assessment Name',
                        hintText: 'e.g. Midterm 1, Quiz 3, Lab 1',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: marksCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Total Marks',
                              hintText: 'e.g. 50, 100',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Marks required';
                              final double? val = double.tryParse(v);
                              if (val == null || val <= 0) return 'Must be > 0';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Date picker
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: examDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) {
                                setSheetState(() => examDate = d);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Exam Date',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('d MMM yyyy').format(examDate)),
                                  const Icon(LucideIcons.calendar, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final subjectIds = assignments.map((s) => s.subjectId).toList();
                            context.read<MarksCubit>().createExam(
                                  name: nameCtrl.text.trim(),
                                  date: examDate,
                                  totalMarks: double.parse(marksCtrl.text),
                                  batchId: selBatchId,
                                  subjectId: selSubjectId,
                                  courseId: selCourseId,
                                  subjectIds: subjectIds,
                                );
                            Navigator.pop(sheetCtx);
                          }
                        },
                        child: const Text('Create Exam Assessment', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Confirm Delete Exam ───────────────────────────────────────
  void _confirmDeleteExam(BuildContext context, TeacherExam exam, List<String> subjectIds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Exam?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to delete "${exam.name}"? This will permanently delete all student marks associated with this exam.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MarksCubit>().deleteExam(
                    examId: exam.id,
                    subjectId: exam.subjectId,
                    subjectIds: subjectIds,
                  );
            },
            child: const Text('Delete Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
