import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../services/auto_sync_manager.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';
import 'teacher_analytics_screen.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_profile_screen.dart';
import 'marks_entry_screen.dart';

class TeacherMainLayout extends StatefulWidget {
  const TeacherMainLayout({super.key});

  @override
  State<TeacherMainLayout> createState() => _TeacherMainLayoutState();
}

class _TeacherMainLayoutState extends State<TeacherMainLayout> {
  int _currentIndex = 0;

  // Screens are stateless — use IndexedStack to preserve state across tab switches.
  final List<Widget> _screens = const [
    TeacherDashboardScreen(),
    TeacherAttendanceScreen(),
    MarksEntryScreen(),
    TeacherAnalyticsScreen(),
    TeacherProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Defer all context-dependent work until AFTER the first frame is rendered.
    // This guarantees the full provider tree (AppProviders) is mounted and accessible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoSync();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // All providers (TeacherHiveService, repositories, cubits) are available
    // from the global AppProviders tree. No local provider wrappers needed here.
    return _TeacherScaffold(
      currentIndex: _currentIndex,
      screens: _screens,
      onTabChanged: (i) => setState(() => _currentIndex = i),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private scaffold widget — purely presentational, no provider access.
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherScaffold extends StatelessWidget {
  final int currentIndex;
  final List<Widget> screens;
  final ValueChanged<int> onTabChanged;

  const _TeacherScaffold({
    required this.currentIndex,
    required this.screens,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: currentIndex, children: screens),
        bottomNavigationBar: BlocBuilder<TeacherDashboardCubit,
            TeacherDashboardState>(
          builder: (ctx, dashState) {
            final hasPendingMarks =
                dashState.stats.pendingMarksCount > 0;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              color: Colors.transparent,
              child: NeuBox(
                padding: const EdgeInsets.symmetric(vertical: 8),
                borderRadius: 24,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navItem(context, LucideIcons.home, 'Home', 0),
                    _navItem(context, LucideIcons.mapPin, 'Attendance', 1),
                    _marksNavItem(context, hasPendingMarks),
                    _navItem(context, LucideIcons.barChart2, 'Analytics', 3),
                    _navItem(context, LucideIcons.user, 'Profile', 4),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _navItem(
      BuildContext context, IconData icon, String label, int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.5),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _marksNavItem(BuildContext context, bool hasBadge) {
    final isSelected = currentIndex == 2;
    return GestureDetector(
      onTap: () => onTabChanged(2),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.clipboardList,
                  size: 20,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Marks',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary.withValues(alpha: 0.5),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (hasBadge)
            Positioned(
              top: 4,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
