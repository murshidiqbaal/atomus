import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/fee/fee_bloc.dart';
import '../../blocs/fee/fee_state.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/status_badge.dart';
import '../progress/progress_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocBuilder<StudentBloc, StudentState>(
        builder: (context, state) {
          if (state.status == StudentStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == StudentStatus.failure) {
            return Center(child: Text('Error: ${state.errorMessage}'));
          }

          final student = state.studentInfo;
          if (student == null) return const SizedBox();

          return GlassBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESTEEMED PARENT',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppColors.accent,
                                    letterSpacing: 2.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome Back',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                  ),
                            ),
                          ],
                        ),
                        BlocBuilder<ThemeBloc, ThemeState>(
                          builder: (context, themeState) {
                            final isDark =
                                themeState.themeMode == ThemeMode.dark;
                            return NeuBox(
                              width: 50,
                              height: 50,
                              borderRadius: 12,
                              padding: EdgeInsets.zero,
                              onTap: () =>
                                  context.read<ThemeBloc>().add(ToggleTheme()),
                              child: Center(
                                child: Icon(
                                  isDark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Student Profile Card
                    CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          NeuBox(
                            width: 70,
                            height: 70,
                            borderRadius: 35,
                            padding: const EdgeInsets.all(3),
                            color: AppColors.accent,
                            child: CircleAvatar(
                              radius: 32,
                              backgroundImage: NetworkImage(student.profileUrl),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name.toUpperCase(),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                        fontSize: 18,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  student.grade.toUpperCase(),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Academic Insights Grid
                    Row(
                      children: [
                        Expanded(
                          child: CustomCard(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ProgressScreen(),
                                ),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.analytics_rounded,
                                  color: AppColors.accent,
                                  size: 28,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'PROGRESS',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        letterSpacing: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${(student.overallProgress * 100).toInt()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      '%',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.5),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                StatusBadge(
                                  status: BadgeStatus.fromProgress(
                                    student.overallProgress,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: CustomCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: AppColors.success,
                                  size: 28,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'ATTENDANCE',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                        letterSpacing: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '92',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Text(
                                      '%',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.5),
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                StatusBadge(status: BadgeStatus.excellent),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // Recent Evaluations Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(context, 'Recent Evaluations'),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'ARCHIVE',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                state.exams.first.title.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                state.exams.first.date,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const NeuDivider(),
                          const SizedBox(height: 16),
                          ...state.exams.first.subjects
                              .take(2)
                              .map(
                                (subject) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        subject.subject,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).primaryColor.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '${subject.marksObtained}/${subject.totalMarks}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Financial Overview
                    _buildSectionHeader(context, 'Financial Overview'),
                    const SizedBox(height: 16),
                    BlocBuilder<FeeBloc, FeeState>(
                      builder: (context, feeState) {
                        if (feeState.status == FeeStatus.loading) {
                          return const Center(child: LinearProgressIndicator());
                        }
                        if (feeState.fees.isEmpty) return const SizedBox();

                        final firstFee = feeState.fees.first;

                        return CustomCard(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              NeuBox(
                                width: 50,
                                height: 50,
                                borderRadius: 12,
                                isPressed: true,
                                padding: EdgeInsets.zero,
                                child: Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'OUTSTANDING BALANCE',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${firstFee.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () {},
                                child: NeuBox(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  borderRadius: 12,
                                  color: AppColors.accent,
                                  child: const Text(
                                    'SETTLE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: AppColors.accent,
        letterSpacing: 1.5,
      ),
    );
  }
}
