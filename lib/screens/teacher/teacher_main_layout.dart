import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../services/auto_sync_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';
import 'marks_entry_screen.dart';
import 'student_attendance_tab.dart';
import 'teacher_analytics_screen.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_profile_screen.dart';

class TeacherMainLayout extends StatefulWidget {
  const TeacherMainLayout({super.key});

  @override
  State<TeacherMainLayout> createState() => _TeacherMainLayoutState();
}

class _TeacherMainLayoutState extends State<TeacherMainLayout>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _navBarController;
  late final Animation<double> _navBarSlide;

  // Screens are stateless — use IndexedStack to preserve state across tab switches.
  final List<Widget> _screens = const [
    TeacherDashboardScreen(),
    TeacherAttendanceScreen(),
    StudentAttendanceTab(),
    MarksEntryScreen(),
    TeacherAnalyticsScreen(),
    TeacherProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _navBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _navBarSlide = CurvedAnimation(
      parent: _navBarController,
      curve: Curves.easeOutCubic,
    );

    // Defer all context-dependent work until AFTER the first frame is rendered.
    // This guarantees the full provider tree (AppProviders) is mounted and accessible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoSync();
      _navBarController.forward();
    });
  }

  /// Starts the AutoSyncManager after the widget tree is fully mounted.
  /// Uses Provider.of with listen: false — safe for one-time reads outside build().
  void _startAutoSync() {
    if (!mounted) return;
    try {
      final syncManager = context.read<AutoSyncManager>();
      syncManager.start();
      debugPrint('TeacherMainLayout: AutoSyncManager started.');
    } catch (e) {
      debugPrint('TeacherMainLayout: Failed to start AutoSyncManager: $e');
    }
  }

  void _onTabChanged(int index) {
    if (index == _currentIndex) return;

    // Haptic tap feedback for premium feel
    HapticFeedback.selectionClick();

    setState(() => _currentIndex = index);
  }

  @override
  void dispose() {
    // Stop the auto-sync stream when the teacher leaves this layout.
    if (mounted) {
      try {
        context.read<AutoSyncManager>().stop();
      } catch (_) {
        // Swallow errors during dispose — widget may be partially unmounted.
      }
    }
    _navBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // All providers (TeacherHiveService, repositories, cubits) are available
    // from the global AppProviders tree. No local provider wrappers needed here.
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: KeyedSubtree(
            key: ValueKey(_currentIndex),
            child: IndexedStack(index: _currentIndex, children: _screens),
          ),
        ),
        bottomNavigationBar: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(_navBarSlide),
          child: _BottomNavBar(
            currentIndex: _currentIndex,
            onTabChanged: _onTabChanged,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const _BottomNavBar({required this.currentIndex, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
      builder: (ctx, dashState) {
        final hasPendingMarks = dashState.stats.pendingMarksCount > 0;

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.of(context).padding.bottom + 12,
          ),
          color: Colors.transparent,
          child: NeuBox(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            borderRadius: 26,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: LucideIcons.home,
                  label: 'Home',
                  index: 0,
                  currentIndex: currentIndex,
                  onTap: onTabChanged,
                  isDark: isDark,
                ),
                _NavItem(
                  icon: LucideIcons.userCheck,
                  label: 'My Attend',
                  index: 1,
                  currentIndex: currentIndex,
                  onTap: onTabChanged,
                  isDark: isDark,
                ),
                _NavItem(
                  icon: LucideIcons.users,
                  label: 'Std Attend',
                  index: 2,
                  currentIndex: currentIndex,
                  onTap: onTabChanged,
                  isDark: isDark,
                ),
                _NavItem(
                  icon: LucideIcons.penTool,
                  label: 'Marks',
                  index: 3,
                  currentIndex: currentIndex,
                  onTap: onTabChanged,
                  isDark: isDark,
                  hasBadge: hasPendingMarks,
                ),
                // _NavItem(
                //   icon: LucideIcons.barChart2,
                //   label: 'Analytics',
                //   index: 4,
                //   currentIndex: currentIndex,
                //   onTap: onTabChanged,
                //   isDark: isDark,
                // ),
                _NavItem(
                  icon: LucideIcons.user,
                  label: 'Profile',
                  index: 5,
                  currentIndex: currentIndex,
                  onTap: onTabChanged,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool hasBadge;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark
        ? AppColors.textSecondaryDark.withValues(alpha: 0.45)
        : AppColors.textSecondary.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.12 : 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 280),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                ),
                // Notification badge
                if (hasBadge)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : AppColors.neuBase,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 280),
              style: TextStyle(
                fontSize: isSelected ? 10 : 9,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
            // Active indicator dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(top: 3),
              width: isSelected ? 4 : 0,
              height: isSelected ? 4 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
