import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/fee/fee_bloc.dart';
import '../blocs/fee/fee_event.dart';
import '../blocs/notification/notification_bloc.dart';
import '../blocs/notification/notification_event.dart';
import '../blocs/notification/notification_state.dart';
import '../blocs/student/student_bloc.dart';
import '../blocs/student/student_event.dart';
import '../blocs/theme/theme_bloc.dart';
import '../blocs/theme/theme_event.dart';
import '../blocs/theme/theme_state.dart';
import '../repositories/auth_repository.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';
import '../services/parent_activity_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/neu_box.dart';
import 'attendance/attendance_screen.dart';
import 'fees/fees_screen.dart';
import 'home/dashboard_screen.dart';
import 'login_screen.dart';
import 'marks/marks_screen.dart';
import 'reports/ireports_screen.dart';
import 'profile/profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<StudentBloc>().add(LoadStudentData());
    context.read<FeeBloc>().add(LoadFeeData());
    // Load current month attendance so dashboard can show today's record
    final now = DateTime.now();
    context.read<StudentBloc>().add(
      LoadAttendance(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
      ),
    );
    _initNotifications();
    
    // Initialize parent activity tracking
    context.read<ParentActivityService>().trackDailyAppOpen();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initNotifications() async {
    final repo = context.read<NotificationRepository>();
    // Initialize FCM, request permissions, save token
    await NotificationService.instance.initialize(repo);
    if (!mounted) return;
    // Load existing notifications then subscribe to realtime updates
    context.read<NotificationBloc>()
      ..add(LoadNotifications())
      ..add(StartNotificationStream());
  }

  final List<Widget> _screens = const [
    DashboardScreen(),
    MarksScreen(),
    AttendanceScreen(),
    FeesScreen(),
    IReportsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      },
      child: AppBackground(
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: Colors.transparent,
          drawer: SizedBox(
            width: MediaQuery.of(context).size.width * 2 / 3,
            child: _buildDrawer(context),
          ),
          body: IndexedStack(index: _currentIndex, children: _screens),
          bottomNavigationBar: BlocBuilder<NotificationBloc, NotificationState>(
            builder: (context, notifState) {
              final unread = notifState.unreadCount;
              final unreadAttendance = notifState.notifications
                  .where((n) => !n.isRead && n.type == 'attendance')
                  .length;
              final unreadReports = notifState.notifications
                  .where((n) => !n.isRead && (n.type == 'reports' || n.type == 'report_card'))
                  .length;
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                decoration: const BoxDecoration(color: Colors.transparent),
                child: NeuBox(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  borderRadius: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(LucideIcons.home, 'Home', 0, badgeCount: unread),
                      _buildNavItem(LucideIcons.bookOpen, 'Marks', 1),
                      _buildNavItem(LucideIcons.calendar, 'Attendance', 2, badgeCount: unreadAttendance),
                      _buildNavItem(LucideIcons.creditCard, 'Fees', 3),
                      _buildNavItem(LucideIcons.clipboardList, 'Reports', 4, badgeCount: unreadReports),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const NeuBox(
                      width: 60,
                      height: 60,
                      borderRadius: 15,
                      child: Icon(
                        Icons.admin_panel_settings,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ATOMUS',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ListTile(
            //   leading: const Icon(
            //     Icons.person_add_alt_1_rounded,
            //     color: AppColors.primary,
            //   ),
            //   title: const Text(
            //     'Create New Parent',
            //     style: TextStyle(fontWeight: FontWeight.w700),
            //   ),
            //   onTap: () {
            //     Navigator.pop(context);
            //     _showCreateParentDialog(context);
            //   },
            // ),

            // const Padding(
            //   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            //   child: Divider(),
            // ),

            // Appearance section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'APPEARANCE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, themeState) {
                  final isDark = themeState.themeMode == ThemeMode.dark;
                  return Row(
                    children: [
                      Expanded(
                        child: NeuBox(
                          isPressed: !isDark,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onTap: () {
                            if (isDark) {
                              context.read<ThemeBloc>().add(ToggleTheme());
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.light_mode_rounded,
                                size: 18,
                                color: !isDark
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'LIGHT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: !isDark
                                      ? AppColors.accent
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NeuBox(
                          isPressed: isDark,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onTap: () {
                            if (!isDark) {
                              context.read<ThemeBloc>().add(ToggleTheme());
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.dark_mode_rounded,
                                size: 18,
                                color: isDark
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'DARK',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),

            // Academic Performance section
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            //   child: Align(
            //     alignment: Alignment.centerLeft,
            //     child: Text(
            //       'ACADEMIC PERFORMANCE',
            //       style: TextStyle(
            //         color: AppColors.textSecondary,
            //         fontSize: 10,
            //         fontWeight: FontWeight.w900,
            //         letterSpacing: 1.5,
            //       ),
            //     ),
            //   ),
            // ),
            // BlocBuilder<StudentBloc, StudentState>(
            //   builder: (context, state) {
            //     if (state.status == StudentStatus.loading ||
            //         state.studentInfo == null) {
            //       return const Padding(
            //         padding: EdgeInsets.all(16),
            //         child: LinearProgressIndicator(),
            //       );
            //     }

            //     final performance = state.performance;
            //     final attendancePct = performance != null
            //         ? performance.attendancePercentage / 100.0
            //         : state.studentInfo!.attendancePercentage / 100.0;

            //     double totalObtained = 0;
            //     double totalPossible = 0;
            //     for (final exam in state.exams) {
            //       for (final subject in exam.subjects) {
            //         totalObtained += subject.marksObtained;
            //         totalPossible += subject.totalMarks;
            //       }
            //     }
            //     final marksPct = performance != null
            //         ? performance.marksPercentage / 100.0
            //         : (totalPossible > 0 ? totalObtained / totalPossible : 0.0);

            //     final overallPct = performance != null
            //         ? performance.academicPerformanceScore / 100.0
            //         : (state.exams.isEmpty
            //               ? attendancePct
            //               : marksPct * 0.7 + attendancePct * 0.3);

            //     return Padding(
            //       padding: const EdgeInsets.symmetric(
            //         horizontal: 16,
            //         vertical: 4,
            //       ),
            //       child: CustomCard(
            //         padding: const EdgeInsets.all(16),
            //         child: Column(
            //           crossAxisAlignment: CrossAxisAlignment.start,
            //           children: [
            //             _buildPerformanceBar(
            //               context,
            //               'Overall',
            //               overallPct,
            //               _performanceColor(overallPct),
            //             ),
            //             const SizedBox(height: 12),
            //             _buildPerformanceBar(
            //               context,
            //               'Attendance',
            //               attendancePct,
            //               AppColors.success,
            //             ),
            //             const SizedBox(height: 12),
            //             _buildPerformanceBar(
            //               context,
            //               'Marks',
            //               marksPct,
            //               AppColors.info,
            //             ),
            //           ],
            //         ),
            //       ),
            //     );
            //   },
            // ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'v1.0.0',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _performanceColor(double value) {
    if (value >= 0.8) return AppColors.success;
    if (value >= 0.6) return AppColors.info;
    if (value >= 0.4) return AppColors.warning;
    return AppColors.error;
  }

  Widget _buildPerformanceBar(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    final pct = (value * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  void _showCreateParentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CreateParentDialog(),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary.withOpacity(0.5),
                  size: 20,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary.withOpacity(0.5),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateParentDialog extends StatefulWidget {
  const _CreateParentDialog();

  @override
  State<_CreateParentDialog> createState() => _CreateParentDialogState();
}

class _CreateParentDialogState extends State<_CreateParentDialog> {
  late final TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Parent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Enter the parent email address to generate credentials.'),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            enabled: !_isLoading,
          ),
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
      actions: _isLoading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Add Parent'),
              ),
            ],
    );
  }

  void _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authRepo = context.read<AuthRepository>();
      final result = await authRepo.createParentWithEmail(email);

      if (mounted) {
        Navigator.pop(context); // Close create dialog

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Parent Created Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share these credentials with the parent:'),
                const SizedBox(height: 16),
                SelectableText('Email: ${result['email']}'),
                SelectableText('Password: ${result['password']}'),
                const SizedBox(height: 8),
                const Text(
                  'Note: Copy these now, they won\'t be shown again.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
