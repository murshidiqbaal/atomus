import 'package:atomus/blocs/student/student_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/announcement/announcement_bloc.dart';
import '../../blocs/announcement/announcement_state.dart';
import '../../blocs/fee/fee_bloc.dart';
import '../../blocs/fee/fee_state.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/announcement_popup.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/status_badge.dart';
import '../progress/progress_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch the specific student linked to this logged-in parent
    context.read<StudentBloc>().add(LoadStudentData());
  }

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
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ... existing content ...
                        // Premium Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                NeuBox(
                                  width: 50,
                                  height: 50,
                                  borderRadius: 12,
                                  padding: EdgeInsets.zero,
                                  onTap: () =>
                                      Scaffold.of(context).openDrawer(),
                                  child: const Center(
                                    child: Icon(
                                      Icons.menu_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Column(
                                //   crossAxisAlignment: CrossAxisAlignment.start,
                                //   children: [
                                //     Text(
                                //       'ESTEEMED PARENT',
                                //       style: Theme.of(context)
                                //           .textTheme
                                //           .labelLarge
                                //           ?.copyWith(
                                //             color: AppColors.accent,
                                //             letterSpacing: 2.5,
                                //             fontWeight: FontWeight.w800,
                                //           ),
                                //     ),
                                //     const SizedBox(height: 4),
                                //     // Text(
                                //     //   'Welcome Back',
                                //     //   style: Theme.of(context)
                                //     //       .textTheme
                                //     //       .headlineMedium
                                //     //       ?.copyWith(
                                //     //         color: Theme.of(
                                //     //           context,
                                //     //         ).primaryColor,
                                //     //       ),
                                //     // ),
                                //   ],
                                // ),
                              ],
                            ),
                            Row(
                              children: [
                                BlocBuilder<
                                  AnnouncementBloc,
                                  AnnouncementState
                                >(
                                  builder: (context, state) {
                                    return Stack(
                                      children: [
                                        NeuBox(
                                          width: 50,
                                          height: 50,
                                          borderRadius: 12,
                                          padding: EdgeInsets.zero,
                                          onTap: () =>
                                              _showAnnouncementsBottomSheet(
                                                context,
                                                state,
                                              ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.notifications_none_rounded,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        if (state.announcements.isNotEmpty)
                                          Positioned(
                                            right: 12,
                                            top: 12,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                BlocBuilder<ThemeBloc, ThemeState>(
                                  builder: (context, themeState) {
                                    final isDark =
                                        themeState.themeMode == ThemeMode.dark;
                                    return NeuBox(
                                      width: 50,
                                      height: 50,
                                      borderRadius: 12,
                                      padding: EdgeInsets.zero,
                                      onTap: () => context
                                          .read<ThemeBloc>()
                                          .add(ToggleTheme()),
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
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Student Profile Card
                        CustomCard(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              // Circular Progress Indicator
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 100,
                                      height: 100,
                                      child: CircularProgressIndicator(
                                        value: student.overallProgress,
                                        strokeWidth: 10,
                                        backgroundColor: AppColors.primary
                                            .withOpacity(0.1),
                                        color: AppColors.primary,
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${(student.overallProgress * 100).toInt()}%',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 24,
                                              ),
                                        ),
                                        Text(
                                          'Overall',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Status Information
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ProgressScreen(),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Academic Performance',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (student.overallProgress >= 0.8
                                                      ? AppColors.success
                                                      : student.overallProgress >=
                                                            0.6
                                                      ? AppColors.info
                                                      : student.overallProgress >=
                                                            0.4
                                                      ? AppColors.warning
                                                      : AppColors.error)
                                                  .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          student.overallProgress >= 0.8
                                              ? 'Excellent'
                                              : student.overallProgress >= 0.6
                                              ? 'Good'
                                              : student.overallProgress >= 0.4
                                              ? 'Average'
                                              : 'Needs Attention',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    student.overallProgress >=
                                                        0.8
                                                    ? AppColors.success
                                                    : student.overallProgress >=
                                                          0.6
                                                    ? AppColors.info
                                                    : student.overallProgress >=
                                                          0.4
                                                    ? AppColors.warning
                                                    : AppColors.error,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        student.overallProgress >= 0.8
                                            ? 'Outstanding academic record.'
                                            : student.overallProgress >= 0.6
                                            ? 'On track with steady progress.'
                                            : 'Requires additional support.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // const SizedBox(height: 32),

                        // Announcement Section
                        // _buildSectionHeader(context, 'Announcements'),
                        const SizedBox(height: 16),
                        BlocBuilder<AnnouncementBloc, AnnouncementState>(
                          builder: (context, announcementState) {
                            if (announcementState.status ==
                                AnnouncementStatus.loading) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (announcementState.announcements.isEmpty) {
                              return const SizedBox();
                            }
                            return SizedBox(
                              height: 160,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount:
                                    announcementState.announcements.length,
                                clipBehavior: Clip.none,
                                itemBuilder: (context, index) {
                                  final announcement =
                                      announcementState.announcements[index];
                                  return Container(
                                    width: 280,
                                    margin: const EdgeInsets.only(right: 16),
                                    child: CustomCard(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.campaign_rounded,
                                                color: AppColors.accent,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  announcement.title
                                                      .toUpperCase(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 12,
                                                    letterSpacing: 0.5,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Expanded(
                                            child: Text(
                                              announcement.description,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        Theme.of(
                                                              context,
                                                            ).brightness ==
                                                            Brightness.dark
                                                        ? AppColors
                                                              .textSecondaryDark
                                                        : AppColors
                                                              .textSecondary,
                                                    height: 1.4,
                                                  ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            '${announcement.date.day}/${announcement.date.month}/${announcement.date.year}',
                                            style: TextStyle(
                                              color: AppColors.accent
                                                  .withOpacity(0.7),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),

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
                                      Icons.insights_rounded,
                                      color: AppColors.accent,
                                      size: 28,
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'MARKS',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                              return const Center(
                                child: LinearProgressIndicator(),
                              );
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
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
                  // Announcement Popup Overlay
                  BlocBuilder<AnnouncementBloc, AnnouncementState>(
                    builder: (context, state) {
                      if (state.currentAnnouncement != null) {
                        return AnnouncementPopup(
                          key: ValueKey(state.currentAnnouncement!.id),
                          announcement: state.currentAnnouncement!,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAnnouncementsBottomSheet(
    BuildContext context,
    AnnouncementState state,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'ANNOUNCEMENTS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: state.announcements.isEmpty
                  ? const Center(child: Text('No announcements at this time.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: state.announcements.length,
                      itemBuilder: (context, index) {
                        final announcement = state.announcements[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: CustomCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.campaign,
                                      color: AppColors.accent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        announcement.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  announcement.description,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${announcement.date.day}/${announcement.date.month}/${announcement.date.year}',
                                  style: TextStyle(
                                    color: AppColors.accent.withOpacity(0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
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
        ),
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
