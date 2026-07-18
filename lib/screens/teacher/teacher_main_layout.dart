import 'package:atomus/screens/teacher/student_attendance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart' show Provider;

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../blocs/profile/teacher_profile_cubit.dart';
import '../../blocs/profile/teacher_profile_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../blocs/teacher_attendance/teacher_attendance_cubit.dart';
import '../../models/campus_model.dart';
import '../../providers/campus_provider.dart';
import '../../repositories/notification_repository.dart';
import '../../services/auto_sync_manager.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';
import '../login_screen.dart';
import 'marks_entry_screen.dart';
import 'parent_daily_activity_screen.dart';
import 'teacher_attendance_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'teacher_profile_screen.dart';
import 'teacher_reports_screen.dart';

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
  String? _lastCampusId;

  // Screens are stateless — use IndexedStack to preserve state across tab switches.
  final List<Widget> _screens = const [
    TeacherDashboardScreen(),
    TeacherAttendanceScreen(),
    StudentAttendanceScreen(subjectId: '', subjectName: '', batchId: ''),
    MarksEntryScreen(),
    TeacherReportsScreen(),
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
      _initNotifications();
      _navBarController.forward();
    });
  }

  Future<void> _initNotifications() async {
    if (!mounted) return;
    try {
      final repo = context.read<NotificationRepository>();
      await NotificationService.instance.initialize(repo);
      debugPrint('TeacherMainLayout: Push Notifications initialized.');
    } catch (e) {
      debugPrint('TeacherMainLayout: Failed to initialize notifications: $e');
    }
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

  Widget _buildTeacherDrawer(BuildContext context) {
    final campusProvider = Provider.of<CampusProvider>(context);
    final assignedCampuses = campusProvider.assignedCampuses;
    final activeCampus =
        campusProvider.selectedCampus ?? campusProvider.workingCampus;

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
                        Icons.admin_panel_settings_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ATOMUS PORTAL',
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
            if (assignedCampuses.length > 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'CURRENT CAMPUS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Campus>(
                    value:
                        activeCampus != null &&
                            assignedCampuses.any((c) => c.id == activeCampus.id)
                        ? assignedCampuses.firstWhere(
                            (c) => c.id == activeCampus.id,
                          )
                        : null,
                    hint: const Text(
                      'Select Campus',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.primary,
                    ),
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                    dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    items: assignedCampuses.map((Campus campus) {
                      return DropdownMenuItem<Campus>(
                        value: campus,
                        child: Text(campus.name),
                      );
                    }).toList(),
                    onChanged: (Campus? newValue) {
                      if (newValue != null) {
                        campusProvider.selectCampus(newValue);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ANALYTICS',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.analytics_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Parent Daily Activity',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ParentDailyActivityScreen(),
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

  @override
  Widget build(BuildContext context) {
    // All providers (TeacherHiveService, repositories, cubits) are available
    // from the global AppProviders tree. No local provider wrappers needed here.
    final campusProvider = Provider.of<CampusProvider>(context);
    final currentCampusId =
        campusProvider.selectedCampus?.id ?? campusProvider.workingCampus?.id;

    if (currentCampusId != null && currentCampusId != _lastCampusId) {
      _lastCampusId = currentCampusId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshCampusSpecificData(currentCampusId);
      });
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) {
          campusProvider.clear();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      },
      child: BlocListener<TeacherProfileCubit, TeacherProfileState>(
        listener: (context, profileState) {
          final teacher = profileState.teacher;
          if (teacher != null) {
            campusProvider.loadAssignedCampuses(teacher.assignedCampuses);
          }
        },
        child: AppBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            drawer: SizedBox(
              width: MediaQuery.of(context).size.width * 2 / 3,
              child: _buildTeacherDrawer(context),
            ),
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
            floatingActionButton: _currentIndex == 0
                ? FloatingActionButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _currentIndex = 4);
                    },
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 6,
                    child: const Icon(LucideIcons.clipboardList, size: 24),
                  )
                : null,
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
        ),
      ),
    );
  }

  void _refreshCampusSpecificData(String campusId) {
    if (!mounted) return;
    final teacher = context.read<TeacherDashboardCubit>().state.teacher;
    if (teacher == null) return;

    // 1. Refresh Dashboard (queries stats and upcoming exams)
    context.read<TeacherDashboardCubit>().load();

    // 2. Refresh Teacher Attendance today session
    final sessionType = DateTime.now().hour >= 13 ? 'afternoon' : 'forenoon';
    context.read<TeacherAttendanceCubit>().loadTodaySession(
      teacher.id,
      sessionType: sessionType,
    );
    context.read<TeacherAttendanceCubit>().loadHistory(teacher.id);
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
