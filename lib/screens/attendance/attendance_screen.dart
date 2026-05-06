import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/neu_box.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neuBase,
      appBar: AppBar(
        title: const Text('Attendance Ledger'),
      ),
      body: BlocBuilder<StudentBloc, StudentState>(
        builder: (context, state) {
          if (state.status == StudentStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final records = state.attendance;
          if (records.isEmpty) {
            return const Center(child: Text('No attendance records found.'));
          }

          final presentCount = records.where((r) => r.isPresent).length;
          final absentCount = records.where((r) => !r.isPresent).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomCard(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            const Text('PRESENT', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            Text(
                              '$presentCount',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.success),
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
                            const Text('ABSENT', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            Text(
                              '$absentCount',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.error),
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
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
                                record.isPresent ? Icons.verified_rounded : Icons.do_not_disturb_on_rounded,
                                color: record.isPresent ? AppColors.success : AppColors.error,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE, MMMM d').format(record.date).toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    record.isPresent ? 'STATIONED' : 'UNACCOUNTED',
                                    style: TextStyle(
                                      color: record.isPresent ? AppColors.success : AppColors.error,
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
          );
        },
      ),
    );
  }
}
