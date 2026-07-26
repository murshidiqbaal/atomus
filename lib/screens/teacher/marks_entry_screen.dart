import 'package:atomus/models/teacher_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../blocs/marks/marks_cubit.dart';
import '../../blocs/marks/marks_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../models/exam_marks_model.dart';
import '../../providers/campus_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/student_detail_sheet.dart';

class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key});

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  // Track validation error states in real-time
  final Map<String, String?> _validationErrors = {};

  // Filter states
  String? _selectedCampusId;
  String? _selectedFilterCourseId;
  String? _selectedFilterSubjectId;
  String _selectedFilterExamType = 'All'; // 'All', 'Regular', 'Daily'
  String _selectedFilterStatus = 'All'; // 'All', 'Pending', 'Completed'
  String _selectedFilterScope = 'All'; // 'All', 'Subject-based', 'Course-wide'
  // In-list date filter for non-daily exams. Daily exam templates are
  // always visible regardless of this value (the per-day instance is
  // controlled by the mark-date bar inside the marks entry view).
  DateTime? _examListDate;
  bool _hasMultipleCampuses = false;

  /// Returns true when the selected campus is the "main" campus.
  /// Main campus teachers can see all data across campuses.
  bool get _isMainCampusSelected {
    if (_selectedCampusId == null) return false;
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return false;
    final campus = teacher.campuses.where((c) => c.id == _selectedCampusId);
    if (campus.isEmpty) return false;
    return campus.first.name.toLowerCase().contains('main');
  }

  @override
  void initState() {
    super.initState();
    // Initialize campus filter from CampusProvider / teacher data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacher = context.read<TeacherDashboardCubit>().state.teacher;
      final campusProvider = context.read<CampusProvider>();
      if (teacher != null && teacher.campuses.length > 1) {
        setState(() {
          _hasMultipleCampuses = true;
          _selectedCampusId =
              campusProvider.selectedCampus?.id ?? teacher.campusId;
        });
      } else if (teacher != null) {
        _selectedCampusId = teacher.campusId;
      }
    });
    _loadExams();
  }

  Future<void> _loadExams() async {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher != null) {
      // Scope subjects/courses to the selected campus when applicable.
      // Main campus sees ALL data — no filtering.
      final shouldFilterByCampus = _selectedCampusId != null && !_isMainCampusSelected;
      final filteredSubjects = shouldFilterByCampus
          ? teacher.subjects.where((s) =>
              s.campusId == null || s.campusId == _selectedCampusId)
          : teacher.subjects;
      final filteredCourses = shouldFilterByCampus
          ? teacher.courses.where((c) =>
              c.campusId == null || c.campusId == _selectedCampusId)
          : teacher.courses;

      final subjectIds = filteredSubjects.map((s) => s.subjectId).toList();
      final batchIds = filteredSubjects
          .map((s) => s.batchId)
          .whereType<String>()
          .toSet()
          .toList();
      final courseIds = filteredCourses.map((c) => c.courseId).toSet().toList();

      // Bypass the today-only visibility rule and fetch exams across all dates
      // if no specific date is selected in the date strip filter.
      final showAllDates = _examListDate == null;

      await context.read<MarksCubit>().loadExams(
        subjectIds: subjectIds,
        batchIds: batchIds,
        courseIds: courseIds,
        includeAllDates: showAllDates,
        date: _examListDate,
        campusId: _selectedCampusId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MarksCubit, MarksState>(
      builder: (context, state) {
        return PopScope(
          canPop: state.selectedExam == null,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (state.selectedExam != null) {
              setState(() => _validationErrors.clear());
              context.read<MarksCubit>().clearSelection();
            }
          },
          child: AppBackground(
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
                listenWhen: (previous, current) =>
                    (previous.saved != current.saved && current.saved) ||
                    (previous.status != current.status &&
                        current.status == MarksLoadStatus.failure),
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
                  if (state.status == MarksLoadStatus.loading &&
                      state.selectedExam == null) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: 4,
                      itemBuilder: (_, _) => Shimmer.cardSkeleton(height: 110),
                    );
                  }

                  if (state.selectedExam != null) {
                    return _buildMarksEntryView(ctx, state);
                  }

                  return Column(
                    children: [
                      _buildFilterBar(context),
                      Expanded(child: _buildExamList(context, state)),
                    ],
                  );
                },
              ),
              floatingActionButton: BlocBuilder<MarksCubit, MarksState>(
                builder: (ctx, state) {
                  // Only show FAB when viewing the exam list, not the marks grid
                  if (state.selectedExam != null) {
                    return const SizedBox.shrink();
                  }

                  return FloatingActionButton.extended(
                    heroTag: 'create_exam_fab',
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
          ),
        );
      },
    );
  }

  bool _isExamExpired(TeacherExam exam) {
    if (exam.isDaily) return false;
    if (exam.examDate == null) return false;
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final examDateOnly = DateTime(
      exam.examDate!.year,
      exam.examDate!.month,
      exam.examDate!.day,
    );
    return examDateOnly.isBefore(todayDate);
  }

  // ── Exam List ─────────────────────────────────────────────────
  Widget _buildExamList(BuildContext context, MarksState state) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    final shouldFilterByCampus =
        _selectedCampusId != null && !_isMainCampusSelected;

    final filtered = state.exams.where((exam) {
      if (shouldFilterByCampus) {
        if (exam.campusId != null && exam.campusId != _selectedCampusId) {
          return false;
        }
        final isCourseInCampus = teacher?.courses.any(
          (c) =>
              c.courseId == exam.courseId &&
              (c.campusId == null || c.campusId == _selectedCampusId),
        ) ?? true;
        final isSubjectInCampus = teacher?.subjects.any(
          (s) =>
              s.subjectId == exam.subjectId &&
              (s.campusId == null || s.campusId == _selectedCampusId),
        ) ?? true;
        if (exam.campusId == null && !isCourseInCampus && !isSubjectInCampus) {
          return false;
        }
      }

      if (_selectedFilterCourseId != null && _selectedFilterCourseId != 'All') {
        if (exam.courseId != _selectedFilterCourseId) return false;
      }
      if (_selectedFilterSubjectId != null &&
          _selectedFilterSubjectId != 'All') {
        final isDailyCourseWide = exam.isDaily && exam.subjectId == null;
        if (!isDailyCourseWide && exam.subjectId != _selectedFilterSubjectId) {
          return false;
        }
      }
      if (_selectedFilterExamType == 'Daily') {
        if (!exam.isDaily) return false;
      } else if (_selectedFilterExamType == 'Regular') {
        if (exam.isDaily) return false;
      }
      if (_selectedFilterStatus == 'Completed') {
        if (!exam.isMarksEntered) return false;
      } else if (_selectedFilterStatus == 'Pending') {
        if (exam.isMarksEntered) return false;
      }
      if (_selectedFilterScope == 'Subject-based') {
        if (exam.subjectId == null) return false;
      } else if (_selectedFilterScope == 'Course-wide') {
        if (exam.subjectId != null) return false;
      }
      if (_examListDate != null && !exam.isDaily) {
        final d = exam.examDate;
        if (d == null) return false;
        if (d.year != _examListDate!.year ||
            d.month != _examListDate!.month ||
            d.day != _examListDate!.day) {
          return false;
        }
      }
      if (_examListDate != null && exam.createdAt != null) {
        final filterDateOnly = DateTime(
          _examListDate!.year,
          _examListDate!.month,
          _examListDate!.day,
        );
        final createdDateOnly = DateTime(
          exam.createdAt!.year,
          exam.createdAt!.month,
          exam.createdAt!.day,
        );
        if (filterDateOnly.isBefore(createdDateOnly)) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sort order: Active (non-expired) exams FIRST; Expired exams sorted to the VERY BOTTOM
    filtered.sort((a, b) {
      final aExpired = _isExamExpired(a);
      final bExpired = _isExamExpired(b);
      if (aExpired != bExpired) {
        return aExpired ? 1 : -1; // Expired exams placed at the bottom
      }
      final aDate = a.examDate ?? a.createdAt ?? DateTime(1970);
      final bDate = b.examDate ?? b.createdAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    final listWidget = filtered.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.fileText,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _examListDate != null
                            ? 'No exams on this date'
                            : 'No matching exams found',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            itemCount: filtered.length,
            separatorBuilder: (context, i) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _buildExamCard(ctx, filtered[i]),
          );

    return Column(
      children: [
        _buildExamListDateStrip(context),
        Expanded(
          child: RefreshIndicator(onRefresh: _loadExams, child: listWidget),
        ),
      ],
    );
  }

  Widget _buildExamListDateStrip(BuildContext context) {
    final hasDate = _examListDate != null;
    final label = hasDate
        ? DateFormat('EEE, d MMM yyyy').format(_examListDate!)
        : 'All dates';

    void shiftDay(int delta) {
      final base = _examListDate ?? DateTime.now();
      final next = DateTime(base.year, base.month, base.day + delta);
      setState(() => _examListDate = next);
      _loadExams();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: NeuBox(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        borderRadius: 14,
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Previous day',
              icon: const Icon(
                Icons.chevron_left,
                size: 20,
                color: AppColors.primary,
              ),
              onPressed: () => shiftDay(-1),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _examListDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) {
                    setState(() => _examListDate = picked);
                    _loadExams();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 14,
                        color: hasDate
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.4,
                            color: hasDate
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Next day',
              icon: const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.primary,
              ),
              onPressed: () => shiftDay(1),
            ),
            const SizedBox(width: 2),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: hasDate
                  ? () {
                      setState(() => _examListDate = null);
                      _loadExams();
                    }
                  : null,
              child: Text(
                'ALL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: hasDate
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, TeacherExam exam) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    final isExpired = _isExamExpired(exam);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final subjectIds = teacher?.subjects.map((s) => s.subjectId).toList() ?? [];
    final batchIds =
        teacher?.subjects
            .map((s) => s.batchId)
            .whereType<String>()
            .toSet()
            .toList() ??
        [];
    final courseIds =
        teacher?.courses.map((c) => c.courseId).toSet().toList() ?? [];

    final cardWidget = NeuBox(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      onTap: () {
        context.read<MarksCubit>().selectExam(
          exam,
          markDate: _examListDate,
          subjectId: _selectedFilterSubjectId ?? exam.subjectId,
          campusId: _selectedCampusId,
        );
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isExpired
                  ? AppColors.textSecondary.withOpacity(0.12)
                  : AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.clipboardCheck,
              color: isExpired ? AppColors.textSecondary : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: isExpired ? AppColors.textSecondary : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${exam.subjectName}${exam.batchName != null ? ' · ${exam.batchName}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isExpired
                        ? AppColors.textSecondary.withOpacity(0.7)
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (exam.isDaily) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.repeat,
                          size: 10,
                          color: AppColors.accent,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'DAILY TEST',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (exam.examDate != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.calendar,
                        size: 10,
                        color: isExpired ? AppColors.textSecondary : AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('d MMM yyyy').format(exam.examDate!),
                        style: TextStyle(
                          fontSize: 10,
                          color: isExpired ? AppColors.textSecondary : AppColors.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isExpired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'EXPIRED',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? AppColors.textSecondary.withOpacity(0.12)
                          : (exam.isMarksEntered
                              ? AppColors.success.withOpacity(0.12)
                              : AppColors.warning.withOpacity(0.12)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      exam.isMarksEntered ? 'Done' : (isExpired ? 'Expired' : 'Pending'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isExpired
                            ? AppColors.textSecondary
                            : (exam.isMarksEntered
                                ? AppColors.success
                                : AppColors.warning),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit Exam button
                  GestureDetector(
                    onTap: () =>
                        _showCreateExamSheet(context, examToEdit: exam),
                    child: Icon(
                      LucideIcons.edit2,
                      size: 15,
                      color: AppColors.primary.withOpacity(0.8),
                    ),
                  ),
                  if (exam.createdBy == Supabase.instance.client.auth.currentUser?.id ||
                      exam.creatorId == Supabase.instance.client.auth.currentUser?.id) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _confirmDeleteExam(
                        context,
                        exam,
                        subjectIds,
                        batchIds,
                        courseIds,
                      ),
                      child: Icon(
                        LucideIcons.trash2,
                        size: 15,
                        color: AppColors.error.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '/${exam.totalMarks.toInt()} Marks',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Opacity(
      opacity: isExpired ? 0.65 : 1.0,
      child: cardWidget,
    );
  }

  // ── Marks Entry View ──────────────────────────────────────────
  Widget _buildMarksEntryView(BuildContext context, MarksState state) {
    final exam = state.selectedExam!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDateOnly = state.selectedMarkDate != null
        ? DateTime(
            state.selectedMarkDate!.year,
            state.selectedMarkDate!.month,
            state.selectedMarkDate!.day,
          )
        : null;

    final isBeforeCreation =
        selectedDateOnly != null &&
        exam.createdAt != null &&
        selectedDateOnly.isBefore(
          DateTime(
            exam.createdAt!.year,
            exam.createdAt!.month,
            exam.createdAt!.day,
          ),
        );
    final isFutureDate =
        selectedDateOnly != null && selectedDateOnly.isAfter(today);
    final cantAssign = isBeforeCreation || isFutureDate;

    return Column(
      children: [
        _buildExamHeader(context, exam, state),
        if (exam.isDaily) _buildDailyMarkDateBar(context, state),
        if (cantAssign)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  color: AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFutureDate
                        ? 'Cannot assign marks on future dates'
                        : 'Cannot assign marks before exam was created (${DateFormat('d MMM yyyy').format(exam.createdAt!)})',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: state.status == MarksLoadStatus.loading
              ? const Center(child: CircularProgressIndicator())
              : _buildStudentMarksGrid(context, state, cantAssign: cantAssign),
        ),
        _buildSaveBar(context, state, cantAssign: cantAssign),
      ],
    );
  }

  /// Day-by-day navigator for daily exams. The exam template stays the
  /// same; this just controls which mark_date the entries grid below
  /// loads marks for. Defaults to today (set by MarksCubit.selectExam).
  Widget _buildDailyMarkDateBar(BuildContext context, MarksState state) {
    final cubit = context.read<MarksCubit>();
    final today = DateTime.now();
    final current =
        state.selectedMarkDate ?? DateTime(today.year, today.month, today.day);
    final isToday =
        current.year == today.year &&
        current.month == today.month &&
        current.day == today.day;

    void shift(int days) {
      final next = DateTime(current.year, current.month, current.day + days);
      // Don't let teachers mark for a future date.
      if (next.isAfter(DateTime(today.year, today.month, today.day))) return;
      cubit.changeMarkDate(next);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: NeuBox(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        borderRadius: 14,
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Previous day',
              icon: const Icon(
                Icons.chevron_left,
                size: 20,
                color: AppColors.primary,
              ),
              onPressed: () => shift(-1),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: current,
                    firstDate: DateTime(today.year - 1),
                    lastDate: today,
                  );
                  if (picked != null) cubit.changeMarkDate(picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.calendar,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isToday
                            ? 'Today  ·  ${DateFormat('d MMM yyyy').format(current)}'
                            : DateFormat('EEE, d MMM yyyy').format(current),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.4,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Next day',
              icon: Icon(
                Icons.chevron_right,
                size: 20,
                color: isToday
                    ? AppColors.textSecondary.withValues(alpha: 0.4)
                    : AppColors.primary,
              ),
              onPressed: isToday ? null : () => shift(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamHeader(
    BuildContext context,
    TeacherExam exam,
    MarksState state,
  ) {
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Builder(
                  builder: (ctx) {
                    final teacher = ctx
                        .read<TeacherDashboardCubit>()
                        .state
                        .teacher;
                    final String resolvedSubjectName;
                    if (exam.subjectId != null) {
                      resolvedSubjectName = exam.subjectName;
                    } else {
                      final selectedSubjId = state.entries.isNotEmpty
                          ? state.entries.first.subjectId
                          : null;
                      if (selectedSubjId != null && teacher != null) {
                        final match = teacher.subjects.firstWhere(
                          (s) => s.subjectId == selectedSubjId,
                          orElse: () => teacher.subjects.first,
                        );
                        resolvedSubjectName = match.subjectName;
                      } else {
                        resolvedSubjectName = exam.subjectName;
                      }
                    }
                    return Text(
                      '$resolvedSubjectName · Max Marks: ${exam.totalMarks.toInt()}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Avg: ${state.classAverage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.info,
                  fontSize: 14,
                ),
              ),
              Text(
                '${state.pendingCount} Pending',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentMarksGrid(
    BuildContext context,
    MarksState state, {
    required bool cantAssign,
  }) {
    final listWidget = state.entries.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.users,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No students found',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: state.entries.length,
            itemBuilder: (ctx, i) {
              final entry = state.entries[i];
              return _buildMarksTile(
                ctx,
                entry,
                state.selectedExam!,
                cantAssign: cantAssign,
              );
            },
          );

    return RefreshIndicator(
      onRefresh: () async {
        final exam = state.selectedExam;
        if (exam != null) {
          await context.read<MarksCubit>().selectExam(
            exam,
            markDate: state.selectedMarkDate,
            subjectId: state.entries.isNotEmpty
                ? state.entries.first.subjectId
                : null,
            campusId: _selectedCampusId,
          );
        }
      },
      child: listWidget,
    );
  }

  Widget _buildMarksTile(
    BuildContext context,
    StudentMarksEntry entry,
    TeacherExam exam, {
    required bool cantAssign,
  }) {
    final validationError = _validationErrors[entry.studentId];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NeuBox(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        borderRadius: 20,
        onLongPress: () {
          showStudentDetailsBottomSheet(
            context,
            studentId: entry.studentId,
            studentName: entry.studentName,
            rollNumber: entry.rollNumber,
            admissionNumber: entry.admissionNumber,
            photoUrl: entry.profilePhotoDriveId,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  child: Text(
                    entry.studentName.isNotEmpty
                        ? entry.studentName[0].toUpperCase()
                        : '?',
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      if (entry.rollNumber != null)
                        Text(
                          'Roll: ${entry.rollNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Absent Toggle
                    GestureDetector(
                      onTap: cantAssign
                          ? null
                          : () {
                              setState(
                                () => _validationErrors[entry.studentId] = null,
                              );
                              context.read<MarksCubit>().toggleAbsent(
                                entry.studentId,
                              );
                            },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: entry.isAbsent
                              ? AppColors.error.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: entry.isAbsent
                                ? AppColors.error
                                : AppColors.textSecondary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          'ABSENT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: entry.isAbsent
                                ? AppColors.error
                                : AppColors.textSecondary,
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
                          initialValue: entry.isAbsent
                              ? ''
                              : (entry.marksObtained?.toString() ?? ''),
                          enabled: !entry.isAbsent && !cantAssign,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: entry.isAbsent ? 'AB' : '0.0',
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                            border: InputBorder.none,
                            suffixText: '/${exam.totalMarks.toInt()}',
                            suffixStyle: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                          onChanged: (v) {
                            if (v.isEmpty) {
                              setState(
                                () => _validationErrors[entry.studentId] = null,
                              );
                              context.read<MarksCubit>().updateMarks(
                                entry.studentId,
                                null,
                              );
                              return;
                            }
                            final marks = double.tryParse(v);
                            if (marks == null) {
                              setState(
                                () => _validationErrors[entry.studentId] =
                                    "Numeric only",
                              );
                            } else if (marks < 0 || marks > exam.totalMarks) {
                              setState(
                                () => _validationErrors[entry.studentId] =
                                    "Out of range",
                              );
                            } else {
                              setState(
                                () => _validationErrors[entry.studentId] = null,
                              );
                              context.read<MarksCubit>().updateMarks(
                                entry.studentId,
                                marks,
                              );
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
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveBar(
    BuildContext context,
    MarksState state, {
    required bool cantAssign,
  }) {
    final isSaving = state.status == MarksLoadStatus.saving;
    final hasErrors = _validationErrors.values.any((e) => e != null);
    final canSave = !isSaving && !hasErrors && !cantAssign;

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
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(LucideIcons.save, size: 18, color: Colors.white),
          label: Text(
            isSaving
                ? 'Saving...'
                : 'Save Marks (${state.entries.length - state.pendingCount}/${state.entries.length})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: canSave ? AppColors.primary : Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: canSave
              ? () {
                  final teacher = context
                      .read<TeacherDashboardCubit>()
                      .state
                      .teacher;
                  if (teacher != null) {
                    final subjectIds = teacher.subjects
                        .map((s) => s.subjectId)
                        .toList();
                    final batchIds = teacher.subjects
                        .map((s) => s.batchId)
                        .whereType<String>()
                        .toSet()
                        .toList();
                    final courseIds = teacher.courses
                        .map((c) => c.courseId)
                        .toSet()
                        .toList();
                    context.read<MarksCubit>().saveMarks(
                      subjectIds: subjectIds,
                      batchIds: batchIds,
                      courseIds: courseIds,
                    );
                  }
                }
              : null,
        ),
      ),
    );
  }

  // ── Premium Filter Bar UI ──────────────────────────────────────
  Widget _buildFilterBar(BuildContext context) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return const SizedBox.shrink();

    // Scope courses and subjects to the selected campus.
    // Main campus sees ALL data — no filtering.
    final shouldFilterByCampus = _selectedCampusId != null && !_isMainCampusSelected;
    final campusFilteredCourses = shouldFilterByCampus
        ? teacher.courses.where((c) =>
            c.campusId == null || c.campusId == _selectedCampusId).toList()
        : teacher.courses;
    final campusFilteredSubjects = shouldFilterByCampus
        ? teacher.subjects.where((s) =>
            s.campusId == null || s.campusId == _selectedCampusId).toList()
        : teacher.subjects;

    // Deduplicate courses from both teacher.courses and teacher.subjects
    final courseMap = <String, String>{};
    for (final c in campusFilteredCourses) {
      courseMap[c.courseId] = c.courseName;
    }
    for (final s in campusFilteredSubjects) {
      if (s.courseId != null && s.courseName != null) {
        courseMap.putIfAbsent(s.courseId!, () => s.courseName!);
      }
    }
    final courseEntries = courseMap.entries.toList();

    // Get unique subjects filtered by course selection
    final uniqueSubjects = <String, String>{};
    for (final s in campusFilteredSubjects) {
      if (_selectedFilterCourseId == null ||
          s.courseId == _selectedFilterCourseId) {
        uniqueSubjects[s.subjectId] = s.subjectName;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Campus Filter — only show when teacher has multiple campuses
          if (_hasMultipleCampuses) ...[
            _buildFilterDropdown(
              hint: 'Campus',
              value: _selectedCampusId,
              items: [
                ...teacher.campuses.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.displayName),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedCampusId = val;
                  // Reset dependent filters
                  _selectedFilterCourseId = null;
                  _selectedFilterSubjectId = null;
                });
                _loadExams();
              },
            ),
            const SizedBox(width: 8),
          ],

          // Course Filter
          _buildFilterDropdown(
            hint: 'Course',
            value: _selectedFilterCourseId,
            items: [
              const DropdownMenuItem(value: 'All', child: Text('All Courses')),
              ...courseEntries.map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _selectedFilterCourseId = val == 'All' ? null : val;

                // Validate selected subject under the new course selection
                if (_selectedFilterSubjectId != null) {
                  final isValid = campusFilteredSubjects.any(
                    (s) =>
                        s.subjectId == _selectedFilterSubjectId &&
                        (_selectedFilterCourseId == null ||
                            s.courseId == _selectedFilterCourseId),
                  );
                  if (!isValid) {
                    _selectedFilterSubjectId = null;
                  }
                }
              });
              // Refetch -- "All Courses" lifts the today-only filter
              // and pulls every assigned exam across all dates;
              // selecting a specific course re-applies the daily
              // visibility rule.
              _loadExams();
            },
          ),
          const SizedBox(width: 8),

          // Subject Filter
          _buildFilterDropdown(
            hint: 'Subject',
            value: _selectedFilterSubjectId,
            items: [
              const DropdownMenuItem(value: 'All', child: Text('All Subjects')),
              ...uniqueSubjects.entries.map(
                (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
              ),
            ],
            onChanged: (val) {
              setState(
                () => _selectedFilterSubjectId = val == 'All' ? null : val,
              );
            },
          ),
          const SizedBox(width: 8),

          // Exam Type Filter
          _buildFilterChips(
            selected: _selectedFilterExamType,
            options: const ['All', 'Regular', 'Daily'],
            onSelected: (val) {
              setState(() {
                _selectedFilterExamType = val;
                // Daily exam templates are visible every day -- no
                // per-day filter chips are needed. The day to enter
                // marks for is picked inside the marks entry view.
              });
            },
          ),
          const SizedBox(width: 8),

          // Status Filter
          _buildFilterChips(
            selected: _selectedFilterStatus,
            options: const ['All', 'Pending', 'Completed'],
            onSelected: (val) {
              setState(() => _selectedFilterStatus = val);
            },
          ),
          const SizedBox(width: 8),

          // Scope Filter
          _buildFilterChips(
            selected: _selectedFilterScope,
            options: const ['All', 'Subject-based', 'Course-wide'],
            onSelected: (val) {
              setState(() => _selectedFilterScope = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String hint,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.glassBase : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDarkMode
              ? AppColors.glassBorder
              : AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value ?? 'All',
          items: items,
          onChanged: onChanged,
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 14,
            color: AppColors.textSecondary,
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
          dropdownColor: isDarkMode ? AppColors.neuBaseDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildFilterChips({
    required String selected,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.glassBase : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDarkMode
              ? AppColors.glassBorder
              : AppColors.textSecondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSel = selected == opt;
          return GestureDetector(
            onTap: () => onSelected(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: double.infinity,
              decoration: BoxDecoration(
                color: isSel ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Text(
                opt,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSel ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Create/Edit Exam sheet ────────────────────────────────────
  void _showCreateExamSheet(BuildContext context, {TeacherExam? examToEdit}) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    final assignments = teacher?.subjects ?? [];

    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assigned subjects found to create/edit exams.'),
        ),
      );
      return;
    }

    // Map of courseId -> courseName derived from assignments
    final courseMap = <String, String>{};
    for (final s in assignments) {
      final cid = s.courseId;
      final cname = s.courseName;
      if (cid != null && cname != null) {
        courseMap[cid] = cname;
      }
    }

    // Default course mapping
    String? selCourseId = examToEdit?.courseId;
    if (selCourseId == null || !courseMap.containsKey(selCourseId)) {
      if (_selectedFilterCourseId != null && courseMap.containsKey(_selectedFilterCourseId)) {
        selCourseId = _selectedFilterCourseId;
      } else if (assignments.isNotEmpty) {
        final firstWithCourse = assignments.firstWhere(
          (s) => s.courseId != null,
          orElse: () => assignments.first,
        );
        selCourseId = firstWithCourse.courseId;
      }
    }

    String? selSubjectId = examToEdit?.subjectId ?? _selectedFilterSubjectId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateEditExamBottomSheet(
        examToEdit: examToEdit,
        assignments: assignments,
        courseMap: courseMap,
        listDate: _examListDate ?? DateTime.now(),
        initialCourseId: selCourseId,
        initialSubjectId: selSubjectId,
        teacher: teacher,
      ),
    );
  }

  // ── Confirm Delete Exam ───────────────────────────────────────
  void _confirmDeleteExam(
    BuildContext context,
    TeacherExam exam,
    List<String> subjectIds,
    List<String> batchIds,
    List<String> courseIds,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Exam?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Are you sure you want to delete "${exam.name}"? This will permanently delete all student marks associated with this exam.',
        ),
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
                batchIds: batchIds,
                courseIds: courseIds,
                listDate: _examListDate,
              );
            },
            child: const Text(
              'Delete Exam',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateEditExamBottomSheet extends StatefulWidget {
  final TeacherExam? examToEdit;
  final List<TeacherSubjectAssignment> assignments;
  final Map<String, String> courseMap;
  final DateTime listDate;
  final String? initialCourseId;
  final String? initialSubjectId;
  final TeacherModel? teacher;

  const _CreateEditExamBottomSheet({
    required this.examToEdit,
    required this.assignments,
    required this.courseMap,
    required this.listDate,
    required this.initialCourseId,
    this.initialSubjectId,
    required this.teacher,
  });

  @override
  State<_CreateEditExamBottomSheet> createState() =>
      _CreateEditExamBottomSheetState();
}

class _CreateEditExamBottomSheetState
    extends State<_CreateEditExamBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _marksCtrl;
  late DateTime _examDate;
  late String? _selCourseId;
  late List<TeacherSubjectAssignment> _filteredAssignments;
  late String _selAssignmentId;
  late String _selSubjectId;
  late String _selBatchId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.examToEdit?.name);
    _marksCtrl = TextEditingController(
      text: widget.examToEdit != null
          ? widget.examToEdit!.totalMarks.toInt().toString()
          : '',
    );
    _examDate = widget.examToEdit?.examDate ?? DateTime.now();
    _selCourseId = widget.initialCourseId;

    _updateFilteredAssignments(isInit: true);
  }

  void _updateFilteredAssignments({bool isInit = false}) {
    if (_selCourseId != null) {
      _filteredAssignments = widget.assignments
          .where((s) => s.courseId == _selCourseId)
          .toList();
    } else {
      _filteredAssignments = widget.assignments;
    }

    _selAssignmentId = '';
    _selSubjectId = '';
    _selBatchId = '';

    if (_filteredAssignments.isNotEmpty) {
      final match = widget.examToEdit != null && isInit
          ? _filteredAssignments.firstWhere(
              (s) =>
                  s.subjectId == widget.examToEdit!.subjectId &&
                  (s.batchId ?? '') == (widget.examToEdit!.batchId ?? ''),
              orElse: () => _filteredAssignments.first,
            )
          : (widget.initialSubjectId != null && isInit
              ? _filteredAssignments.firstWhere(
                  (s) => s.subjectId == widget.initialSubjectId,
                  orElse: () => _filteredAssignments.first,
                )
              : _filteredAssignments.first);
      _selAssignmentId = match.id;
      _selSubjectId = match.subjectId;
      _selBatchId = match.batchId ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _marksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.examToEdit != null
                          ? 'EDIT EXAM ASSESSMENT'
                          : 'CREATE NEW EXAM',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.courseMap.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _selCourseId,
                    decoration: InputDecoration(
                      labelText: 'Course',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: widget.courseMap.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _selCourseId = val;
                        _updateFilteredAssignments();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: _selAssignmentId.isNotEmpty
                      ? _selAssignmentId
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Subject / Batch Class',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _filteredAssignments.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text('${s.subjectName} · ${s.batchName ?? "All"}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final s = _filteredAssignments.firstWhere(
                      (x) => x.id == val,
                    );
                    setState(() {
                      _selAssignmentId = s.id;
                      _selSubjectId = s.subjectId;
                      _selBatchId = s.batchId ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Exam Assessment Name',
                    hintText: 'e.g. Midterm 1, Quiz 3, Lab 1',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _marksCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Total Marks',
                          hintText: 'e.g. 50, 100',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Marks required';
                          }
                          final double? val = double.tryParse(v);
                          if (val == null || val <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _examDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d != null) {
                            setState(() => _examDate = d);
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Exam Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('d MMM yyyy').format(_examDate)),
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
                      if (_formKey.currentState!.validate()) {
                        final subjectIds =
                            widget.teacher?.subjects
                                .map((s) => s.subjectId)
                                .toList() ??
                            [];
                        final batchIds =
                            widget.teacher?.subjects
                                .map((s) => s.batchId)
                                .whereType<String>()
                                .toSet()
                                .toList() ??
                            [];
                        final courseIds =
                            widget.teacher?.courses
                                .map((c) => c.courseId)
                                .toSet()
                                .toList() ??
                            [];

                        if (widget.examToEdit == null) {
                          context.read<MarksCubit>().createExam(
                            name: _nameCtrl.text.trim(),
                            date: _examDate,
                            totalMarks: double.parse(_marksCtrl.text),
                            batchId: _selBatchId,
                            subjectId: _selSubjectId,
                            courseId: _selCourseId,
                            subjectIds: subjectIds,
                            batchIds: batchIds,
                            courseIds: courseIds,
                            listDate: widget.listDate,
                            campusId: widget.teacher?.campusId,
                          );
                        } else {
                          context.read<MarksCubit>().updateExam(
                            examId: widget.examToEdit!.id,
                            name: _nameCtrl.text.trim(),
                            date: _examDate,
                            totalMarks: double.parse(_marksCtrl.text),
                            batchId: _selBatchId,
                            subjectId: _selSubjectId,
                            courseId: _selCourseId,
                            currentSubjectId: widget.examToEdit!.subjectId,
                            subjectIds: subjectIds,
                            batchIds: batchIds,
                            courseIds: courseIds,
                            listDate: widget.listDate,
                          );
                        }
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      widget.examToEdit != null
                          ? 'Save Exam Assessment'
                          : 'Create Exam Assessment',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
