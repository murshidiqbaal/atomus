import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../models/dummy_data.dart';
import '../../theme/app_colors.dart';
import '../../utils/progress_report_pdf_generator.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/neu_box.dart';

class ProgressReportScreen extends StatefulWidget {
  final StudentInfo studentInfo;
  final List<ExamSession> exams;

  const ProgressReportScreen({
    super.key,
    required this.studentInfo,
    required this.exams,
  });

  @override
  State<ProgressReportScreen> createState() => _ProgressReportScreenState();
}

class _ProgressReportScreenState extends State<ProgressReportScreen> {
  // Tabs: 'daily', 'monthly', 'exam_wise'
  String _selectedTab = 'daily';

  // Daily filters
  DateTime _dailyStartDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dailyEndDate = DateTime.now();

  // Monthly filters
  DateTime? _selectedMonth;
  List<DateTime> _availableMonths = [];

  // Exam-wise filters
  String? _selectedExamTitle;
  List<String> _availableExams = [];

  @override
  void initState() {
    super.initState();
    _initializeFilters();
  }

  void _initializeFilters() {
    // 1. Calculate available months dynamically
    final Map<String, DateTime> monthsMap = {};
    for (var exam in widget.exams) {
      final dt = DateTime.tryParse(exam.date);
      if (dt != null) {
        final key = DateFormat('yyyy-MM').format(dt);
        monthsMap[key] = DateTime(dt.year, dt.month);
      }
    }
    _availableMonths = monthsMap.values.toList()
      ..sort((a, b) => b.compareTo(a));
    if (_availableMonths.isEmpty) {
      _availableMonths.add(DateTime(DateTime.now().year, DateTime.now().month));
    }
    _selectedMonth = _availableMonths.first;

    // 2. Calculate available exams dynamically
    _availableExams =
        widget.exams
            .where((e) => !e.isDaily)
            .map((e) => e.title.trim())
            .toSet()
            .toList()
          ..sort();
    if (_availableExams.isNotEmpty) {
      _selectedExamTitle = _availableExams.first;
    }
  }

  // Helper to calculate grade from percentage
  String _calculateGrade(double percentage) {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B+';
    if (percentage >= 60) return 'B';
    if (percentage >= 50) return 'C';
    return 'F';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return AppColors.success;
      case 'B+':
      case 'B':
        return AppColors.info;
      case 'C':
        return AppColors.warning;
      case 'F':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate data based on filters
    final headers = _getHeaders();
    final rows = _getRows();
    final summaryStats = _getSummaryStats(rows);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.center,
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Academic Reports',
            style: TextStyle(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 25,
              height: 1.1,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Segmented Tab bar
              _buildSegmentedTab(isDark),

              // Student Info Summary Header
              _buildStudentSummaryCard(isDark),

              // Filter Controls section
              _buildFilterSection(isDark),

              // Tabular Data Preview Section
              Expanded(
                child: _buildTabularPreviewSection(
                  isDark,
                  headers,
                  rows,
                  summaryStats,
                ),
              ),

              // Download / Print Actions Bar
              if (rows.isNotEmpty)
                _buildActionBar(isDark, headers, rows, summaryStats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentedTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.neuLightDark.withOpacity(0.5)
              : AppColors.neuDark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.glassBorder : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: _buildTabButton('daily', 'Daily', isDark)),
            Expanded(child: _buildTabButton('monthly', 'Monthly', isDark)),
            Expanded(child: _buildTabButton('exam_wise', 'Exam-Wise', isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String value, String label, bool isDark) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = value),
      child: Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary : AppColors.neuLight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            fontSize: 13,
            color: isSelected
                ? (isDark ? Colors.white : AppColors.primary)
                : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentSummaryCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            NeuBox(
              width: 46,
              height: 46,
              borderRadius: 12,
              child: const Icon(
                LucideIcons.user,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.studentInfo.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Roll No: ${widget.studentInfo.rollNumber ?? "N/A"}  •  Class: ${widget.studentInfo.grade ?? "N/A"}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.glassBase
              : AppColors.neuLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? AppColors.glassBorder
                : AppColors.neuDark.withOpacity(0.3),
          ),
        ),
        child: _buildFilterContent(isDark),
      ),
    );
  }

  Widget _buildFilterContent(bool isDark) {
    if (_selectedTab == 'daily') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT ASSESSMENT DATE RANGE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDateDisplayTile(
                  'Start Date',
                  _dailyStartDate,
                  () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dailyStartDate,
                      firstDate: DateTime(DateTime.now().year - 2),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _dailyStartDate = picked);
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Icon(
                  LucideIcons.arrowRight,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _buildDateDisplayTile(
                  'End Date',
                  _dailyEndDate,
                  () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dailyEndDate,
                      firstDate: _dailyStartDate,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _dailyEndDate = picked);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_selectedTab == 'monthly') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SELECT MONTH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.neuLightDark : AppColors.neuLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? AppColors.glassBorder
                    : AppColors.neuDark.withOpacity(0.5),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                value: _selectedMonth,
                icon: const Icon(LucideIcons.chevronDown, size: 16),
                dropdownColor: isDark
                    ? AppColors.neuLightDark
                    : AppColors.neuLight,
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedMonth = val);
                  }
                },
                items: _availableMonths.map((dt) {
                  return DropdownMenuItem<DateTime>(
                    value: dt,
                    child: Text(
                      DateFormat('MMMM yyyy').format(dt),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    } else {
      // Exam-wise
      if (_availableExams.isEmpty) {
        return const Center(
          child: Text(
            'No term exams recorded for this student.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SELECT EXAMINATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.neuLightDark : AppColors.neuLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.glassBorder
                      : AppColors.neuDark.withOpacity(0.5),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedExamTitle,
                  isExpanded: true,
                  icon: const Icon(LucideIcons.chevronDown, size: 16),
                  dropdownColor: isDark
                      ? AppColors.neuLightDark
                      : AppColors.neuLight,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedExamTitle = val);
                    }
                  },
                  items: _availableExams.map((exam) {
                    return DropdownMenuItem<String>(
                      value: exam,
                      child: Text(
                        exam.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildDateDisplayTile(
    String label,
    DateTime date,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.neuLightDark
              : AppColors.neuLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Icon(
              LucideIcons.calendar,
              size: 14,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabularPreviewSection(
    bool isDark,
    List<String> headers,
    List<List<String>> rows,
    Map<String, String> summaryStats,
  ) {
    if (rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeuBox(
              width: 70,
              height: 70,
              borderRadius: 20,
              child: const Icon(
                LucideIcons.folderClosed,
                color: AppColors.textSecondary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Records Found',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try adjusting your filter settings above.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        CustomCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Horizontal scrollable table container
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 16,
                  columnSpacing: 20,
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.primary.withOpacity(0.1),
                  ),
                  dataRowMinHeight: 46,
                  dataRowMaxHeight: 52,
                  columns: headers.map((header) {
                    return DataColumn(
                      label: Text(
                        header.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  }).toList(),
                  rows: rows.map((row) {
                    return DataRow(
                      cells: row.map((cell) {
                        final isGrade =
                            headers[row.indexOf(cell)].toLowerCase() == 'grade';
                        if (isGrade) {
                          return DataCell(
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getGradeColor(cell).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getGradeColor(
                                      cell,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  cell,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    color: _getGradeColor(cell),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return DataCell(
                          Text(
                            cell,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Statistics Overview Summary Card
        _buildOverallSummaryCard(isDark, summaryStats),
      ],
    );
  }

  Widget _buildOverallSummaryCard(bool isDark, Map<String, String> stats) {
    final grade = stats['overallGrade'] ?? 'F';
    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERFORMANCE SUMMARY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatSummaryColumn(
                'Total Assessments',
                stats['totalAssessments'] ?? '0',
              ),
              _buildStatSummaryColumn(
                'Average Percent',
                stats['overallPercentage'] ?? '0.0%',
              ),
              Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Overall Grade',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Result Level',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _getGradeColor(grade).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getGradeColor(grade).withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      grade,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: _getGradeColor(grade),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatSummaryColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(
    bool isDark,
    List<String> headers,
    List<List<String>> rows,
    Map<String, String> summaryStats,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neuDarkDark.withOpacity(0.8)
            : AppColors.neuLight,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.glassBorder
                : AppColors.neuDark.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: NeuBox(
              height: 48,
              borderRadius: 14,
              padding: EdgeInsets.zero,
              onTap: () => _handlePrint(headers, rows, summaryStats),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.printer, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Print Report',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () => _handleShare(headers, rows, summaryStats),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.download, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Download PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Action methods
  String _getReportTitle() {
    switch (_selectedTab) {
      case 'daily':
        return 'Daily Assessments Report';
      case 'monthly':
        return 'Monthly Academic Progress';
      default:
        return 'Exam-wise Academic Report';
    }
  }

  String _getPeriodText() {
    switch (_selectedTab) {
      case 'daily':
        return '${DateFormat('d MMM yyyy').format(_dailyStartDate)} - ${DateFormat('d MMM yyyy').format(_dailyEndDate)}';
      case 'monthly':
        return _selectedMonth != null
            ? DateFormat('MMMM yyyy').format(_selectedMonth!)
            : '';
      default:
        return _selectedExamTitle ?? '';
    }
  }

  void _handlePrint(
    List<String> headers,
    List<List<String>> rows,
    Map<String, String> summaryStats,
  ) {
    ProgressReportPdfGenerator.printReport(
      studentName: widget.studentInfo.fullName,
      rollNumber: widget.studentInfo.rollNumber ?? 'N/A',
      admissionNumber: widget.studentInfo.admissionNumber ?? 'N/A',
      grade: widget.studentInfo.grade ?? 'N/A',
      campusName: widget.studentInfo.campusName ?? 'Atomus Campus',
      reportTitle: _getReportTitle(),
      periodText: _getPeriodText(),
      headers: headers,
      rows: rows,
      overallPercentage: summaryStats['overallPercentage'] ?? '0.0%',
      overallGrade: summaryStats['overallGrade'] ?? 'F',
      totalAssessments: summaryStats['totalAssessments'] ?? '0',
    );
  }

  void _handleShare(
    List<String> headers,
    List<List<String>> rows,
    Map<String, String> summaryStats,
  ) {
    ProgressReportPdfGenerator.shareReport(
      studentName: widget.studentInfo.fullName,
      rollNumber: widget.studentInfo.rollNumber ?? 'N/A',
      admissionNumber: widget.studentInfo.admissionNumber ?? 'N/A',
      grade: widget.studentInfo.grade ?? 'N/A',
      campusName: widget.studentInfo.campusName ?? 'Atomus Campus',
      reportTitle: _getReportTitle(),
      periodText: _getPeriodText(),
      headers: headers,
      rows: rows,
      overallPercentage: summaryStats['overallPercentage'] ?? '0.0%',
      overallGrade: summaryStats['overallGrade'] ?? 'F',
      totalAssessments: summaryStats['totalAssessments'] ?? '0',
    );
  }

  // Business Logic Methods
  List<String> _getHeaders() {
    if (_selectedTab == 'daily') {
      return ['Date', 'Assessment', 'Subject', 'Marks', 'Grade', '%'];
    } else if (_selectedTab == 'monthly') {
      return ['Date', 'Type', 'Name', 'Subject', 'Marks', 'Grade', '%'];
    } else {
      return ['Subject', 'Marks Obtained', 'Total Marks', 'Grade', '%'];
    }
  }

  List<List<String>> _getRows() {
    final List<List<String>> computedRows = [];

    if (_selectedTab == 'daily') {
      final filteredSessions = widget.exams.where((e) {
        if (!e.isDaily) return false;
        final date = DateTime.tryParse(e.date);
        if (date == null) return false;
        // Normalize to day-only comparison
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final start = DateTime(
          _dailyStartDate.year,
          _dailyStartDate.month,
          _dailyStartDate.day,
        );
        final end = DateTime(
          _dailyEndDate.year,
          _dailyEndDate.month,
          _dailyEndDate.day,
        );
        return (normalizedDate.isAtSameMomentAs(start) ||
                normalizedDate.isAfter(start)) &&
            (normalizedDate.isAtSameMomentAs(end) ||
                normalizedDate.isBefore(end));
      }).toList()..sort((a, b) => b.date.compareTo(a.date)); // descending date

      for (var session in filteredSessions) {
        final date = DateTime.tryParse(session.date);
        final formattedDate = date != null
            ? DateFormat('d MMM yy').format(date)
            : session.date;
        for (var subject in session.subjects) {
          final percent = subject.totalMarks > 0
              ? (subject.marksObtained / subject.totalMarks) * 100
              : 0.0;
          computedRows.add([
            formattedDate,
            session.title,
            subject.subject,
            '${subject.marksObtained}/${subject.totalMarks}',
            subject.grade,
            '${percent.toStringAsFixed(0)}%',
          ]);
        }
      }
    } else if (_selectedTab == 'monthly') {
      if (_selectedMonth == null) return [];
      final filteredSessions = widget.exams.where((e) {
        final date = DateTime.tryParse(e.date);
        if (date == null) return false;
        return date.year == _selectedMonth!.year &&
            date.month == _selectedMonth!.month;
      }).toList()..sort((a, b) => b.date.compareTo(a.date));

      for (var session in filteredSessions) {
        final date = DateTime.tryParse(session.date);
        final formattedDate = date != null
            ? DateFormat('d MMM yy').format(date)
            : session.date;
        for (var subject in session.subjects) {
          final percent = subject.totalMarks > 0
              ? (subject.marksObtained / subject.totalMarks) * 100
              : 0.0;
          computedRows.add([
            formattedDate,
            session.isDaily ? 'Daily' : 'Exam',
            session.title,
            subject.subject,
            '${subject.marksObtained}/${subject.totalMarks}',
            subject.grade,
            '${percent.toStringAsFixed(0)}%',
          ]);
        }
      }
    } else {
      // Exam-wise
      if (_selectedExamTitle == null) return [];
      final filteredSessions = widget.exams.where((e) {
        return !e.isDaily &&
            e.title.trim().toLowerCase() == _selectedExamTitle!.toLowerCase();
      }).toList();

      for (var session in filteredSessions) {
        for (var subject in session.subjects) {
          final percent = subject.totalMarks > 0
              ? (subject.marksObtained / subject.totalMarks) * 100
              : 0.0;
          computedRows.add([
            subject.subject,
            subject.marksObtained.toString(),
            subject.totalMarks.toString(),
            subject.grade,
            '${percent.toStringAsFixed(0)}%',
          ]);
        }
      }
    }

    return computedRows;
  }

  Map<String, String> _getSummaryStats(List<List<String>> computedRows) {
    if (computedRows.isEmpty) {
      return {
        'totalAssessments': '0',
        'overallPercentage': '0.0%',
        'overallGrade': 'F',
      };
    }

    int totalObtained = 0;
    int totalMax = 0;

    int obtainedIndex = 3;
    if (_selectedTab == 'exam_wise') {
      obtainedIndex = 1;
    }

    for (var row in computedRows) {
      if (_selectedTab == 'exam_wise') {
        final obtained = int.tryParse(row[1]) ?? 0;
        final maxMarks = int.tryParse(row[2]) ?? 100;
        totalObtained += obtained;
        totalMax += maxMarks;
      } else {
        // format is "obtained/max"
        final parts = row[obtainedIndex].split('/');
        if (parts.length == 2) {
          totalObtained += int.tryParse(parts[0]) ?? 0;
          totalMax += int.tryParse(parts[1]) ?? 100;
        }
      }
    }

    final double avgPercentage = totalMax > 0
        ? (totalObtained / totalMax) * 100
        : 0.0;
    final overallGrade = _calculateGrade(avgPercentage);

    return {
      'totalAssessments': computedRows.length.toString(),
      'overallPercentage': '${avgPercentage.toStringAsFixed(1)}%',
      'overallGrade': overallGrade,
    };
  }
}
