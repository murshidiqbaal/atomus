import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/progress_chart.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Performance Analytics')),
        body: BlocBuilder<StudentBloc, StudentState>(
          builder: (context, state) {
            if (state.status == StudentStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final student = state.studentInfo;
            if (student == null) return const SizedBox();

            return GlassBackground(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Academic Trajectory',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const ProgressChart(
                            dataPoints: [0.72, 0.78, 0.75, 0.88, 0.85, 0.92],
                            labels: ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN'],
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('PEAK', '94%', AppColors.success),
                              _buildStatItem('AVG', '82%', AppColors.accent),
                              _buildStatItem('TERM', '+12%', AppColors.info),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                    const Text(
                      'Composite Scoring Breakdown',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnalyticalBreakdown(context, student.overallProgress),

                    const SizedBox(height: 40),
                    const Text(
                      'Subject Proficiency',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._buildProficiencyList(context),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticalBreakdown(BuildContext context, double total) {
    final components = [
      {
        'label': 'ACADEMIC PERFORMANCE',
        'weight': '70%',
        'score': '92%',
        'value': 0.92,
        'color': AppColors.primary,
      },
      {
        'label': 'ATTENDANCE CONSISTENCY',
        'weight': '20%',
        'score': '96%',
        'value': 0.96,
        'color': AppColors.success,
      },
      {
        'label': 'BEHAVIORAL STANDARDS',
        'weight': '10%',
        'score': '88%',
        'value': 0.88,
        'color': AppColors.accent,
      },
    ];

    return Column(
      children: components
          .map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: NeuBox(
                padding: const EdgeInsets.all(20),
                borderRadius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          c['label'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          c['weight'] as String,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: c['value'] as double,
                              minHeight: 6,
                              backgroundColor: AppColors.neuDark.withOpacity(
                                0.2,
                              ),
                              color: c['color'] as Color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          c['score'] as String,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  List<Widget> _buildProficiencyList(BuildContext context) {
    final proficiencies = [
      {'subject': 'MATHEMATICS', 'value': 0.94, 'color': AppColors.primary},
      {
        'subject': 'PHYSICAL SCIENCES',
        'value': 0.88,
        'color': AppColors.accent,
      },
      {'subject': 'LITERATURE & ARTS', 'value': 0.91, 'color': AppColors.info},
      {'subject': 'SOCIAL STUDIES', 'value': 0.85, 'color': AppColors.success},
    ];

    return proficiencies
        .map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      p['subject'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 1.0,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${((p['value'] as double) * 100).toInt()}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
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
                      width:
                          MediaQuery.of(context).size.width *
                          (p['value'] as double) *
                          0.75,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (p['color'] as Color).withOpacity(0.7),
                            p['color'] as Color,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
