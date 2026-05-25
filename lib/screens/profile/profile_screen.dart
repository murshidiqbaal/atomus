import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/profile/profile_cubit.dart';
import '../../blocs/profile/profile_state.dart';
import '../../models/profile_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/drive_profile_image.dart';
import '../../widgets/neu_box.dart';
import '../login_screen.dart';

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

  bool _isEditing = false;
  bool _notificationsEnabled = true;
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
    super.dispose();
  }

  Future<void> _handleRefresh() {
    return context.read<ProfileCubit>().loadProfile();
  }

  void _populateControllers(ParentProfile parent) {
    if (_controllerParentId == parent.id && !_isEditing) return;
    _controllerParentId = parent.id;
    _nameController.text = parent.fullName;
    _emailController.text = parent.email ?? '';
    _phoneController.text = parent.phoneNumber ?? '';
    _addressController.text = parent.address ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Parent Profile' : 'Profile'),
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
                        final parent = state.snapshot!.parent;
                        if (!_isEditing) _populateControllers(parent);
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
            return const Center(child: CircularProgressIndicator());
          }

          if (state.snapshot == null) {
            return _buildEmptyState(state);
          }

          final snapshot = state.snapshot!;
          if (!_isEditing) _populateControllers(snapshot.parent);

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
                  const SizedBox(height: 28),
                  _buildProfileImageManagement(snapshot, state),
                  const SizedBox(height: 28),
                  _buildLinkedStudentsSummary(snapshot),
                  const SizedBox(height: 28),
                  _buildSectionHeader('Student Profile Management'),
                  ...snapshot.students.map(
                    (student) => _buildStudentCard(student, snapshot, state),
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
            if (state.pendingUploadCount > 0)
              TextButton(
                onPressed: () =>
                    context.read<ProfileCubit>().retryPendingUploads(),
                child: const Text('Retry'),
              ),
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
      child: Row(
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
              if (state.pendingUploadCount > 0) ...[
                const SizedBox(height: 12),
                CustomButton(
                  text: 'SYNC PENDING',
                  icon: Icons.sync_rounded,
                  isOutline: true,
                  isLoading: state.status == ProfileStatus.syncing,
                  onPressed: () =>
                      context.read<ProfileCubit>().retryPendingUploads(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkedStudentsSummary(ProfileSnapshot snapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Linked Students'),
        NeuBox(
          borderRadius: 18,
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.school_outlined,
                color: AppColors.accent,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  snapshot.students.isEmpty
                      ? 'No students are linked to this parent account.'
                      : '${snapshot.students.length} linked student${snapshot.students.length == 1 ? '' : 's'}',
                  style: const TextStyle(
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

  Widget _buildStudentCard(
    LinkedStudentProfile student,
    ProfileSnapshot snapshot,
    ProfileState state,
  ) {
    final uploadKey = 'student:${student.id}';
    final localPath = snapshot.studentLocalImagePaths[student.id];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeuBox(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DriveProfileImage(
                  driveId: student.profilePhotoDriveId,
                  localPath: localPath,
                  radius: 36,
                  initials: student.initials,
                  isUploading: state.activeUploadKey == uploadKey,
                  hasError: localPath != null && state.pendingUploadCount > 0,
                  onRetry: () =>
                      context.read<ProfileCubit>().retryPendingUploads(),
                  alt: '${student.fullName} profile photo',
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.admissionNumber ??
                            student.rollNumber ??
                            'Student Profile',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildStudentMeta(
              Icons.menu_book_outlined,
              'Course',
              student.courseLabel,
            ),
            _buildStudentMeta(
              Icons.groups_outlined,
              'Batch',
              student.batchLabel,
            ),
            _buildStudentMeta(
              Icons.apartment_rounded,
              'Campus',
              student.campusLabel,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'EDIT STUDENT IMAGE',
              icon: Icons.image_outlined,
              isLoading:
                  state.status == ProfileStatus.uploading &&
                  state.activeUploadKey == uploadKey,
              onPressed: () => _showImageSourceSheet(
                onSelected: (source) => context
                    .read<ProfileCubit>()
                    .updateStudentImage(student.id, source),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSettings(ProfileState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Account Settings'),
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
            const SizedBox(height: 36),
            CustomButton(
              text: 'SAVE CHANGES',
              icon: Icons.check_rounded,
              isLoading: state.status == ProfileStatus.loading,
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                context.read<ProfileCubit>().saveParentDetails(
                  fullName: _nameController.text.trim(),
                  phoneNumber: _phoneController.text.trim(),
                  address: _addressController.text.trim(),
                );
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

  Widget _buildStudentMeta(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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

  void _logout() {
    context.read<AuthBloc>().add(LogoutRequested());
  }
}
