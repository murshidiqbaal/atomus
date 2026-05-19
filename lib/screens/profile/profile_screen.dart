import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../theme/app_colors.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_event.dart';
import '../../blocs/student/student_state.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/neu_box.dart';
import '../../models/dummy_data.dart';
import '../login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    
    // Fetch real-time student data linked to this parent
    context.read<StudentBloc>().add(LoadStudentData());
  }

  Future<void> _handleRefresh() async {
    final studentBloc = context.read<StudentBloc>();
    studentBloc.add(LoadStudentData());
    await studentBloc.stream
        .firstWhere((s) => s.status != StudentStatus.loading)
        .timeout(const Duration(seconds: 4), onTimeout: () => studentBloc.state);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _selectedRelationship;

  void _initControllers(StudentInfo student) {
    _nameController.text = student.fullName;
    _emailController.text = student.email ?? '';
    _phoneController.text = student.phoneNumber ?? '';
    _selectedGender = student.gender;
    _selectedRelationship = student.relationship ?? 'Parent';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'Student Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_note_rounded),
            onPressed: () {
              setState(() {
                if (!_isEditing) {
                  final state = context.read<StudentBloc>().state;
                  if (state.studentInfo != null) {
                    _initControllers(state.studentInfo!);
                  }
                }
                _isEditing = !_isEditing;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<StudentBloc, StudentState>(
        listener: (context, state) {
          if (state.status == StudentStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.redAccent),
            );
          }
        },
        builder: (context, state) {
          if (state.status == StudentStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == StudentStatus.failure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      state.errorMessage ?? 'Failed to load profile',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'RETRY FETCH',
                      onPressed: () => context.read<StudentBloc>().add(LoadStudentData()),
                    ),
                  ],
                ),
              ),
            );
          }

          final student = state.studentInfo;
          if (student == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_add_disabled_rounded, size: 80, color: AppColors.accent),
                    const SizedBox(height: 24),
                    const Text(
                      'No Student Linked',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your parent account is active, but no student has been assigned to you yet. Please contact the institution to link your child.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'REFRESH DATA',
                      onPressed: () => context.read<StudentBloc>().add(LoadStudentData()),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_isEditing) {
            return _buildEditForm(student);
          }

          return _buildProfileView(student);
        },
      ),
    );
  }

  Widget _buildProfileView(StudentInfo student) {
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.primary,
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
        children: [
          Center(
            child: NeuBox(
              width: 120,
              height: 120,
              borderRadius: 60,
              padding: const EdgeInsets.all(4),
              color: AppColors.accent,
              child: CircleAvatar(
                radius: 56,
                backgroundColor: AppColors.primary,
                child: Text(
                  student.fullName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            student.fullName.toUpperCase(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: AppColors.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            student.admissionNumber ?? 'NO ADMISSION ID',
            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2.0),
          ),
          const SizedBox(height: 40),

          _buildSectionHeader('Essential Details'),
          _buildNeuListTile(Icons.phone_rounded, 'Phone Number', student.phoneNumber ?? 'Not provided'),
          _buildNeuListTile(Icons.alternate_email_rounded, 'Email Address', student.email ?? 'Not provided'),
          _buildNeuListTile(Icons.family_restroom_rounded, 'Parental Relation', student.relationship ?? 'Not specified'),
          _buildNeuListTile(Icons.wc_rounded, 'Gender', student.gender ?? 'Not specified'),
          _buildNeuListTile(Icons.cake_rounded, 'Date of Birth', student.dateOfBirth ?? 'Not specified'),
          _buildNeuListTile(Icons.pin_rounded, 'Roll Number', student.rollNumber ?? 'N/A'),

          const SizedBox(height: 48),

          CustomButton(
            text: 'TERMINATE SESSION',
            onPressed: () {
              context.read<AuthBloc>().add(LogoutRequested());
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            isOutline: true,
            icon: Icons.power_settings_new_rounded,
          ),
          const SizedBox(height: 40),
        ],
      ),
    ),
    );
  }

  Widget _buildEditForm(StudentInfo student) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildTextField(_nameController, 'Full Name', Icons.person_outline),
            const SizedBox(height: 20),
            _buildTextField(_emailController, 'Email Address', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 20),
            _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            
            _buildSectionHeader('Gender Selection'),
            Row(
              children: [
                _buildGenderOption('Male'),
                const SizedBox(width: 12),
                _buildGenderOption('Female'),
                const SizedBox(width: 12),
                _buildGenderOption('Other'),
              ],
            ),
            const SizedBox(height: 20),
            
            _buildSectionHeader('Relationship'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ['Father', 'Mother', 'Guardian', 'Other'].map((rel) => 
                _buildRelationshipOption(rel)
              ).toList(),
            ),
            
            const SizedBox(height: 48),
            CustomButton(
              text: 'SAVE CHANGES',
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final updatedStudent = StudentInfo(
                    id: student.id,
                    fullName: _nameController.text,
                    admissionNumber: student.admissionNumber,
                    rollNumber: student.rollNumber,
                    gender: _selectedGender,
                    dateOfBirth: student.dateOfBirth,
                    grade: student.grade,
                    attendancePercentage: student.attendancePercentage,
                    progressStatus: student.progressStatus,
                    email: _emailController.text,
                    phoneNumber: _phoneController.text,
                    relationship: _selectedRelationship,
                  );
                  
                  context.read<StudentBloc>().add(UpdateStudentProfile(updatedStudent));
                  setState(() => _isEditing = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return NeuBox(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      borderRadius: 16,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          icon: Icon(icon, color: AppColors.accent, size: 20),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required field' : null,
      ),
    );
  }

  Widget _buildGenderOption(String gender) {
    bool isSelected = _selectedGender == gender;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = gender),
        child: NeuBox(
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: 12,
          color: isSelected ? AppColors.accent : null,
          child: Center(
            child: Text(
              gender,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRelationshipOption(String rel) {
    bool isSelected = _selectedRelationship == rel;
    return GestureDetector(
      onTap: () => setState(() => _selectedRelationship = rel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: NeuBox(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          borderRadius: 12,
          isPressed: isSelected,
          color: isSelected ? AppColors.accent : null,
          child: Text(
            rel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, left: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.accent, letterSpacing: 1.5),
        ),
      ),
    );
  }

  Widget _buildNeuListTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: NeuBox(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        borderRadius: 16,
        child: Row(
          children: [
            NeuBox(
              width: 44,
              height: 44,
              borderRadius: 12,
              isPressed: true,
              padding: EdgeInsets.zero,
              child: Icon(icon, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
