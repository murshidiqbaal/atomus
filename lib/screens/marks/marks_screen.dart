import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../theme/app_colors.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/neu_box.dart';

class MarksScreen extends StatelessWidget {
  const MarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neuBase,
      appBar: AppBar(
        title: const Text('Academic Record'),
      ),
      body: BlocBuilder<StudentBloc, StudentState>(
        builder: (context, state) {
          if (state.status == StudentStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.exams.isEmpty) {
            return const Center(child: Text('No examination records found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(24.0),
            itemCount: state.exams.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final exam = state.exams[index];
              return CustomCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                  collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                  iconColor: AppColors.accent,
                  collapsedIconColor: AppColors.primary,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  title: Text(
                    exam.title.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.0),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'CONCLUDED ON ${exam.date.toUpperCase()}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    const NeuDivider(),
                    const SizedBox(height: 20),
                    ...exam.subjects.map((subject) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subject.subject,
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                              Text(
                                '${subject.marksObtained}/${subject.totalMarks}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              const SizedBox(width: 16),
                              NeuBox(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        )),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
