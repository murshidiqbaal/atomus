import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/password_recovery_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/neu_box.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  Future<void> _handleSendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = context.read<PasswordRecoveryService>();
      await service.sendPasswordResetEmail(_emailController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset link sent successfully. Check your inbox.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().replaceFirst('Exception: ', '');
        // Map common errors to user-friendly messages
        if (errorMsg.contains('Network') || errorMsg.contains('SocketException') || errorMsg.contains('Failed host lookup')) {
          errorMsg = 'No internet connection. Please verify your network and retry.';
        } else if (errorMsg.contains('rate limit')) {
          errorMsg = 'Too many requests. Please wait a bit before requesting another link.';
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

  @override
  Widget build(BuildContext context) {
    final scale = (MediaQuery.of(context).size.shortestSide / 390.0).clamp(0.72, 1.35);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Reset Password'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 40.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20 * scale),
                  NeuBox(
                    width: 80 * scale,
                    height: 80 * scale,
                    borderRadius: 20,
                    child: Icon(
                      Icons.lock_reset_rounded,
                      size: 32 * scale,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 40 * scale),
                  Text(
                    'Recover Credentials',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter your registered email below to receive a password reset link.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 50 * scale),

                  // Email input field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          'EMAIL ADDRESS',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      NeuInset(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        borderRadius: 16,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          validator: _validateEmail,
                          decoration: const InputDecoration(
                            hintText: 'yourname@email.com',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.normal,
                            ),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 18),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 40 * scale),

                  CustomButton(
                    text: 'SEND RESET LINK',
                    isLoading: _isLoading,
                    onPressed: _isLoading ? () {} : _handleSendResetLink,
                  ),

                  const SizedBox(height: 24),

                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Back to Login',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.8),
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
      ),
    );
  }
}
