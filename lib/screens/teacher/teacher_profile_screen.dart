import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_cubit.dart';
import '../../blocs/teacher_dashboard/teacher_dashboard_state.dart';
import '../../models/profile_models.dart';
import '../../models/teacher_model.dart';
import '../../services/google_drive_profile_upload_service.dart';
import '../../services/profile_image_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/drive_network_image.dart';
import '../../widgets/neu_box.dart';
import 'teacher_settings_screen.dart';

class TeacherProfileScreen extends StatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  State<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends State<TeacherProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  bool _isUploadingPhoto = false;
  String? _localPhotoPath;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(
      parent: _headerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerController,
            curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
          ),
        );
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  // ──────────────── Photo Upload ────────────────
  Future<void> _pickAndUploadPhoto() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final imageService = context.read<ProfileImageService>();
      final localPath = await imageService.pickAndPersistImage(
        source: source,
        filePrefix: 'teacher_profile',
      );
      if (localPath == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }
      setState(() => _localPhotoPath = localPath);

      // Upload to Google Drive via Edge Function
      final driveUploader = context.read<GoogleDriveProfileUploadService>();
      final teacher = context.read<TeacherDashboardCubit>().state.teacher;
      if (teacher == null) throw Exception('Teacher profile not loaded.');

      final driveId = await driveUploader.uploadProfileImage(
        target: ProfileUploadTarget.teacher,
        targetId: teacher.id,
        localPath: localPath,
      );

      // Update the teacher record in Supabase
      await Supabase.instance.client
          .from('teachers')
          .update({'profile_photo_drive_id': driveId})
          .eq('id', teacher.id);

      // Refresh dashboard to pick up the new photo
      if (mounted) {
        context.read<TeacherDashboardCubit>().refresh();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo updated!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Update Profile Photo',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SourceOption(
                      icon: LucideIcons.camera,
                      label: 'Camera',
                      color: AppColors.primary,
                      onTap: () => Navigator.pop(ctx, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SourceOption(
                      icon: LucideIcons.image,
                      label: 'Gallery',
                      color: AppColors.accent,
                      onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ──────────────── Build ────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
          builder: (ctx, state) {
            final teacher = state.teacher;
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Animated Header
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _headerSlide,
                    child: FadeTransition(
                      opacity: _headerFade,
                      child: _buildProfileHeader(context, teacher),
                    ),
                  ),
                ),
                // Body content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildContactCard(context, teacher),
                      const SizedBox(height: 14),
                      _buildAssignmentsCard(context, state),
                      const SizedBox(height: 14),
                      _buildQuickActionsCard(context),
                      const SizedBox(height: 24),
                      _buildLogoutButton(context),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ──────────────── Profile Header ────────────────
  Widget _buildProfileHeader(BuildContext context, TeacherModel? teacher) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          // Settings icon row
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => const TeacherSettingsScreen(),
                  transitionsBuilder: (_, animation, _, child) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.settings,
                  size: 18,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Avatar with gradient ring
          GestureDetector(
            onTap: _pickAndUploadPhoto,
            child: _buildAvatarWithRing(teacher, isDark),
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            teacher?.fullName ?? 'Teacher',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Employee ID badge
          if (teacher?.employeeId != null)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.badgeCheck,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'ID: ${teacher!.employeeId}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          // Campus badge
          if (teacher?.campusName != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  LucideIcons.mapPin,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  teacher!.campusName!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarWithRing(TeacherModel? teacher, bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Gradient ring
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                AppColors.primary,
                AppColors.accent,
                AppColors.success,
                AppColors.primary,
              ],
            ),
          ),
        ),
        // Inner white ring
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
          ),
        ),
        // Avatar image or initials
        SizedBox(
          width: 96,
          height: 96,
          child: ClipOval(child: _buildAvatarContent(teacher)),
        ),
        // Upload overlay
        if (_isUploadingPhoto)
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),
        // Camera badge
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF7C3AED)],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                width: 2.5,
              ),
            ),
            child: const Icon(
              LucideIcons.camera,
              color: Colors.white,
              size: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarContent(TeacherModel? teacher) {
    // If there's a local photo pending upload, show it immediately
    if (_localPhotoPath != null && File(_localPhotoPath!).existsSync()) {
      return Image.file(
        File(_localPhotoPath!),
        fit: BoxFit.cover,
        width: 96,
        height: 96,
      );
    }

    // If teacher has a Drive photo, show it
    final driveId = teacher?.profilePhotoDriveId;
    if (driveId != null && driveId.isNotEmpty) {
      return DriveNetworkImage(
        driveId: driveId,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        placeholderType: DrivePlaceholderType.avatar,
        initials: teacher?.fullName,
        imageWidth: 256,
      );
    }

    // Fallback: initials
    final name = teacher?.fullName ?? 'T';
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : name.isNotEmpty
        ? name[0].toUpperCase()
        : 'T';

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.accent.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ──────────────── Contact Info Card ────────────────
  Widget _buildContactCard(BuildContext context, TeacherModel? teacher) {
    return NeuBox(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, LucideIcons.contact, 'CONTACT DETAILS'),
          const SizedBox(height: 14),
          _DetailTile(
            icon: LucideIcons.mail,
            label: 'Email',
            value: teacher?.email ?? '—',
            valueColor: AppColors.primary,
          ),
          _divider(),
          _DetailTile(
            icon: LucideIcons.phone,
            label: 'Phone',
            value: teacher?.phoneNumber ?? '—',
          ),
          _divider(),
          _DetailTile(
            icon: LucideIcons.building2,
            label: 'Campus',
            value: teacher?.campusName ?? '—',
          ),
          _divider(),
          _DetailTile(
            icon: LucideIcons.shield,
            label: 'Status',
            value: teacher?.isActive == true ? 'Active' : 'Inactive',
            valueColor: teacher?.isActive == true
                ? AppColors.success
                : AppColors.error,
          ),
        ],
      ),
    );
  }

  // ──────────────── Assignments Card ────────────────
  Widget _buildAssignmentsCard(
    BuildContext context,
    TeacherDashboardState state,
  ) {
    final subjects = state.teacher?.subjects ?? [];
    if (subjects.isEmpty) return const SizedBox.shrink();

    // Group by course
    final Map<String, List<TeacherSubjectAssignment>> grouped = {};
    for (final s in subjects) {
      final key = s.courseName ?? 'Other';
      grouped.putIfAbsent(key, () => []).add(s);
    }

    return NeuBox(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            context,
            LucideIcons.graduationCap,
            'ASSIGNED SUBJECTS',
          ),
          const SizedBox(height: 14),
          // Subject count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${subjects.length} subject${subjects.length != 1 ? "s" : ""} across ${grouped.length} course${grouped.length != 1 ? "s" : ""}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...grouped.entries.map(
            (entry) =>
                _CourseGroup(courseName: entry.key, assignments: entry.value),
          ),
        ],
      ),
    );
  }

  // ──────────────── Quick Actions ────────────────
  Widget _buildQuickActionsCard(BuildContext context) {
    return NeuBox(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(context, LucideIcons.zap, 'QUICK ACTIONS'),
          const SizedBox(height: 14),
          _ActionTile(
            icon: LucideIcons.settings,
            label: 'Settings',
            subtitle: 'Theme, notifications & more',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherSettingsScreen()),
            ),
          ),
          _ActionTile(
            icon: LucideIcons.refreshCcw,
            label: 'Refresh Data',
            subtitle: 'Sync latest from server',
            onTap: () {
              context.read<TeacherDashboardCubit>().refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Refreshing...'),
                  backgroundColor: AppColors.info,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
          ),
          _ActionTile(
            icon: LucideIcons.helpCircle,
            label: 'Help & Support',
            subtitle: 'Contact administrator',
            onTap: () {},
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ──────────────── Logout ────────────────
  Widget _buildLogoutButton(BuildContext context) {
    return NeuBox(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      onTap: () => _confirmLogout(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.logOut, size: 17, color: AppColors.error),
            const SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.warning, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Sign Out?',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: const Text(
          'You will need to sign in again to access your dashboard.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(LogoutRequested());
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Helpers ────────────────
  Widget _sectionHeader(BuildContext context, IconData icon, String title) {
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

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Divider(
        color: AppColors.textSecondary.withValues(alpha: 0.08),
        height: 16,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Sub-Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: valueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseGroup extends StatelessWidget {
  final String courseName;
  final List<TeacherSubjectAssignment> assignments;

  const _CourseGroup({required this.courseName, required this.assignments});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course name header
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  courseName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Subject chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: assignments.map((a) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.bookOpen,
                      size: 12,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${a.subjectName}${a.batchName != null ? " · ${a.batchName}" : ""}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            color: AppColors.textSecondary.withValues(alpha: 0.06),
            height: 4,
          ),
      ],
    );
  }
}
