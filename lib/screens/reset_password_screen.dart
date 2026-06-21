import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../services/password_recovery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/neu_box.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // Real-time validation states
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePasswordFields);
    _confirmPasswordController.addListener(_validatePasswordFields);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordFields);
    _confirmPasswordController.removeListener(_validatePasswordFields);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePasswordFields() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _passwordsMatch = password.isNotEmpty && password == confirmPassword;
    });
  }

  bool get _isFormValid =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar &&
      _passwordsMatch;

  Future<void> _handleUpdatePassword() async {
    if (!_isFormValid) return;

    setState(() => _isLoading = true);

    try {
      final service = context.read<PasswordRecoveryService>();
      await service.updatePassword(_passwordController.text);

      if (mounted) {
        // Sync BLoC state to unauthenticated
        context.read<AuthBloc>().add(LogoutRequested());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully. Please log in with your new password.'),
            backgroundColor: AppColors.success,
          ),
        );

        // Clear navigation stack and go back to LoginScreen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceFirst('Exception: ', '');
        if (errorMsg.contains('Network') || errorMsg.contains('SocketException')) {
          errorMsg = 'No internet connection. Please verify your network and retry.';
        } else if (errorMsg.contains('weak_password') || errorMsg.contains('should be different')) {
          errorMsg = 'Password does not meet institutional requirements or matches previous password.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleCancel() {
    // Navigate back to login screen, clearing the stack
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.of(context).size.shortestSide / 390.0).clamp(0.72, 1.35);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('New Password'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Force them to complete or cancel explicitly
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 10 * scale),
                NeuBox(
                  width: 70 * scale,
                  height: 70 * scale,
                  borderRadius: 20,
                  child: Icon(
                    Icons.security_rounded,
                    size: 30 * scale,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 24 * scale),
                Text(
                  'Set Secure Password',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Define a secure, complex password below to restore access to your account.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 32 * scale),

                // Password Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        'NEW PASSWORD',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    NeuInset(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      borderRadius: 16,
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          hintStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Confirm Password Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        'CONFIRM NEW PASSWORD',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    NeuInset(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      borderRadius: 16,
                      child: TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          hintStyle: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Security Requirements Card
                NeuBox(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PASSWORD REQUIREMENTS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRequirementRow('Minimum 8 characters', _hasMinLength),
                      _buildRequirementRow('At least 1 uppercase letter (A-Z)', _hasUppercase),
                      _buildRequirementRow('At least 1 lowercase letter (a-z)', _hasLowercase),
                      _buildRequirementRow('At least 1 digit (0-9)', _hasNumber),
                      _buildRequirementRow('At least 1 special character (!@#\$%^&...)', _hasSpecialChar),
                      _buildRequirementRow('Passwords match', _passwordsMatch),
                    ],
                  ),
                ),

                SizedBox(height: 32 * scale),

                CustomButton(
                  text: 'UPDATE PASSWORD',
                  isLoading: _isLoading,
                  onPressed: (_isLoading || !_isFormValid) ? () {} : _handleUpdatePassword,
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: _isLoading ? null : _handleCancel,
                  child: Text(
                    'Cancel and Logout',
                    style: TextStyle(
                      color: AppColors.error.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isMet ? AppColors.success : AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isMet ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
