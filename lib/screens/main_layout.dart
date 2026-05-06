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

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

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
        backgroundColor: Colors.transparent,
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
