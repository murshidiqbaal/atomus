import 'package:atomus/blocs/student/student_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/announcement/announcement_bloc.dart';
import '../../blocs/announcement/announcement_state.dart';
import '../../blocs/announcement/announcement_event.dart';
import '../../blocs/course/course_bloc.dart';
import '../../blocs/course/course_state.dart';
import '../../blocs/fee/fee_bloc.dart';
import '../../blocs/fee/fee_state.dart';
import '../../blocs/fee/fee_event.dart';
import '../../blocs/notification/notification_bloc.dart';
import '../../blocs/notification/notification_state.dart';
import '../../blocs/notification/notification_event.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/announcement_popup.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/drive_network_image.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/marquee_widget.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/status_badge.dart';
import '../course/course_detail_screen.dart';
import '../notifications/notification_screen.dart';
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
    context.read<StudentBloc>().add(LoadStudentData());
  }

  Future<void> _handleRefresh() async {
    final studentBloc = context.read<StudentBloc>();
    final feeBloc = context.read<FeeBloc>();
    final announcementBloc = context.read<AnnouncementBloc>();
    final notificationBloc = context.read<NotificationBloc>();

    studentBloc.add(LoadStudentData());
    feeBloc.add(LoadFeeData());
    announcementBloc.add(LoadAnnouncements());
    notificationBloc.add(LoadNotifications());

    final now = DateTime.now();
    studentBloc.add(
      LoadAttendance(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      ),
    );

    await Future.wait([
      studentBloc.stream
          .firstWhere((s) => s.status != StudentStatus.loading)
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => studentBloc.state,
          ),
      feeBloc.stream
          .firstWhere((s) => s.status != FeeStatus.loading)
          .timeout(const Duration(seconds: 4), onTimeout: () => feeBloc.state),
    ]);
  }

  double _computeAcademicPerformance(StudentState state) {
    final attendancePct =
        (state.studentInfo?.attendancePercentage ?? 0.0) / 100.0;
    double totalObtained = 0;
    double totalPossible = 0;
    for (final exam in state.exams) {
      for (final subject in exam.subjects) {
        totalObtained += subject.marksObtained;
        totalPossible += subject.totalMarks;
      }
    }
    final marksPct = totalPossible > 0 ? totalObtained / totalPossible : 0.0;
    if (state.exams.isEmpty) return attendancePct;
    return marksPct * 0.7 + attendancePct * 0.3;
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

          final performance = state.performance;
          final double academicPerformance = performance != null
              ? performance.academicPerformance / 100.0
              : _computeAcademicPerformance(state);
          final double attendancePercentage = performance != null
              ? performance.attendancePercentage
              : student.attendancePercentage;
          final double marksPercentage = performance != null
              ? performance.marksPercentage
              : academicPerformance * 100.0;
          final String statusLabel = performance != null
              ? performance.progressStatus
              : (academicPerformance >= 0.8
                    ? 'Excellent'
                    : academicPerformance >= 0.6
                    ? 'Good'
                    : academicPerformance >= 0.4
                    ? 'Average'
                    : 'Needs Attention');
          final Color progressColor = performance != null
              ? performance.progressColor
              : (academicPerformance >= 0.8
                    ? AppColors.success
                    : academicPerformance >= 0.6
                    ? AppColors.info
                    : academicPerformance >= 0.4
                    ? AppColors.warning
                    : AppColors.error);

          // Find today's attendance record
          final today = DateTime.now();
          final todayAttendance = state.attendance.where(
            (r) =>
                r.date.year == today.year &&
                r.date.month == today.month &&
                r.date.day == today.day,
          );
          final todayRecord = todayAttendance.isNotEmpty
              ? todayAttendance.first
              : null;

          return GlassBackground(
            child: SafeArea(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: AppColors.primary,
                    onRefresh: _handleRefresh,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header — menu + notifications only (theme toggle moved to drawer)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              NeuBox(
                                width: 50,
                                height: 50,
                                borderRadius: 12,
                                padding: EdgeInsets.zero,
                                onTap: () => Scaffold.of(context).openDrawer(),
                                child: const Center(
                                  child: Icon(
                                    Icons.menu_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              BlocBuilder<NotificationBloc, NotificationState>(
                                builder: (context, notifState) {
                                  final unread = notifState.unreadCount;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      NeuBox(
                                        width: 50,
                                        height: 50,
                                        borderRadius: 12,
                                        padding: EdgeInsets.zero,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const NotificationScreen(),
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.notifications_none_rounded,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      if (unread > 0)
                                        Positioned(
                                          right: 4,
                                          top: 4,
                                          child: Container(
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: AppColors.error,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                unread > 99 ? '99+' : '$unread',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Student Profile Card
                          CustomCard(
                            padding: const EdgeInsets.all(24),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ProgressScreen(),
                                ),
                              );
                            },
                            child: Row(
                              children: [
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
                                          value: academicPerformance,
                                          strokeWidth: 10,
                                          backgroundColor: AppColors.primary
                                              .withOpacity(0.1),
                                          color: progressColor,
                                          strokeCap: StrokeCap.round,
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${(academicPerformance * 100).toInt()}%',
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
                                Expanded(
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
                                          color: progressColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: progressColor,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        statusLabel == 'Excellent'
                                            ? 'Outstanding academic record.'
                                            : statusLabel == 'Good'
                                            ? 'On track with steady progress.'
                                            : statusLabel == 'Average'
                                            ? 'Consistent performance.'
                                            : statusLabel == 'Needs Improvement'
                                            ? 'Requires additional support.'
                                            : 'Immediate intervention required.',
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
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),
                          _buildCourseMarquee(context),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
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
                                            '${marksPercentage.toInt()}',
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
                                          marksPercentage / 100.0,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
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
                                            '${attendancePercentage.toInt()}',
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
                                          attendancePercentage / 100.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Recent Evaluations
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader(
                                context,
                                'Recent Evaluations',
                              ),
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

                          // Today's attendance card
                          _buildTodayAttendanceCard(context, todayRecord),
                          const SizedBox(height: 12),

                          // Latest exam marks card
                          if (state.exams.isNotEmpty) ...[
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .primaryColor
                                                      .withOpacity(0.05),
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
                          ] else ...[
                            const CustomCard(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.assignment_late_outlined,
                                      color: AppColors.textSecondary,
                                      size: 32,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'No recent evaluations found.',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                              if (feeState.fees.isEmpty) {
                                return const SizedBox();
                              }

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
                                      child: const Icon(
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
                        ],
                      ),
                    ),
                  ),
                  // Announcement Popup Overlay
                  BlocBuilder<AnnouncementBloc, AnnouncementState>(
                    builder: (context, announcementState) {
                      if (announcementState.currentAnnouncement != null) {
                        return AnnouncementPopup(
                          key: ValueKey(
                            announcementState.currentAnnouncement!.id,
                          ),
                          announcement: announcementState.currentAnnouncement!,
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

  Widget _buildCourseMarquee(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'EXPLORE COURSES',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        BlocBuilder<CourseBloc, CourseState>(
          builder: (context, state) {
            if (state.status == CourseStatus.loading) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state.courses.isEmpty) {
              return const SizedBox();
            }

            return SizedBox(
              height: 180,
              child: MarqueeWidget(
                scrollSpeed: 30,
                children: state.courses.map((course) {
                  return Container(
                    width: 280,
                    margin: const EdgeInsets.only(right: 24),
                    child: GestureDetector(
                      onDoubleTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                CourseDetailScreen(course: course),
                          ),
                        );
                      },
                      child: CustomCard(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              // Background Image
                              Positioned.fill(
                                child: DriveNetworkImage(
                                  driveId: course.thumbnailDriveId,
                                  fit: BoxFit.cover,
                                  placeholderType: DrivePlaceholderType.banner,
                                  alt: '${course.name} thumbnail',
                                ),
                              ),

                              // Overlay Gradient for readability
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.8),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Content
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        course.courseType.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 9,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      course.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.layers_outlined,
                                          color: Colors.white70,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          course.classLevel ?? 'All Levels',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodayAttendanceCard(BuildContext context, dynamic todayRecord) {
    final today = DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(today).toUpperCase();

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (todayRecord == null) {
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.schedule_rounded;
      statusLabel = 'NOT MARKED YET';
    } else {
      switch (todayRecord.status) {
        case 'Present':
          statusColor = AppColors.success;
          statusIcon = Icons.verified_rounded;
          statusLabel = 'PRESENT';
          break;
        case 'Absent':
          statusColor = AppColors.error;
          statusIcon = Icons.do_not_disturb_on_rounded;
          statusLabel = 'ABSENT';
          break;
        case 'Late':
          statusColor = AppColors.warning;
          statusIcon = Icons.watch_later_rounded;
          statusLabel = 'LATE';
          break;
        default:
          statusColor = AppColors.textSecondary;
          statusIcon = Icons.schedule_rounded;
          statusLabel = todayRecord.status.toUpperCase();
      }
    }

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY\'S ATTENDANCE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
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
