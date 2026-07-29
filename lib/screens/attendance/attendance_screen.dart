import 'package:atomus/blocs/course/course_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../blocs/course/course_bloc.dart';
import '../../blocs/course/course_state.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_event.dart';
import '../../blocs/student/student_state.dart';
import '../../models/dummy_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/shimmer.dart';

class AttendanceScreen extends StatefulWidget {
  final bool isPlainWhiteBackground;

  const AttendanceScreen({
    super.key,
    this.isPlainWhiteBackground = false,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCourseId;
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    final studentInfo = context.read<StudentBloc>().state.studentInfo;
    if (studentInfo?.courseId != null) {
      _selectedCourseId = studentInfo!.courseId;
      context.read<CourseBloc>().add(LoadSubjects(_selectedCourseId!));
    }
    _loadAttendanceForMonth(_selectedMonth);
  }

  void _loadAttendanceForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    context.read<StudentBloc>().add(
      LoadAttendance(
        startDate: start,
        endDate: end,
        courseId: _selectedCourseId,
        subjectId: _selectedSubjectId,
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
    _loadAttendanceForMonth(_selectedMonth);
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
    _loadAttendanceForMonth(_selectedMonth);
  }

  Future<void> _handleRefresh() async {
    final studentBloc = context.read<StudentBloc>();
    studentBloc.add(LoadStudentData());

    final newState = await studentBloc.stream
        .firstWhere((s) => s.status != StudentStatus.loading)
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => studentBloc.state,
        );

    final studentInfo = newState.studentInfo;
    if (studentInfo?.courseId != null &&
        _selectedCourseId != studentInfo!.courseId) {
      setState(() {
        _selectedCourseId = studentInfo.courseId;
      });
      context.read<CourseBloc>().add(LoadSubjects(_selectedCourseId!));
    }

    _loadAttendanceForMonth(_selectedMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isPlainWhiteBackground ? Colors.white : Colors.transparent,
      appBar: AppBar(title: const Text('Attendance')),
      body: BlocListener<StudentBloc, StudentState>(
        listenWhen: (previous, current) =>
            previous.studentInfo?.courseId != current.studentInfo?.courseId,
        listener: (context, state) {
          final courseId = state.studentInfo?.courseId;
          if (courseId != null && courseId != _selectedCourseId) {
            setState(() {
              _selectedCourseId = courseId;
            });
            context.read<CourseBloc>().add(LoadSubjects(courseId));
          }
        },
        child: BlocBuilder<StudentBloc, StudentState>(
          builder: (context, state) {
            final records = state.attendance;

            final Map<int, List<AttendanceRecord>> dailyRecords = {};
            for (final record in records) {
              if (record.date.month == _selectedMonth.month &&
                  record.date.year == _selectedMonth.year) {
                dailyRecords.putIfAbsent(record.date.day, () => []).add(record);
              }
            }

            final Map<int, String> recordMap = {};
            int presentCount = 0;
            int absentCount = 0;
            int lateCount = 0;

            dailyRecords.forEach((day, dayRecords) {
              int present = 0;
              int absent = 0;
              int late = 0;
              for (var r in dayRecords) {
                if (r.status == 'Present') {
                  present++;
                } else if (r.status == 'Absent') {
                  absent++;
                } else if (r.status == 'Late') {
                  late++;
                }
              }

              if (present == 0 && absent == 0 && late == 0) return;

              String overallStatus = '';
              if (present >= absent && present >= late) {
                overallStatus = 'Present';
                presentCount++;
              } else if (late > present && late >= absent) {
                overallStatus = 'Late';
                lateCount++;
              } else {
                overallStatus = 'Absent';
                absentCount++;
              }

              recordMap[day] = overallStatus;
            });

            final daysInMonth = DateTime(
              _selectedMonth.year,
              _selectedMonth.month + 1,
              0,
            ).day;
            // DateTime.weekday: 1=Mon ... 7=Sun; offset so Mon is column 0
            final startOffset =
                DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday -
                1;
            final today = DateTime.now();

            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: AppColors.primary,
              onRefresh: _handleRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    // Month and Subject Selectors
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 6),
                                child: Text(
                                  'MONTH',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              CustomCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 3,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: _previousMonth,
                                      icon: const Icon(
                                        Icons.chevron_left,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    Expanded(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          DateFormat('MMM yyyy')
                                              .format(_selectedMonth)
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            letterSpacing: 1.0,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      onPressed: _nextMonth,
                                      icon: const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: _buildFilters(context)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (state.status == StudentStatus.loading)
                      Column(
                        children: [
                          Row(
                            children: const [
                              Expanded(child: Shimmer(width: double.infinity, height: 60, borderRadius: 16)),
                              SizedBox(width: 10),
                              Expanded(child: Shimmer(width: double.infinity, height: 60, borderRadius: 16)),
                              SizedBox(width: 10),
                              Expanded(child: Shimmer(width: double.infinity, height: 60, borderRadius: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Shimmer(width: double.infinity, height: 300, borderRadius: 20),
                        ],
                      )
                    else ...[
                      // Summary chips
                      Row(
                        children: [
                          _buildSummaryCard(
                            'PRESENT',
                            presentCount,
                            AppColors.success,
                          ),
                          const SizedBox(width: 10),
                          _buildSummaryCard(
                            'ABSENT',
                            absentCount,
                            AppColors.error,
                          ),
                          const SizedBox(width: 10),
                          _buildSummaryCard(
                            'LATE',
                            lateCount,
                            AppColors.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Calendar card
                      CustomCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Weekday header row
                            Row(
                              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                                  .map(
                                    (d) => Expanded(
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            // Day cells
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    mainAxisSpacing: 5,
                                    crossAxisSpacing: 5,
                                    childAspectRatio: 1,
                                  ),
                              itemCount: startOffset + daysInMonth,
                              itemBuilder: (context, index) {
                                if (index < startOffset) {
                                  return const SizedBox();
                                }
                                final day = index - startOffset + 1;
                                final status = recordMap[day];
                                final date = DateTime(
                                  _selectedMonth.year,
                                  _selectedMonth.month,
                                  day,
                                );
                                final isToday =
                                    date.year == today.year &&
                                    date.month == today.month &&
                                    date.day == today.day;
                                final isFuture = date.isAfter(
                                  DateTime(today.year, today.month, today.day),
                                );

                                Color? bgColor;
                                Color textColor =
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimary;

                                if (!isFuture && status != null) {
                                  switch (status) {
                                    case 'Present':
                                      bgColor = AppColors.success;
                                      textColor = Colors.white;
                                      break;
                                    case 'Absent':
                                      bgColor = AppColors.error;
                                      textColor = Colors.white;
                                      break;
                                    case 'Late':
                                      bgColor = AppColors.warning;
                                      textColor = Colors.white;
                                      break;
                                  }
                                }

                                final isSelected =
                                    _selectedDate.year == date.year &&
                                    _selectedDate.month == date.month &&
                                    _selectedDate.day == date.day;

                                return GestureDetector(
                                  onTap: () {
                                    if (!isFuture) {
                                      setState(() {
                                        _selectedDate = date;
                                      });
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                      color: bgColor != null
                                          ? bgColor.withOpacity(
                                              isSelected ? 0.8 : 1.0,
                                            )
                                          : isSelected
                                          ? AppColors.primary.withOpacity(0.2)
                                          : (isToday
                                                ? AppColors.primary.withOpacity(
                                                    0.08,
                                                  )
                                                : Colors.transparent),
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color:
                                                  bgColor ?? AppColors.primary,
                                              width: 2.0,
                                            )
                                          : isToday && bgColor == null
                                          ? Border.all(
                                              color: AppColors.primary,
                                              width: 1.5,
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$day',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              (isToday ||
                                                  bgColor != null ||
                                                  isSelected)
                                              ? FontWeight.w900
                                              : FontWeight.w500,
                                          color: isFuture
                                              ? AppColors.textSecondary
                                                    .withOpacity(0.3)
                                              : (bgColor != null
                                                    ? Colors.white
                                                    : (isSelected
                                                          ? AppColors.primary
                                                          : textColor)),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            // Legend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegend('Present', AppColors.success),
                                const SizedBox(width: 20),
                                _buildLegend('Absent', AppColors.error),
                                const SizedBox(width: 20),
                                _buildLegend('Late', AppColors.warning),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildAttendanceHoursCard(
                        records,
                        context.read<CourseBloc>().state.subjects,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return BlocBuilder<CourseBloc, CourseState>(
      builder: (context, state) {
        return _buildDropdown<String>(
          label: 'SUBJECT',
          value: _selectedSubjectId,
          items: [
            const DropdownMenuItem(value: null, child: Text('All Subjects')),
            ...state.subjects.map((s) {
              return DropdownMenuItem(
                value: s.id,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              );
            }),
          ],
          onChanged: (val) {
            setState(() {
              _selectedSubjectId = val;
            });
            _loadAttendanceForMonth(_selectedMonth);
          },
        );
      },
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              dropdownColor: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, int count, Color color) {
    return Expanded(
      child: CustomCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceHoursCard(
    List<AttendanceRecord> allRecords,
    List<Subject> subjects,
  ) {
    final dailyRecords = allRecords
        .where(
          (r) =>
              r.date.year == _selectedDate.year &&
              r.date.month == _selectedDate.month &&
              r.date.day == _selectedDate.day,
        )
        .toList();

    // Sort by session type (forenoon, afternoon, evening) or period number
    final sessionOrder = {'forenoon': 1, 'afternoon': 2, 'evening': 3};
    dailyRecords.sort((a, b) {
      final orderA = sessionOrder[a.sessionType?.toLowerCase()] ?? (a.periodNumber ?? 99);
      final orderB = sessionOrder[b.sessionType?.toLowerCase()] ?? (b.periodNumber ?? 99);
      return orderA.compareTo(orderB);
    });

    return CustomCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'DAILY ATTENDANCE - ${DateFormat('MMM d, yyyy').format(_selectedDate).toUpperCase()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (dailyRecords.isEmpty)
            _buildSingleAttendanceDetail(
              context,
              AttendanceRecord(
                id: 'dummy',
                studentId: '',
                date: _selectedDate,
                status: 'Unmarked',
              ),
              subjects,
            )
          else
            Column(
              children: [
                for (int i = 0; i < dailyRecords.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildSingleAttendanceDetail(
                    context,
                    dailyRecords[i],
                    subjects,
                    index: i,
                    totalCount: dailyRecords.length,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSingleAttendanceDetail(
    BuildContext context,
    AttendanceRecord record,
    List<Subject> subjects, {
    int index = 0,
    int totalCount = 1,
  }) {
    Color bgColor;
    if (record.status == 'Present') {
      bgColor = AppColors.success;
    } else if (record.status == 'Absent') {
      bgColor = AppColors.error;
    } else if (record.status == 'Late') {
      bgColor = AppColors.warning;
    } else {
      bgColor = Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.05);
    }

    String subjectName = record.subjectName ?? 'Unassigned';
    String teacherName = record.markerName ?? 'N/A';

    if (subjectName == 'Unassigned' && record.subjectId != null) {
      final subject = subjects.firstWhere(
        (s) => s.id == record.subjectId,
        orElse: () => Subject(id: '', name: 'Unknown Subject'),
      );
      subjectName = subject.name;
    }
    if (teacherName == 'N/A') {
      teacherName = 'Teacher';
    }

    String? sessionStr = record.sessionType;
    if (sessionStr == null && totalCount == 2) {
      sessionStr = index == 0 ? 'Forenoon' : 'Afternoon';
    }

    final periodStr = record.periodNumber != null ? 'Period ${record.periodNumber}' : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: bgColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    record.status == 'Present'
                        ? LucideIcons.checkCircle
                        : record.status == 'Absent'
                            ? LucideIcons.xCircle
                            : record.status == 'Late'
                                ? LucideIcons.clock
                                : LucideIcons.helpCircle,
                    color: record.status != 'Unmarked'
                        ? bgColor
                        : AppColors.textSecondary,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                record.status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.5,
                  color: record.status != 'Unmarked'
                      ? bgColor
                      : AppColors.textSecondary,
                ),
              ),
              if (sessionStr != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    sessionStr.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              if (periodStr != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    periodStr.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (record.status != 'Unmarked') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    subjectName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.user,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        teacherName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (record.status == 'Unmarked') ...[
            const SizedBox(height: 8),
            const Text(
              'No attendance marked for this day.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
