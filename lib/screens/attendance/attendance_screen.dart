import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_event.dart';
import '../../blocs/student/student_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/neu_box.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendanceForMonth(_selectedMonth);
  }

  void _loadAttendanceForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    context.read<StudentBloc>().add(
      LoadAttendance(startDate: start, endDate: end),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Attendance Ledger')),
      body: BlocBuilder<StudentBloc, StudentState>(
        builder: (context, state) {
          final records = state.attendance;
          final presentCount = records.where((r) => r.isPresent).length;
          final absentCount = records.where((r) => !r.isPresent).length;

          return Column(
            children: [
              // Month Selector
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: CustomCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _previousMonth,
                        icon: const Icon(
                          Icons.chevron_left,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMMM yyyy',
                        ).format(_selectedMonth).toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.0,
                          color: AppColors.primary,
                        ),
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const Icon(
                          Icons.chevron_right,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (state.status == StudentStatus.loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: CustomCard(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              const Text(
                                'PRESENT',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$presentCount',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: CustomCard(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              const Text(
                                'ABSENT',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '$absentCount',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chronological Registry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: records.isEmpty
                      ? const Center(
                          child: Text('No attendance records for this period.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: CustomCard(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    NeuBox(
                                      width: 52,
                                      height: 52,
                                      borderRadius: 14,
                                      isPressed: true,
                                      padding: EdgeInsets.zero,
                                      child: Icon(
                                        record.isPresent
                                            ? Icons.verified_rounded
                                            : Icons.do_not_disturb_on_rounded,
                                        color: record.isPresent
                                            ? AppColors.success
                                            : AppColors.error,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat(
                                              'EEEE, MMMM d',
                                            ).format(record.date).toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            record.status.toUpperCase(),
                                            style: TextStyle(
                                              color: record.isPresent
                                                  ? AppColors.success
                                                  : AppColors.error,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
