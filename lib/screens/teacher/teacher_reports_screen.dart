import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../blocs/daily_report/daily_report_cubit.dart';
import '../../blocs/daily_report/daily_report_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../models/teacher_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/neu_box.dart';

class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  String? _selectedCourseId;
  String? _selectedCourseName;
  String? _selectedAssignmentId;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  String? _selectedBatchId;
  String? _selectedBatchName;
  String? _selectedCampusId;
  DateTime _selectedDate = DateTime.now();
  String _sessionType = 'forenoon'; // 'forenoon' | 'afternoon'

  // Text inputs controllers
  final TextEditingController _topicsCtrl = TextEditingController();
  final TextEditingController _homeworkCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();

  // Search input controller
  final TextEditingController _studentSearchCtrl = TextEditingController();
  String _studentSearchQuery = '';

  // Student workflow lists
  List<Map<String, dynamic>> _normalStudents = [];
  List<Map<String, dynamic>> _needsImprovementStudents = [];

  // Persistent comment controllers per student ID to avoid focus loss
  final Map<String, TextEditingController> _commentCtrls = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacher = context.read<TeacherDashboardCubit>().state.teacher;
      if (teacher == null) return;

      setState(() {
        _selectedCampusId = teacher.campusId;
      });
      context.read<DailyReportCubit>().loadClassReportsForTeacher(teacher.id);
    });
  }

  void _loadData() {
    if (_selectedCourseId == null || _selectedSubjectId == null) return;
    context.read<DailyReportCubit>().loadDailyClassReport(
      courseId: _selectedCourseId!,
      batchId: _selectedBatchId ?? '',
      subjectId: _selectedSubjectId!,
      date: _selectedDate,
      sessionType: _sessionType,
      campusId: _selectedCampusId,
    );
  }

  void _populateFromLoadedState(DailyReportState state) {
    setState(() {
      final report = state.loadedClassReport;
      if (report != null) {
        _topicsCtrl.text = report['topics_covered'] as String? ?? '';
        _homeworkCtrl.text = report['homework'] as String? ?? '';
        _remarksCtrl.text = report['general_remarks'] as String? ?? '';

        final reportSubjectId = report['subject_id'] as String?;
        final reportBatchId = report['batch_id'] as String?;
        final teacher = context.read<TeacherDashboardCubit>().state.teacher;
        if (teacher != null &&
            reportSubjectId != null &&
            reportBatchId != null) {
          final match = teacher.subjects.firstWhere(
            (s) => s.subjectId == reportSubjectId && s.batchId == reportBatchId,
            orElse: () => const TeacherSubjectAssignment(
              id: '',
              subjectId: '',
              subjectName: '',
            ),
          );
          if (match.id.isNotEmpty) {
            _selectedAssignmentId = match.id;
          }
        }

        final childReports = (report['daily_student_reports'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r))
            .toList();

        final needsImprovementIds = childReports
            .where((cr) => cr['status'] == 'need_improvement')
            .map((cr) => cr['student_id'] as String)
            .toSet();

        final commentsMap = {
          for (var cr in childReports)
            if (cr['status'] == 'need_improvement' && cr['comment'] != null)
              cr['student_id'] as String: cr['comment'] as String,
        };

        _needsImprovementStudents = [];
        _normalStudents = [];

        for (final student in state.students) {
          final studentId = student['id'] as String;
          if (needsImprovementIds.contains(studentId)) {
            final commentText = commentsMap[studentId] ?? '';
            final matchingReport = childReports.firstWhere(
              (cr) => cr['student_id'] == studentId,
              orElse: () => const <String, dynamic>{},
            );
            _needsImprovementStudents.add({
              ...student,
              'comment': commentText,
              'behavior_rating':
                  matchingReport['behavior_rating'] ?? 'Needs Imp.',
              'study_engagement':
                  matchingReport['study_engagement'] ?? 'Active',
              'homework_status':
                  matchingReport['homework_status'] ?? 'Completed',
            });
            _commentCtrls.putIfAbsent(studentId, () => TextEditingController());
            _commentCtrls[studentId]!.text = commentText;
          } else {
            _normalStudents.add(student);
          }
        }
      } else {
        _topicsCtrl.clear();
        _homeworkCtrl.clear();
        _remarksCtrl.clear();
        _needsImprovementStudents = [];
        _normalStudents = List<Map<String, dynamic>>.from(state.students);
        for (final ctrl in _commentCtrls.values) {
          ctrl.dispose();
        }
        _commentCtrls.clear();
      }
    });
  }

  void _moveStudentToNeedsImprovement(Map<String, dynamic> student) {
    setState(() {
      _normalStudents.removeWhere((s) => s['id'] == student['id']);
      final studentId = student['id'] as String;

      _commentCtrls.putIfAbsent(studentId, () => TextEditingController());
      _commentCtrls[studentId]!.text = '';

      _needsImprovementStudents.add({
        ...student,
        'comment': '',
        'behavior_rating': 'Needs Imp.',
        'study_engagement': 'Active',
        'homework_status': 'Completed',
      });
      _studentSearchCtrl.clear();
      _studentSearchQuery = '';
    });
  }

  void _moveStudentToNormal(Map<String, dynamic> student) {
    setState(() {
      _needsImprovementStudents.removeWhere((s) => s['id'] == student['id']);
      final studentId = student['id'] as String;

      if (_commentCtrls.containsKey(studentId)) {
        _commentCtrls[studentId]!.text = '';
      }

      final cleanStudent = Map<String, dynamic>.from(student)
        ..remove('comment');
      _normalStudents.add(cleanStudent);
      _normalStudents.sort((a, b) {
        final rA = a['roll_number'] as String? ?? '';
        final rB = b['roll_number'] as String? ?? '';
        return rA.compareTo(rB);
      });
    });
  }

  void _saveReport() {
    final topics = _topicsCtrl.text.trim();
    if (topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Topics Covered Today is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_normalStudents.isEmpty && _needsImprovementStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students found in this batch.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    for (final student in _needsImprovementStudents) {
      final studentId = student['id'] as String;
      final commentText = (_commentCtrls[studentId]?.text ?? '').trim();
      if (commentText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter a comment for ${student['full_name']}.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;

    final List<Map<String, dynamic>> studentReports = [];
    for (final s in _normalStudents) {
      studentReports.add({
        'student_id': s['id'],
        'status': 'normal',
        'comment': null,
        'behavior_rating': 'Excellent',
        'study_engagement': 'Active',
        'homework_status': 'Completed',
      });
    }
    for (final s in _needsImprovementStudents) {
      final studentId = s['id'] as String;
      final commentText = (_commentCtrls[studentId]?.text ?? '').trim();
      studentReports.add({
        'student_id': studentId,
        'status': 'need_improvement',
        'comment': commentText,
        'behavior_rating': s['behavior_rating'] ?? 'Needs Imp.',
        'study_engagement': s['study_engagement'] ?? 'Active',
        'homework_status': s['homework_status'] ?? 'Completed',
      });
    }

    context
        .read<DailyReportCubit>()
        .saveDailyClassReport(
          courseId: _selectedCourseId!,
          batchId: _selectedBatchId ?? '',
          subjectId: _selectedSubjectId!,
          date: _selectedDate,
          sessionType: _sessionType,
          teacherId: teacher.id,
          topicsCovered: topics,
          homework: _homeworkCtrl.text.trim().isEmpty
              ? null
              : _homeworkCtrl.text.trim(),
          generalRemarks: _remarksCtrl.text.trim().isEmpty
              ? null
              : _remarksCtrl.text.trim(),
          studentReports: studentReports,
        )
        .then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Daily class report saved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.read<DailyReportCubit>().loadClassReportsForTeacher(
            teacher.id,
          );
        });
  }

  @override
  void dispose() {
    _topicsCtrl.dispose();
    _homeworkCtrl.dispose();
    _remarksCtrl.dispose();
    _studentSearchCtrl.dispose();
    for (final ctrl in _commentCtrls.values) {
      ctrl.dispose();
    }
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
            'Daily Class Report',
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
            if (state.status == DailyReportStatus.success) {
              _populateFromLoadedState(state);
            }
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
            final hasSelection =
                _selectedCourseId != null && _selectedSubjectId != null;

            return Column(
              children: [
                _buildWorkspaceSelectors(),
                Expanded(
                  child: !hasSelection
                      ? _buildInitialEmptyState()
                      : state.status == DailyReportStatus.loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSessionStatsCard(),
                              const SizedBox(height: 16),
                              _buildSearchAndAddCard(),
                              const SizedBox(height: 16),
                              _buildNeedsImprovementCard(),
                              const SizedBox(height: 16),
                              _buildTopicsCard(),
                              const SizedBox(height: 16),
                              _buildHomeworkCard(),
                              const SizedBox(height: 16),
                              _buildRemarksCard(),
                              const SizedBox(height: 24),
                              _buildSaveButton(state),
                            ],
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

  Widget _buildWorkspaceSelectors() {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return const SizedBox.shrink();

    final allCourses = teacher.courses;
    final allSubjects = teacher.subjects;

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
        : <TeacherSubjectAssignment>[];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(color: AppColors.textSecondary.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSelectorDropdown<String?>(
                  label: 'COURSE',
                  value: courseEntries.any((e) => e.key == _selectedCourseId)
                      ? _selectedCourseId
                      : null,
                  hint: 'Select Course',
                  items: courseEntries
                      .map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.key,
                          child: Text(
                            e.value,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCourseId = val;
                      _selectedCourseName = val != null ? courseMap[val] : null;
                      _selectedAssignmentId = null;
                      _selectedSubjectId = null;
                      _selectedSubjectName = null;
                      _selectedBatchId = null;
                      _selectedBatchName = null;
                      _normalStudents = [];
                      _needsImprovementStudents = [];
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSelectorDropdown<String?>(
                  label: 'SUBJECT',
                  value:
                      filteredSubjects.any((s) => s.id == _selectedAssignmentId)
                      ? _selectedAssignmentId
                      : null,
                  hint: 'Select Subject',
                  items: filteredSubjects
                      .map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(
                            '${s.subjectName}${s.batchName != null ? " · ${s.batchName}" : ""}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final match = filteredSubjects.firstWhere(
                      (x) => x.id == val,
                    );
                    setState(() {
                      _selectedAssignmentId = val;
                      _selectedSubjectId = match.subjectId;
                      _selectedSubjectName = match.subjectName;
                      _selectedBatchId = match.batchId;
                      _selectedBatchName = match.batchName;
                    });
                    _loadData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REPORT DATE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 30),
                          ),
                          lastDate: DateTime.now().add(const Duration(days: 1)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  onSurface: AppColors.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                          });
                          _loadData();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.textSecondary.withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('yyyy-MM-dd').format(_selectedDate),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              LucideIcons.calendar,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SESSION',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _sessionType = 'forenoon';
                              });
                              _loadData();
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _sessionType == 'forenoon'
                                    ? AppColors.primary
                                    : Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                                border: Border.all(
                                  color: _sessionType == 'forenoon'
                                      ? AppColors.primary
                                      : AppColors.textSecondary.withOpacity(
                                          0.15,
                                        ),
                                ),
                              ),
                              child: Text(
                                'FORENOON',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _sessionType == 'forenoon'
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _sessionType = 'afternoon';
                              });
                              _loadData();
                            },
                            child: Container(
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _sessionType == 'afternoon'
                                    ? AppColors.primary
                                    : Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                border: Border.all(
                                  color: _sessionType == 'afternoon'
                                      ? AppColors.primary
                                      : AppColors.textSecondary.withOpacity(
                                          0.15,
                                        ),
                                ),
                              ),
                              child: Text(
                                'AFTERNOON',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _sessionType == 'afternoon'
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorDropdown<T>({
    required String label,
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.textSecondary.withOpacity(0.15),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(
                hint,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              items: items,
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialEmptyState() {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    return BlocBuilder<DailyReportCubit, DailyReportState>(
      builder: (context, state) {
        final reports = state.classReports;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Empty illustration card
              Center(
                child: Column(
                  children: [
                    NeuBox(
                      width: 80,
                      height: 80,
                      borderRadius: 24,
                      child: const Icon(
                        LucideIcons.clipboardList,
                        color: AppColors.textSecondary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Daily Class Report Workspace',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select Course & Subject to write a new report',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Divider & Section Title
              Row(
                children: [
                  const Text(
                    'Recent Reports',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (teacher != null)
                    IconButton(
                      icon: const Icon(LucideIcons.refreshCw, size: 14),
                      onPressed: () {
                        context
                            .read<DailyReportCubit>()
                            .loadClassReportsForTeacher(teacher.id);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (state.status == DailyReportStatus.loading && reports.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (reports.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textSecondary.withOpacity(0.08),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'No saved class reports found.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final dateStr = report['report_date'] as String;
                    final parsedDate =
                        DateTime.tryParse(dateStr) ?? DateTime.now();
                    final formattedDate = DateFormat(
                      'EEEE, MMM d, yyyy',
                    ).format(parsedDate);

                    final courseName =
                        (report['courses'] as Map?)?['name'] as String? ??
                        'Course';
                    final batchName =
                        (report['batches'] as Map?)?['name'] as String?;
                    final subjectName =
                        (report['subjects'] as Map?)?['name'] as String? ??
                        'Subject';
                    final session =
                        (report['session_type'] as String? ?? 'forenoon')
                            .toUpperCase();
                    final topics = report['topics_covered'] as String? ?? '';

                    return CustomCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  session,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$courseName${batchName != null ? " · $batchName" : ""} · $subjectName',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Topics: $topics',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(LucideIcons.edit3, size: 14),
                                label: const Text(
                                  'View / Edit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  _openReportForEdit(report);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _openReportForEdit(Map<String, dynamic> report) {
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;

    final allSubjects = teacher.subjects;
    final match = allSubjects.firstWhere(
      (s) =>
          s.subjectId == report['subject_id'] &&
          s.courseId == report['course_id'] &&
          (s.batchId == report['batch_id'] ||
              (s.batchId == null && report['batch_id'] == null)),
      orElse: () => const TeacherSubjectAssignment(
        id: '',
        subjectId: '',
        subjectName: '',
      ),
    );

    if (match.id.isNotEmpty) {
      setState(() {
        _selectedAssignmentId = match.id;
        _selectedCourseId = report['course_id'] as String?;
        _selectedCourseName = match.courseName;
        _selectedSubjectId = report['subject_id'] as String?;
        _selectedSubjectName = match.subjectName;
        _selectedBatchId = report['batch_id'] as String?;
        _selectedBatchName = match.batchName;
        _selectedDate =
            DateTime.tryParse(report['report_date'] as String? ?? '') ??
            DateTime.now();
        _sessionType = report['session_type'] as String? ?? 'forenoon';
      });
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This subject/batch assignment is no longer active for you.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildSessionStatsCard() {
    final total = _normalStudents.length + _needsImprovementStudents.length;
    final normalCount = _normalStudents.length;
    final needsImpCount = _needsImprovementStudents.length;

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👨🎓 Students Overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('🟢 ', style: TextStyle(fontSize: 14)),
              Text(
                'Normal Students: $normalCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🟡 ', style: TextStyle(fontSize: 14)),
              Text(
                'Need Improvement: $needsImpCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('🔵 ', style: TextStyle(fontSize: 14)),
              Text(
                'Total Students: $total',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (_normalStudents.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Normal Students (Tap to mark for improvement):',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _normalStudents.map((s) {
                return InkWell(
                  onTap: () => _moveStudentToNeedsImprovement(s),
                  borderRadius: BorderRadius.circular(8),
                  child: Chip(
                    label: Text(
                      s['full_name'] as String? ?? 'Student',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: AppColors.success.withOpacity(0.08),
                    side: BorderSide(color: AppColors.success.withOpacity(0.2)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndAddCard() {
    final filteredNormal = _normalStudents.where((s) {
      final name = (s['full_name'] as String? ?? '').toLowerCase();
      return name.contains(_studentSearchQuery.toLowerCase());
    }).toList();

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🔍 Need Improvement Students',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _studentSearchCtrl,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search Student...........',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _studentSearchQuery = val;
              });
            },
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.textSecondary.withOpacity(0.1),
              ),
            ),
            child: filteredNormal.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No matching students found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filteredNormal.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = filteredNormal[index];
                      return ListTile(
                        title: Text(
                          s['full_name'] as String? ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: GestureDetector(
                          onTap: () => _moveStudentToNeedsImprovement(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              '[+]',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsImprovementCard() {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '⚠️ Need Improvement Students',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_needsImprovementStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No students marked for improvement today.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _needsImprovementStudents.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final student = _needsImprovementStudents[index];
                final studentId = student['id'] as String;
                final ctrl = _commentCtrls[studentId];

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            student['full_name'] as String? ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _moveStudentToNormal(student),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Text('❌', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStudentFieldDropdown<String>(
                              label: 'BEHAVIOR',
                              value:
                                  student['behavior_rating'] as String? ??
                                  'Needs Imp.',
                              items: const [
                                'Excellent',
                                'Good',
                                'Average',
                                'Needs Imp.',
                                'Poor',
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    student['behavior_rating'] = val;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStudentFieldDropdown<String>(
                              label: 'ENGAGEMENT',
                              value:
                                  student['study_engagement'] as String? ??
                                  'Active',
                              items: const ['Active', 'Passive', 'Distracted'],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    student['study_engagement'] = val;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStudentFieldDropdown<String>(
                              label: 'HOMEWORK',
                              value:
                                  student['homework_status'] as String? ??
                                  'Completed',
                              items: const [
                                'Completed',
                                'Not Completed',
                                'Partial',
                                'N/A',
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    student['homework_status'] = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Comments:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ctrl,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Needs improvement in...',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.textSecondary.withOpacity(0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          student['comment'] = val;
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopicsCard() {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Topics Covered Today',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _topicsCtrl,
            maxLines: 4,
            maxLength: 2000,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter topics covered today...',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard() {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Homework Given Today',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _homeworkCtrl,
            maxLines: 4,
            maxLength: 2000,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter homework details (optional)...',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksCard() {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'General Remarks',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _remarksCtrl,
            maxLines: 4,
            maxLength: 2000,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter general class remarks (optional)...',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(DailyReportState state) {
    final isSaving = state.status == DailyReportStatus.saving;
    return ElevatedButton(
      onPressed: isSaving ? null : _saveReport,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text(
              'Save Report',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
    );
  }

  Widget _buildStudentFieldDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.textSecondary.withOpacity(0.15),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              items: items.map((val) {
                return DropdownMenuItem<T>(
                  value: val,
                  child: Text(
                    val.toString(),
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
