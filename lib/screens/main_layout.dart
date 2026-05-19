import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../blocs/fee/fee_bloc.dart';
import '../blocs/fee/fee_event.dart';
import '../blocs/notification/notification_bloc.dart';
import '../blocs/notification/notification_event.dart';
import '../blocs/student/student_bloc.dart';
import '../blocs/student/student_event.dart';
import '../blocs/student/student_state.dart';
import '../blocs/theme/theme_bloc.dart';
import '../blocs/theme/theme_event.dart';
import '../blocs/theme/theme_state.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/custom_card.dart';
import '../widgets/neu_box.dart';
import 'attendance/attendance_screen.dart';
import 'fees/fees_screen.dart';
import 'home/dashboard_screen.dart';
import 'marks/marks_screen.dart';
import 'profile/profile_screen.dart';
import '../repositories/auth_repository.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: _buildDrawer(context),
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: NeuBox(
            padding: const EdgeInsets.symmetric(vertical: 8),
            borderRadius: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(LucideIcons.home, 'Home', 0),
                _buildNavItem(LucideIcons.bookOpen, 'Marks', 1),
                _buildNavItem(LucideIcons.calendar, 'Attendance', 2),
                _buildNavItem(LucideIcons.creditCard, 'Fees', 3),
                _buildNavItem(LucideIcons.user, 'Profile', 4),
              ],
            ),
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
                      'ATOMUS ADMIN',
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

            ListTile(
              leading: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Create New Parent',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context);
                _showCreateParentDialog(context);
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),

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
            BlocBuilder<ThemeBloc, ThemeState>(
              builder: (context, themeState) {
                final isDark = themeState.themeMode == ThemeMode.dark;
                return ListTile(
                  leading: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isDark ? 'Light Mode' : 'Dark Mode',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) =>
                        context.read<ThemeBloc>().add(ToggleTheme()),
                    activeColor: AppColors.primary,
                  ),
                  onTap: () => context.read<ThemeBloc>().add(ToggleTheme()),
                );
              },
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),

            // Academic Performance section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ACADEMIC PERFORMANCE',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            BlocBuilder<StudentBloc, StudentState>(
              builder: (context, state) {
                if (state.status == StudentStatus.loading ||
                    state.studentInfo == null) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }

                final performance = state.performance;
                final attendancePct = performance != null
                    ? performance.attendancePercentage / 100.0
                    : state.studentInfo!.attendancePercentage / 100.0;

                double totalObtained = 0;
                double totalPossible = 0;
                for (final exam in state.exams) {
                  for (final subject in exam.subjects) {
                    totalObtained += subject.marksObtained;
                    totalPossible += subject.totalMarks;
                  }
                }
                final marksPct = performance != null
                    ? performance.marksPercentage / 100.0
                    : (totalPossible > 0 ? totalObtained / totalPossible : 0.0);

                final overallPct = performance != null
                    ? performance.academicPerformanceScore / 100.0
                    : (state.exams.isEmpty
                        ? attendancePct
                        : marksPct * 0.7 + attendancePct * 0.3);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: CustomCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPerformanceBar(
                          context,
                          'Overall',
                          overallPct,
                          _performanceColor(overallPct),
                        ),
                        const SizedBox(height: 12),
                        _buildPerformanceBar(
                          context,
                          'Attendance',
                          attendancePct,
                          AppColors.success,
                        ),
                        const SizedBox(height: 12),
                        _buildPerformanceBar(
                          context,
                          'Marks',
                          marksPct,
                          AppColors.info,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Parent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the parent email address to generate credentials.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email')),
                );
                return;
              }

              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final authRepo = context.read<AuthRepository>();
                final result = await authRepo.createParentWithEmail(email);

                if (context.mounted) {
                  Navigator.pop(context);

                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Parent Created Successfully'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Share these credentials with the parent:',
                          ),
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
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add Parent'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
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
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary.withOpacity(0.5),
              size: 20,
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
