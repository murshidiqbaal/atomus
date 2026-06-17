import 'package:atomus/models/dummy_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_event.dart';
import '../../blocs/student/student_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/neu_box.dart';
import 'progress_report_screen.dart';

class MarksScreen extends StatefulWidget {
  const MarksScreen({super.key});

  @override
  State<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends State<MarksScreen> {
  DateTime? _selectedDailyExamDate;

  Future<void> _handleRefresh(BuildContext context) async {
    final studentBloc = context.read<StudentBloc>();
    studentBloc.add(LoadStudentData());
    await studentBloc.stream
        .firstWhere((s) => s.status != StudentStatus.loading)
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => studentBloc.state,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Academic Record')),
      body: BlocBuilder<StudentBloc, StudentState>(
        builder: (context, state) {
          if (state.status == StudentStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.exams.isEmpty) {
            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.primary,
              onRefresh: () => _handleRefresh(context),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: const Center(
                      child: Text('No examination records found.'),
                    ),
                  ),
                ),
              ),
            );
          }

          final regularExams = state.exams.where((e) => !e.isDaily).toList()
            ..sort((a, b) {
              final da = DateTime.tryParse(a.date);
              final db = DateTime.tryParse(b.date);
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              return db.compareTo(da); // descending
            });
          final dailyExams = state.exams.where((e) => e.isDaily).toList()
            ..sort((a, b) {
              final da = DateTime.tryParse(a.date);
              final db = DateTime.tryParse(b.date);
              if (da == null && db == null) return 0;
              if (da == null) return 1;
              if (db == null) return -1;
              return db.compareTo(da); // descending
            });

          final filteredDailyExams = _selectedDailyExamDate == null
              ? dailyExams
              : dailyExams.where((e) {
                  final examDate = DateTime.tryParse(e.date);
                  if (examDate == null) return false;
                  return examDate.year == _selectedDailyExamDate!.year &&
                      examDate.month == _selectedDailyExamDate!.month &&
                      examDate.day == _selectedDailyExamDate!.day;
                }).toList();

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.primary,
            onRefresh: () => _handleRefresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              children: [
                // ── Progress Reports Banner ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: CustomCard(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (state.studentInfo != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProgressReportScreen(
                                studentInfo: state.studentInfo!,
                                exams: state.exams,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Student information is loading...'),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          NeuBox(
                            width: 50,
                            height: 50,
                            borderRadius: 14,
                            child: const Icon(
                              LucideIcons.fileSpreadsheet,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Progress Reports',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'View & download structured academic reports',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Regular Exams Section ──────────────────────────────────
                if (regularExams.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12.0, left: 4.0),
                    child: Text(
                      'EXAMINATIONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...regularExams.map(
                    (exam) => Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: _buildExamTile(exam),
                    ),
                  ),
                ],

                // Spacer if both are present
                if (regularExams.isNotEmpty && dailyExams.isNotEmpty)
                  const SizedBox(height: 16),

                // ── Daily Exams Section ────────────────────────────────────
                if (dailyExams.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4.0),
                        child: Text(
                          'DAILY ASSESSMENTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      _buildDateFilterChip(context),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filteredDailyExams.isEmpty)
                    CustomCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 20,
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              LucideIcons.calendarX,
                              color: AppColors.textSecondary,
                              size: 32,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedDailyExamDate != null
                                  ? 'No assessments found for ${DateFormat('d MMM yyyy').format(_selectedDailyExamDate!)}'
                                  : 'No daily assessments found.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredDailyExams.map(
                      (exam) => Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: _buildExamTile(exam),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateFilterChip(BuildContext context) {
    final hasDate = _selectedDailyExamDate != null;
    final label = hasDate
        ? DateFormat('d MMM yyyy').format(_selectedDailyExamDate!)
        : 'All Dates';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasDate) ...[
          GestureDetector(
            onTap: () {
              setState(() => _selectedDailyExamDate = null);
            },
            child: const Icon(LucideIcons.x, size: 14, color: AppColors.error),
          ),
          const SizedBox(width: 8),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDailyExamDate ?? now,
              firstDate: DateTime(now.year - 1),
              lastDate: now,
            );
            if (picked != null) {
              setState(() => _selectedDailyExamDate = picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.calendar,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
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

  Widget _buildExamTile(ExamSession exam) {
    String formattedDate = exam.date;
    try {
      final parsedDate = DateTime.tryParse(exam.date);
      if (parsedDate != null) {
        formattedDate = DateFormat('MMMM d, yyyy').format(parsedDate);
      }
    } catch (_) {}

    return CustomCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        collapsedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        iconColor: AppColors.accent,
        collapsedIconColor: AppColors.primary,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        title: Text(
          exam.title.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 1.0,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            exam.isDaily
                ? 'ASSESSMENT ON ${formattedDate.toUpperCase()}'
                : 'CONCLUDED ON ${formattedDate.toUpperCase()}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          const NeuDivider(),
          const SizedBox(height: 20),
          ...exam.subjects.map(
            (subject) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.subject,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${subject.marksObtained}/${subject.totalMarks}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  NeuBox(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    borderRadius: 10,
                    isPressed: true,
                    child: Text(
                      subject.grade,
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
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
}
