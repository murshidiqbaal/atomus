import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/profile/profile_cubit.dart';
import '../../blocs/profile/profile_state.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../blocs/theme/theme_state.dart';
import '../../models/profile_models.dart';
import '../../theme/app_colors.dart';
import '../../utils/id_card_pdf_generator.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/drive_profile_image.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/shimmer.dart';
import '../main_layout.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Secondary/emergency contact controllers
  final _secNameController = TextEditingController();
  final _secPhoneController = TextEditingController();
  final _secEmailController = TextEditingController();
  final _secRelationController = TextEditingController();

  // Dynamic student medical controllers
  final Map<String, TextEditingController> _studentBloodControllers = {};
  final Map<String, TextEditingController> _studentAllergiesControllers = {};
  final Map<String, TextEditingController> _studentConditionsControllers = {};
  final Map<String, TextEditingController> _studentDobControllers = {};

  bool _isEditing = false;
  bool _notificationsEnabled = true;
  bool _biometricsEnabled = false;
  String? _controllerParentId;

  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _secNameController.dispose();
    _secPhoneController.dispose();
    _secEmailController.dispose();
    _secRelationController.dispose();
    for (final controller in _studentBloodControllers.values) {
      controller.dispose();
    }
    for (final controller in _studentAllergiesControllers.values) {
      controller.dispose();
    }
    for (final controller in _studentConditionsControllers.values) {
      controller.dispose();
    }
    for (final controller in _studentDobControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleRefresh() {
    return context.read<ProfileCubit>().loadProfile();
  }

  void _populateControllers(ProfileSnapshot snapshot) {
    final parent = snapshot.parent;
    if (_controllerParentId == parent.id && !_isEditing) return;
    _controllerParentId = parent.id;
    _nameController.text = parent.fullName;
    _emailController.text = parent.email ?? '';
    _phoneController.text = parent.phoneNumber ?? '';
    _addressController.text = parent.address ?? '';
    _secNameController.text = parent.secondaryContactName ?? '';
    _secPhoneController.text = parent.secondaryContactPhone ?? '';
    _secEmailController.text = parent.secondaryContactEmail ?? '';
    _secRelationController.text = parent.secondaryContactRelationship ?? '';

    for (final student in snapshot.students) {
      _studentBloodControllers
              .putIfAbsent(student.id, () => TextEditingController())
              .text =
          student.bloodGroup ?? '';
      _studentAllergiesControllers
              .putIfAbsent(student.id, () => TextEditingController())
              .text =
          student.allergies ?? '';
      _studentConditionsControllers
              .putIfAbsent(student.id, () => TextEditingController())
              .text =
          student.medicalConditions ?? '';
      _studentDobControllers
              .putIfAbsent(student.id, () => TextEditingController())
              .text =
          student.dob ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              final mainLayoutState = context.findAncestorStateOfType<MainLayoutState>();
              if (mainLayoutState != null) {
                mainLayoutState.setIndex(0);
              }
            }
          },
        ),
        title: Text(_isEditing ? 'Edit Parent & Student Profiles' : 'Profile'),
        actions: [
          BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              final canEdit = state.snapshot != null;
              return IconButton(
                icon: Icon(
                  _isEditing ? Icons.close_rounded : Icons.edit_note_rounded,
                ),
                onPressed: canEdit
                    ? () {
                        final snapshot = state.snapshot!;
                        if (!_isEditing) _populateControllers(snapshot);
                        setState(() => _isEditing = !_isEditing);
                      }
                    : null,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<ProfileCubit, ProfileState>(
        listener: _listenForProfileMessages,
        builder: (context, state) {
          if (state.status == ProfileStatus.loading && state.snapshot == null) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Shimmer Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.03)
                          : Colors.black.withOpacity(0.01),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.03),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Shimmer(width: 88, height: 88, borderRadius: 44),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Shimmer(width: 150, height: 18),
                                  SizedBox(height: 8),
                                  Shimmer(width: 120, height: 12),
                                  SizedBox(height: 12),
                                  Shimmer(width: 60, height: 16, borderRadius: 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            3,
                            (_) => const Shimmer(width: 80, height: 24, borderRadius: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Section Skeletons
                  const Shimmer(width: 100, height: 14),
                  const SizedBox(height: 16),
                  ...List.generate(
                    4,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Shimmer.cardSkeleton(height: 60, borderRadius: 16),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state.snapshot == null) {
            return _buildEmptyState(state);
          }

          final snapshot = state.snapshot!;
          if (!_isEditing) _populateControllers(snapshot);

          if (_isEditing) {
            return _buildEditForm(snapshot, state);
          }

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.primary,
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.isOffline || state.pendingUploadCount > 0)
                    _buildSyncBanner(state),
                  _buildParentHero(snapshot, state),
                  const SizedBox(height: 28),
                  _buildSectionHeader('Parent Profile'),
                  _buildDetailTile(
                    Icons.person_outline_rounded,
                    'Full Name',
                    snapshot.parent.fullName,
                  ),
                  _buildDetailTile(
                    Icons.phone_outlined,
                    'Phone Number',
                    snapshot.parent.phoneNumber ?? 'Not provided',
                  ),
                  _buildDetailTile(
                    Icons.location_on_outlined,
                    'Address',
                    snapshot.parent.address ?? 'Not provided',
                  ),
                  _buildDetailTile(
                    Icons.alternate_email_rounded,
                    'Email',
                    snapshot.parent.email ?? 'Not provided',
                  ),

                  // Secondary / Emergency Contact Details Display
                  if (snapshot.parent.secondaryContactName != null &&
                      snapshot.parent.secondaryContactName!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionHeader('Emergency / Secondary Contact'),
                    _buildDetailTile(
                      Icons.contact_phone_outlined,
                      'Name & Relation',
                      '${snapshot.parent.secondaryContactName} (${snapshot.parent.secondaryContactRelationship ?? 'Secondary Contact'})',
                    ),
                    if (snapshot.parent.secondaryContactPhone != null &&
                        snapshot.parent.secondaryContactPhone!.isNotEmpty)
                      _buildDetailTile(
                        Icons.phone_forwarded_rounded,
                        'Emergency Phone',
                        snapshot.parent.secondaryContactPhone!,
                      ),
                    if (snapshot.parent.secondaryContactEmail != null &&
                        snapshot.parent.secondaryContactEmail!.isNotEmpty)
                      _buildDetailTile(
                        Icons.email_outlined,
                        'Emergency Email',
                        snapshot.parent.secondaryContactEmail!,
                      ),
                  ],

                  const SizedBox(height: 28),
                  _buildProfileImageManagement(snapshot, state),
                  const SizedBox(height: 28),
                  _buildLinkedStudentsSummary(snapshot),
                  const SizedBox(height: 28),
                  _buildSectionHeader('Student Profile ID Cards'),
                  ...snapshot.students.map(
                    (student) => StudentIdCard(
                      student: student,
                      snapshot: snapshot,
                      state: state,
                      onEditImage: () => _showImageSourceSheet(
                        onSelected: (source) => context
                            .read<ProfileCubit>()
                            .updateStudentImage(student.id, source),
                      ),
                      onEditMedical: () =>
                          _showStudentMedicalEditSheet(context, student),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildAccountSettings(state),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _listenForProfileMessages(BuildContext context, ProfileState state) {
    if (state.status == ProfileStatus.uploadSuccess) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile image updated.')));
    }
    if (state.status == ProfileStatus.uploadFailed &&
        state.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
    }
    if (state.status == ProfileStatus.failure && state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildEmptyState(ProfileState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 72,
              color: AppColors.accent,
            ),
            const SizedBox(height: 18),
            const Text(
              'Profile Not Available',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              state.errorMessage ??
                  'We could not load your parent profile right now.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            CustomButton(
              text: 'RETRY',
              icon: Icons.refresh_rounded,
              onPressed: () => context.read<ProfileCubit>().loadProfile(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncBanner(ProfileState state) {
    final text = state.pendingUploadCount > 0
        ? '${state.pendingUploadCount} image update${state.pendingUploadCount == 1 ? '' : 's'} waiting to sync'
        : 'Offline mode: showing cached profile';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: NeuBox(
        borderRadius: 16,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              state.pendingUploadCount > 0
                  ? Icons.cloud_upload_outlined
                  : Icons.wifi_off_rounded,
              color: AppColors.warning,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Automatically syncing in background when online
          ],
        ),
      ),
    );
  }

  Widget _buildParentHero(ProfileSnapshot snapshot, ProfileState state) {
    final parent = snapshot.parent;
    final uploadKey = 'parent:${parent.id}';

    return NeuBox(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  DriveProfileImage(
                    driveId: parent.profilePhotoDriveId,
                    localPath: snapshot.parentLocalImagePath,
                    radius: 44,
                    initials: parent.initials,
                    isUploading: state.activeUploadKey == uploadKey,
                    hasError:
                        snapshot.parentLocalImagePath != null &&
                        state.pendingUploadCount > 0,
                    onRetry: () =>
                        context.read<ProfileCubit>().retryPendingUploads(),
                    alt: '${parent.fullName} profile photo',
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.accent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showImageSourceSheet(
                          onSelected: context
                              .read<ProfileCubit>()
                              .updateParentImage,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parent.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      parent.email ?? parent.phoneNumber ?? 'Atomus Parent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      parent.accountStatus ?? 'Active',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const NeuDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHeroBadge(
                Icons.people_outline_rounded,
                '${snapshot.students.length} Student${snapshot.students.length == 1 ? '' : 's'}',
                AppColors.accent,
              ),
              _buildHeroBadge(
                Icons.security_rounded,
                parent.accountStatus ?? 'Active',
                AppColors.success,
              ),
              _buildHeroBadge(
                Icons.cloud_done_outlined,
                state.isOffline ? 'Offline' : 'Connected',
                state.isOffline ? AppColors.error : AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageManagement(
    ProfileSnapshot snapshot,
    ProfileState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Profile Image Management'),
        NeuBox(
          borderRadius: 18,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parent Photo',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Images preview instantly, then sync to Google Drive and Supabase.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.35),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'CHANGE PHOTO',
                icon: Icons.add_a_photo_outlined,
                isLoading:
                    state.status == ProfileStatus.uploading &&
                    state.activeUploadKey == 'parent:${snapshot.parent.id}',
                onPressed: () => _showImageSourceSheet(
                  onSelected: context.read<ProfileCubit>().updateParentImage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkedStudentsSummary(ProfileSnapshot snapshot) {
    if (snapshot.students.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('Linked Students'),
          NeuBox(
            borderRadius: 18,
            padding: const EdgeInsets.all(18),
            child: const Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  color: AppColors.accent,
                  size: 28,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No students are linked to this parent account.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Linked Students'),
        ...snapshot.students.map((student) {
          final localPath = snapshot.studentLocalImagePaths[student.id];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeuBox(
              borderRadius: 18,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  DriveProfileImage(
                    driveId: student.profilePhotoDriveId,
                    localPath: localPath,
                    radius: 20,
                    initials: student.initials,
                    alt: '${student.fullName} profile photo',
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Roll: ${student.rollNumber ?? "N/A"} · ${student.courseLabel}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAccountSettings(ProfileState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Account & System Settings'),
        NeuBox(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            children: [
              SwitchListTile(
                value: _notificationsEnabled,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.accent,
                title: const Text(
                  'Notifications',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Attendance and institute alerts'),
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
              ),
              const Divider(height: 1),

              // Dark Mode Toggle using ThemeBloc
              BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, themeState) {
                  final isDark = themeState.themeMode == ThemeMode.dark;
                  return SwitchListTile(
                    value: isDark,
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: AppColors.accent,
                    title: const Text(
                      'Dark Mode',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text('Toggle app color theme'),
                    onChanged: (value) {
                      context.read<ThemeBloc>().add(ToggleTheme());
                    },
                  );
                },
              ),
              const Divider(height: 1),

              // Biometric authentication toggle stub
              SwitchListTile(
                value: _biometricsEnabled,
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppColors.accent,
                title: const Text(
                  'Biometric Login',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Secure login with Face ID / Fingerprint'),
                onChanged: (value) {
                  setState(() => _biometricsEnabled = value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value ? 'Biometrics enabled.' : 'Biometrics disabled.',
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),

              // Change Password Row
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.accent,
                ),
                title: const Text(
                  'Change Password',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Update account security'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showChangePasswordSheet(context),
              ),
              const Divider(height: 1),

              _buildSettingsRow(
                Icons.support_agent_rounded,
                'Support',
                'support@atomuserp.com',
              ),
              const Divider(height: 1),
              _buildSettingsRow(
                Icons.info_outline_rounded,
                'App Version',
                state.appVersion ?? '1.0.0',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        CustomButton(
          text: 'LOGOUT',
          icon: Icons.power_settings_new_rounded,
          isOutline: true,
          onPressed: _logout,
        ),
      ],
    );
  }

  Widget _buildEditForm(ProfileSnapshot snapshot, ProfileState state) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: DriveProfileImage(
                driveId: snapshot.parent.profilePhotoDriveId,
                localPath: snapshot.parentLocalImagePath,
                radius: 48,
                initials: snapshot.parent.initials,
                isUploading: state.status == ProfileStatus.uploading,
                alt: '${snapshot.parent.fullName} profile photo',
              ),
            ),
            const SizedBox(height: 24),
            _buildTextField(_nameController, 'Full Name', Icons.person_outline),
            const SizedBox(height: 18),
            _buildTextField(
              _phoneController,
              'Phone Number',
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 18),
            _buildTextField(
              _addressController,
              'Address',
              Icons.location_on_outlined,
              maxLines: 3,
            ),
            const SizedBox(height: 18),
            _buildTextField(
              _emailController,
              'Email Address',
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              readOnly: true,
              required: false,
            ),

            // Secondary contact fields inside edit form
            const SizedBox(height: 28),
            _buildSectionHeader('Emergency / Secondary Contact'),
            _buildTextField(
              _secNameController,
              'Contact Name',
              Icons.person_pin_outlined,
              required: false,
            ),
            const SizedBox(height: 18),
            _buildTextField(
              _secRelationController,
              'Relationship (e.g. Father, Mother)',
              Icons.family_restroom_rounded,
              required: false,
            ),
            const SizedBox(height: 18),
            _buildTextField(
              _secPhoneController,
              'Phone Number',
              Icons.phone_forwarded_rounded,
              keyboardType: TextInputType.phone,
              required: false,
            ),
            const SizedBox(height: 18),
            // address
            _buildTextField(
              _addressController,
              'Address',
              Icons.location_pin,
              keyboardType: TextInputType.streetAddress,
              required: false,
            ),

            const SizedBox(height: 18),
            _buildTextField(
              _secEmailController,
              'Email Address',
              Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              required: false,
            ),

            // Student details for ID Card Backside
            for (final student in snapshot.students) ...[
              const SizedBox(height: 28),
              _buildSectionHeader(
                '${student.fullName} - ID Card Backside Details',
              ),
              Center(
                child: DriveProfileImage(
                  driveId: student.profilePhotoDriveId,
                  localPath: snapshot.studentLocalImagePaths[student.id],
                  radius: 48,
                  initials: student.initials,
                  alt: '${student.fullName} profile photo',
                ),
              ),
              const SizedBox(height: 18),
              _buildTextField(
                _studentBloodControllers[student.id]!,
                'Blood Group (e.g. O+, A-)',
                Icons.favorite_rounded,
                required: false,
              ),
              const SizedBox(height: 18),
              _buildTextField(
                _studentAllergiesControllers[student.id]!,
                'Allergies',
                Icons.warning_amber_rounded,
                required: false,
              ),
              const SizedBox(height: 18),
              _buildTextField(
                _studentConditionsControllers[student.id]!,
                'Medical / Chronic Conditions',
                Icons.medical_services_outlined,
                required: false,
              ),
              const SizedBox(height: 18),
              _buildDateField(
                context,
                _studentDobControllers[student.id]!,
                'Date of Birth',
                Icons.calendar_month_rounded,
                required: false,
              ),
            ],

            const SizedBox(height: 36),
            CustomButton(
              text: 'SAVE CHANGES',
              icon: Icons.check_rounded,
              isLoading: state.status == ProfileStatus.loading,
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;

                // Save Parent Details
                context.read<ProfileCubit>().saveParentDetails(
                  fullName: _nameController.text.trim(),
                  phoneNumber: _phoneController.text.trim(),
                  address: _addressController.text.trim(),
                  secondaryContactName: _secNameController.text.trim(),
                  secondaryContactPhone: _secPhoneController.text.trim(),
                  secondaryContactEmail: _secEmailController.text.trim(),
                  secondaryContactRelationship: _secRelationController.text
                      .trim(),
                );

                // Save each linked student's details
                for (final student in snapshot.students) {
                  context.read<ProfileCubit>().saveStudentDetails(
                    studentId: student.id,
                    bloodGroup: _studentBloodControllers[student.id]?.text
                        .trim(),
                    allergies: _studentAllergiesControllers[student.id]?.text
                        .trim(),
                    medicalConditions: _studentConditionsControllers[student.id]
                        ?.text
                        .trim(),
                    dob: _studentDobControllers[student.id]?.text.trim(),
                  );
                }

                setState(() => _isEditing = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    bool readOnly = false,
    bool required = true,
    int maxLines = 1,
  }) {
    return NeuBox(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      borderRadius: 16,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        maxLines: maxLines,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          icon: Icon(icon, color: AppColors.accent, size: 20),
        ),
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Required field'
                  : null
            : null,
      ),
    );
  }

  Widget _buildDateField(
    BuildContext context,
    TextEditingController controller,
    String label,
    IconData icon, {
    bool required = true,
  }) {
    return NeuBox(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      borderRadius: 16,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          icon: Icon(icon, color: AppColors.accent, size: 20),
        ),
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(controller.text) ?? DateTime(2010),
            firstDate: DateTime(1990),
            lastDate: DateTime.now(),
          );
          if (picked != null) {
            controller.text = picked.toIso8601String().split('T').first;
          }
        },
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Required field'
                  : null
            : null,
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NeuBox(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: AppColors.accent,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Future<void> _showImageSourceSheet({
    required Future<void> Function(ImageSource source) onSelected,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source != null && mounted) {
      await onSelected(source);
    }
  }

  void _showStudentMedicalEditSheet(
    BuildContext context,
    LinkedStudentProfile student,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _StudentMedicalEditSheet(student: student),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ChangePasswordSheet(),
    );
  }

  void _logout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            SizedBox(width: 10),
            Text(
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
            child: const Text(
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
}

class _StudentMedicalEditSheet extends StatefulWidget {
  final LinkedStudentProfile student;

  const _StudentMedicalEditSheet({required this.student});

  @override
  State<_StudentMedicalEditSheet> createState() => _StudentMedicalEditSheetState();
}

class _StudentMedicalEditSheetState extends State<_StudentMedicalEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bloodGroupController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _medicalConditionsController;
  late final TextEditingController _dobController;

  @override
  void initState() {
    super.initState();
    _bloodGroupController = TextEditingController(text: widget.student.bloodGroup);
    _allergiesController = TextEditingController(text: widget.student.allergies);
    _medicalConditionsController = TextEditingController(
      text: widget.student.medicalConditions,
    );
    _dobController = TextEditingController(text: widget.student.dob);
  }

  @override
  void dispose() {
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _medicalConditionsController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Student Medical Details',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.student.fullName,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue:
                    [
                      'A+',
                      'A-',
                      'B+',
                      'B-',
                      'AB+',
                      'AB-',
                      'O+',
                      'O-',
                    ].contains(_bloodGroupController.text)
                    ? _bloodGroupController.text
                    : null,
                decoration: InputDecoration(
                  labelText: 'Blood Group',
                  prefixIcon: const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.error,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                    .map(
                      (bg) => DropdownMenuItem(value: bg, child: Text(bg)),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _bloodGroupController.text = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _allergiesController,
                decoration: InputDecoration(
                  labelText: 'Allergies',
                  prefixIcon: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _medicalConditionsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Medical/Safety Conditions',
                  prefixIcon: const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.accent,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.accent,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.tryParse(_dobController.text) ??
                        DateTime(2010),
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _dobController.text = picked
                          .toIso8601String()
                          .split('T')
                          .first;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'SAVE DETAILS',
                onPressed: () {
                  context.read<ProfileCubit>().saveStudentDetails(
                    studentId: widget.student.id,
                    bloodGroup: _bloodGroupController.text.trim(),
                    allergies: _allergiesController.text.trim(),
                    medicalConditions: _medicalConditionsController.text
                        .trim(),
                    dob: _dobController.text.trim(),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _newPasswordController;
  late final TextEditingController _confirmPasswordController;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _newPasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Change Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => value == null || value.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () => setState(
                      () => _obscureConfirm = !_obscureConfirm,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) =>
                    value != _newPasswordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'UPDATE PASSWORD',
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  try {
                    await Supabase.instance.client.auth.updateUser(
                      UserAttributes(
                        password: _newPasswordController.text,
                      ),
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password updated successfully!',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to update password: $e',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentIdCard extends StatefulWidget {
  final LinkedStudentProfile student;
  final ProfileSnapshot snapshot;
  final ProfileState state;
  final VoidCallback onEditImage;
  final VoidCallback onEditMedical;

  const StudentIdCard({
    super.key,
    required this.student,
    required this.snapshot,
    required this.state,
    required this.onEditImage,
    required this.onEditMedical,
  });

  @override
  State<StudentIdCard> createState() => _StudentIdCardState();
}

class _StudentIdCardState extends State<StudentIdCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: _toggleCard,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final transformValue = _animation.value * 3.1415926535897932;
            final isBack = _animation.value > 0.5;
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(transformValue),
              alignment: Alignment.center,
              child: isBack
                  ? Transform(
                      transform: Matrix4.identity()
                        ..rotateY(3.1415926535897932),
                      alignment: Alignment.center,
                      child: _buildBackSide(),
                    )
                  : _buildFrontSide(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardContainer({required Widget child, required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFBF953F), // Gold metallic stops
            Color(0xFFFCF6BA),
            Color(0xFFB38728),
            Color(0xFFFBF5B7),
            Color(0xFFAA771C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.5), // Simulated gold border thickness
      child: Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.5),
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF131824), const Color(0xFF090D14)]
                : [const Color(0xFFFFFFFF), const Color(0xFFF2F6FE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22.5),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMetaField(
    BuildContext context,
    String label,
    String value,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            color: isDark ? const Color(0xFFC59A3F) : const Color(0xFF8C641B),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E2433),
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildBackMetaLabel(
    IconData icon,
    String label,
    String value, {
    Color? textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: textColor ?? const Color(0xFFD4AF37)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white54 : Colors.black45,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFrontSide() {
    final uploadKey = 'student:${widget.student.id}';
    final localPath = widget.snapshot.studentLocalImagePaths[widget.student.id];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCardContainer(
      isDark: isDark,
      child: Stack(
        children: [
          // Security Pattern
          Positioned.fill(
            child: CustomPaint(
              painter: SecurityPatternPainter(
                color:
                    (isDark ? const Color(0xFFD4AF37) : const Color(0xFF4B61DD))
                        .withOpacity(0.025),
              ),
            ),
          ),

          // Faded Crest Watermark in Background
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.shield_rounded,
              size: 160,
              color:
                  (isDark ? const Color(0xFFD4AF37) : const Color(0xFF4B61DD))
                      .withOpacity(0.035),
            ),
          ),

          // Diagonal Holographic Sheen
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.4, 0.45, 0.5, 0.55, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Card Contents
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFD4AF37), // Gold Logo
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ATOMUS ACADEMICS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? const Color(0xFFD4AF37)
                                : const Color(0xFF1E2433),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.nfc_rounded,
                      color: isDark
                          ? const Color(0xFFD4AF37).withOpacity(0.3)
                          : Colors.black26,
                      size: 18,
                    ),
                  ],
                ),

                // Middle Details Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar Image with Golden Ring
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2), // Border thickness
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFBF953F),
                                Color(0xFFFCF6BA),
                                Color(0xFFB38728),
                                Color(0xFFFBF5B7),
                                Color(0xFFAA771C),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Container(
                              color: Colors.transparent,
                              child: DriveProfileImage(
                                driveId: widget.student.profilePhotoDriveId,
                                localPath: localPath,
                                radius: 33,
                                initials: widget.student.initials,
                                isUploading:
                                    widget.state.activeUploadKey == uploadKey,
                                hasError:
                                    localPath != null &&
                                    widget.state.pendingUploadCount > 0,
                                onRetry: () => context
                                    .read<ProfileCubit>()
                                    .retryPendingUploads(),
                                alt: '${widget.student.fullName} profile photo',
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: const Color(0xFFD4AF37),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                widget.onEditImage();
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),

                    // Metadata Details Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E2433),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            widget.student.admissionNumber ??
                                widget.student.rollNumber ??
                                'Student ID Card',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetaField(
                                  context,
                                  'COURSE',
                                  widget.student.courseLabel,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetaField(
                                  context,
                                  'BATCH',
                                  widget.student.batchLabel,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetaField(
                                  context,
                                  'CAMPUS',
                                  widget.student.campusLabel,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildMetaField(
                                  context,
                                  'DATE OF BIRTH',
                                  widget.student.dob != null &&
                                          widget.student.dob!.isNotEmpty
                                      ? widget.student.dob!
                                      : 'Not Provided',
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bottom Flippable Row
                Column(
                  children: [
                    Container(
                      height: 0.5,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // High-fidelity EMV chip mockup
                        Container(
                          width: 32,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFFDF7A),
                                Color(0xFFE2B755),
                                Color(0xFFC59A3F),
                                Color(0xFFFFF2B2),
                                Color(0xFFC59A3F),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: const Color(0xFF8C641B),
                              width: 0.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 2,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: 10,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 0.8,
                                  color: const Color(
                                    0xFF8C641B,
                                  ).withOpacity(0.6),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  width: 0.8,
                                  color: const Color(
                                    0xFF8C641B,
                                  ).withOpacity(0.6),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 0.8,
                                  color: const Color(
                                    0xFF8C641B,
                                  ).withOpacity(0.6),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 0.8,
                                  color: const Color(
                                    0xFF8C641B,
                                  ).withOpacity(0.6),
                                ),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: Container(
                                  width: 8,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2B755),
                                    borderRadius: BorderRadius.circular(1.5),
                                    border: Border.all(
                                      color: const Color(0xFF8C641B),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.swap_horizontal_circle_outlined,
                              size: 14,
                              color: Color(0xFFD4AF37),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'TAP TO FLIP DETAILS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white54 : Colors.black45,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackSide() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildCardContainer(
      isDark: isDark,
      child: Stack(
        children: [
          // Security Pattern
          Positioned.fill(
            child: CustomPaint(
              painter: SecurityPatternPainter(
                color:
                    (isDark ? const Color(0xFFD4AF37) : const Color(0xFF4B61DD))
                        .withOpacity(0.025),
              ),
            ),
          ),

          // Faded Crest Watermark
          Positioned(
            left: -20,
            bottom: -20,
            child: Icon(
              Icons.shield_rounded,
              size: 160,
              color:
                  (isDark ? const Color(0xFFD4AF37) : const Color(0xFF4B61DD))
                      .withOpacity(0.035),
            ),
          ),

          // Diagonal Holographic Sheen
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.12),
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.4, 0.45, 0.5, 0.55, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Magnetic Stripe
              const SizedBox(height: 8),
              Container(
                height: 28,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF261D15), // Dark bronze stripe
                      Color(0xFF140F0A),
                      Color(0xFF261D15),
                    ],
                  ),
                ),
              ),

              // Remaining Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.health_and_safety_rounded,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'EMERGENCY & MEDICAL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.redAccent,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: Color(0xFFD4AF37),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: widget.onEditMedical,
                          ),
                        ],
                      ),

                      // Medical Details in Structured Grid
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildBackMetaLabel(
                                      Icons.favorite_rounded,
                                      'BLOOD GROUP',
                                      widget.student.bloodGroup ??
                                          'Not provided',
                                      textColor: Colors.redAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildBackMetaLabel(
                                      Icons.warning_amber_rounded,
                                      'ALLERGIES',
                                      widget.student.allergies ?? 'None',
                                      textColor: const Color(0xFFD4AF37),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildBackMetaLabel(
                                      Icons.medical_information_outlined,
                                      'SAFETY CONDITIONS',
                                      widget.student.medicalConditions ??
                                          'None reported',
                                      textColor: isDark
                                          ? const Color(0xFFF2D17E)
                                          : const Color(0xFF8C641B),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildBackMetaLabel(
                                      Icons.phone_in_talk_rounded,
                                      'EMERGENCY CONTACT',
                                      widget.snapshot.parent.phoneNumber ??
                                          'Not provided',
                                      textColor: isDark
                                          ? const Color(0xFFF2D17E)
                                          : const Color(0xFF8C641B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Signature Panel Mockup
                      Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: Text(
                                'AUTHORISED SIGNATURE',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                widget.student.rollNumber ??
                                    widget.student.admissionNumber ??
                                    'SECURE',
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Bottom flip guide and options button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ATOMUS DIGITAL SECURITY CERTIFIED',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white38 : Colors.black38,
                              letterSpacing: 0.5,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showIdCardActionsSheet(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E2433)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFD4AF37),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 3,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CustomPaint(
                                      painter: QrPainter(
                                        color: isDark
                                            ? const Color(0xFFD4AF37)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'OPTIONS',
                                    style: TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? const Color(0xFFD4AF37)
                                          : const Color(0xFF1E2433),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showIdCardActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'ID Card Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.student.fullName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),

                // QR Mockup in options sheet
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        painter: QrPainter(color: Colors.black87),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ListTile(
                  leading: const Icon(
                    Icons.download_rounded,
                    color: AppColors.success,
                  ),
                  title: const Text(
                    'Download ID Card (PDF)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Save softcopy to device'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await IdCardPdfGenerator.downloadIdCard(
                        student: widget.student,
                        parent: widget.snapshot.parent,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to download PDF: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.print_rounded,
                    color: AppColors.accent,
                  ),
                  title: const Text(
                    'Print ID Card',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Send to local wireless printer'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await IdCardPdfGenerator.printIdCard(
                        student: widget.student,
                        parent: widget.snapshot.parent,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to print: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}

class QrPainter extends CustomPainter {
  final Color color;

  QrPainter({this.color = Colors.black87});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw QR Finder Patterns in 3 corners
    final finderSize = size.width * 0.25;

    // Top-Left
    _drawFinder(canvas, paint, Offset.zero, finderSize);
    // Top-Right
    _drawFinder(canvas, paint, Offset(size.width - finderSize, 0), finderSize);
    // Bottom-Left
    _drawFinder(canvas, paint, Offset(0, size.height - finderSize), finderSize);

    // Draw random-looking QR data blocks in the remaining area
    final double block = size.width / 15;
    for (int i = 0; i < 15; i++) {
      for (int j = 0; j < 15; j++) {
        // Skip finder areas
        if (i < 4 && j < 4) continue;
        if (i > 10 && j < 4) continue;
        if (i < 4 && j > 10) continue;

        // Pseudo-random deterministic noise
        final hash = (i * 37 + j * 17) % 2;
        if (hash == 0) {
          canvas.drawRect(
            Rect.fromLTWH(i * block, j * block, block - 1, block - 1),
            paint,
          );
        }
      }
    }
  }

  void _drawFinder(Canvas canvas, Paint paint, Offset offset, double size) {
    final block = size / 7;
    // Outer square
    canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, size, size), paint);
    // White middle
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx + block,
        offset.dy + block,
        size - block * 2,
        size - block * 2,
      ),
      whitePaint,
    );
    // Inner square
    canvas.drawRect(
      Rect.fromLTWH(
        offset.dx + block * 2,
        offset.dy + block * 2,
        size - block * 4,
        size - block * 4,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SecurityPatternPainter extends CustomPainter {
  final Color color;

  SecurityPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw wavy lines from left to right
    final path = Path();
    for (double i = -60; i < size.width + 60; i += 24) {
      path.reset();
      path.moveTo(i, -20);
      path.cubicTo(
        i + 30,
        size.height * 0.3,
        i - 30,
        size.height * 0.7,
        i + 20,
        size.height + 20,
      );
      canvas.drawPath(path, paint);
    }

    // Draw secondary intersecting curves
    for (double i = -60; i < size.width + 60; i += 24) {
      path.reset();
      path.moveTo(i, size.height + 20);
      path.cubicTo(
        i - 30,
        size.height * 0.7,
        i + 30,
        size.height * 0.3,
        i - 20,
        -20,
      );
      canvas.drawPath(path, paint);
    }

    // Draw concentric circles / security rosette in the bottom-right corner
    final rosetteCenter = Offset(size.width * 0.85, size.height * 0.65);
    for (double r = 12; r < 140; r += 16) {
      canvas.drawCircle(rosetteCenter, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SecurityPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}
