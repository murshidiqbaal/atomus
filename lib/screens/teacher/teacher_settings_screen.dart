import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/neu_box.dart';

class TeacherSettingsScreen extends StatelessWidget {
  const TeacherSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Top Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            LucideIcons.arrowLeft,
                            size: 18,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Settings',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Settings Body
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildAppearanceSection(context, isDark),
                    const SizedBox(height: 14),
                    _buildAccountSection(context),
                    const SizedBox(height: 14),
                    _buildAboutSection(context),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────── Appearance ────────────────
  Widget _buildAppearanceSection(BuildContext context, bool isDark) {
    return NeuBox(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(LucideIcons.palette, 'APPEARANCE'),
          const SizedBox(height: 16),
          BlocBuilder<ThemeBloc, ThemeState>(
            builder: (ctx, themeState) {
              return Column(
                children: [
                  _ThemeOptionTile(
                    icon: LucideIcons.sun,
                    label: 'Light Mode',
                    subtitle: 'Neumorphic design',
                    isActive: themeState.themeMode == ThemeMode.light,
                    onTap: () => context
                        .read<ThemeBloc>()
                        .add(const SetThemeMode(ThemeMode.light)),
                    activeColor: AppColors.accent,
                  ),
                  const SizedBox(height: 8),
                  _ThemeOptionTile(
                    icon: LucideIcons.moon,
                    label: 'Dark Mode',
                    subtitle: 'Glassmorphic design',
                    isActive: themeState.themeMode == ThemeMode.dark,
                    onTap: () => context
                        .read<ThemeBloc>()
                        .add(const SetThemeMode(ThemeMode.dark)),
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  _ThemeOptionTile(
                    icon: LucideIcons.monitor,
                    label: 'System Default',
                    subtitle: 'Follow device theme',
                    isActive: themeState.themeMode == ThemeMode.system,
                    onTap: () => context
                        .read<ThemeBloc>()
                        .add(const SetThemeMode(ThemeMode.system)),
                    activeColor: AppColors.info,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ──────────────── Account Section ────────────────
  Widget _buildAccountSection(BuildContext context) {
    return NeuBox(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(LucideIcons.user, 'ACCOUNT'),
          const SizedBox(height: 14),
          BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
            builder: (ctx, state) {
              final teacher = state.teacher;
              return Column(
                children: [
                  _InfoRow(
                    icon: LucideIcons.mail,
                    label: 'Email',
                    value: teacher?.email ?? '—',
                  ),
                  _InfoRow(
                    icon: LucideIcons.building2,
                    label: 'Campus',
                    value: teacher?.campusName ?? '—',
                  ),
                  _InfoRow(
                    icon: LucideIcons.bookOpen,
                    label: 'Subjects',
                    value: '${teacher?.subjects.length ?? 0} assigned',
                  ),
                  _InfoRow(
                    icon: LucideIcons.shield,
                    label: 'Geofence',
                    value: teacher?.hasCampusCoordinates == true
                        ? '${teacher!.geofenceRadiusMeters}m radius'
                        : 'Not configured',
                    isLast: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ──────────────── About ────────────────
  Widget _buildAboutSection(BuildContext context) {
    return NeuBox(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(LucideIcons.info, 'ABOUT'),
          const SizedBox(height: 14),
          _InfoRow(
            icon: LucideIcons.code2,
            label: 'App Version',
            value: '2.0.0 (Flutter)',
          ),
          _InfoRow(
            icon: LucideIcons.database,
            label: 'Backend',
            value: 'Supabase',
          ),
          _InfoRow(
            icon: LucideIcons.cpu,
            label: 'Architecture',
            value: 'BLoC + Repository',
          ),
          _InfoRow(
            icon: LucideIcons.heart,
            label: 'Built with',
            value: 'Flutter & Dart 3',
            isLast: true,
          ),
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.accent.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Atomus',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Teachers Portal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Helpers ────────────────
  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Sub-Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.25)
                : AppColors.textSecondary.withValues(alpha: 0.08),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor.withValues(alpha: 0.12)
                    : AppColors.textSecondary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isActive ? activeColor : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isActive ? activeColor : null,
                      )),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      )),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? activeColor
                    : AppColors.textSecondary.withValues(alpha: 0.1),
                border: Border.all(
                  color: isActive
                      ? activeColor
                      : AppColors.textSecondary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: isActive
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Text('$label',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            color: AppColors.textSecondary.withValues(alpha: 0.06),
            height: 2,
          ),
      ],
    );
  }
}
