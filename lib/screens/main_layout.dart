import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../blocs/fee/fee_bloc.dart';
import '../blocs/fee/fee_event.dart';
import '../blocs/student/student_bloc.dart';
import '../blocs/student/student_event.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
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
                      child: Icon(Icons.admin_panel_settings, color: AppColors.primary),
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
              leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
              title: const Text('Create New Parent', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(context);
                _showCreateParentDialog(context);
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

  void _showCreateParentDialog(BuildContext context) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Parent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the parent email address to generate credentials.'),
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

              Navigator.pop(context); // Close input dialog
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                final authRepo = context.read<AuthRepository>();
                final result = await authRepo.createParentWithEmail(email);
                
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  
                  // Show success dialog with credentials
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
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
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
