import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../theme/app_colors.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/student/student_bloc.dart';
import '../../blocs/student/student_state.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/neu_box.dart';
import '../login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neuBase,
      appBar: AppBar(
        title: const Text('Member Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: BlocBuilder<StudentBloc, StudentState>(
        builder: (context, state) {
          final student = state.studentInfo;
          if (student == null) return const SizedBox();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      NeuBox(
                        width: 120,
                        height: 120,
                        borderRadius: 60,
                        padding: const EdgeInsets.all(4),
                        color: AppColors.accent,
                        child: CircleAvatar(
                          radius: 56,
                          backgroundImage: NetworkImage(student.profileUrl),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: NeuBox(
                          width: 36,
                          height: 36,
                          borderRadius: 18,
                          padding: EdgeInsets.zero,
                          child: const Center(child: Icon(Icons.edit_rounded, color: AppColors.primary, size: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'MR. DAVIS',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PRIMARY GUARDIAN',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2.0),
                ),
                const SizedBox(height: 40),

                _buildSectionHeader('Member Information'),
                _buildNeuListTile(Icons.phone_rounded, 'Contact Number', '+1 (555) 123-4567'),
                _buildNeuListTile(Icons.alternate_email_rounded, 'Communication Email', 'davis.family@example.com'),
                _buildNeuListTile(Icons.location_on_rounded, 'Residential Address', '123 Education Ave, NY 10001'),

                const SizedBox(height: 32),

                _buildSectionHeader('Associated Student'),
                _buildNeuListTile(Icons.school_rounded, 'Student Designation', student.name.toUpperCase()),
                _buildNeuListTile(Icons.class_rounded, 'Academic Classification', student.grade.toUpperCase()),
                _buildNeuListTile(Icons.fingerprint_rounded, 'System Identification', 'STU-2026-8921'),

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
          );
        },
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
