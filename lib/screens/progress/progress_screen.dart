import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../theme/app_colors.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/custom_card.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neuBase,
      appBar: AppBar(
        title: const Text('Performance Analytics'),
      ),
      body: BlocBuilder<StudentBloc, StudentState>(
        builder: (context, state) {
          if (state.status == StudentStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final student = state.studentInfo;
          if (student == null) return const SizedBox();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Composite Performance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                Center(
                  child: NeuBox(
                    width: 220,
                    height: 220,
                    borderRadius: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: CircularProgressIndicator(
                            value: student.overallProgress,
                            strokeWidth: 12,
                            backgroundColor: AppColors.neuDark.withOpacity(0.3),
                            color: AppColors.accent,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(student.overallProgress * 100).toInt()}%',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Text(
                              'SCORE',
                              style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 2.0, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'Subject Proficiency',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                ..._buildProficiencyList(context),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildProficiencyList(BuildContext context) {
    final proficiencies = [
      {'subject': 'MATHEMATICS', 'value': 0.94, 'color': AppColors.primary},
      {'subject': 'PHYSICAL SCIENCES', 'value': 0.88, 'color': AppColors.accent},
      {'subject': 'LITERATURE & ARTS', 'value': 0.91, 'color': AppColors.info},
      {'subject': 'SOCIAL STUDIES', 'value': 0.85, 'color': AppColors.success},
    ];

    return proficiencies.map((p) => Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(p['subject'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.0, color: AppColors.textSecondary)),
              Text('${((p['value'] as double) * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          NeuInset(
            padding: EdgeInsets.zero,
            borderRadius: 10,
            child: Container(
              height: 12,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(seconds: 1),
                width: MediaQuery.of(context).size.width * (p['value'] as double) * 0.75, // Simplified width calculation
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (p['color'] as Color).withOpacity(0.7),
                      p['color'] as Color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (p['color'] as Color).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    )).toList();
  }
}
