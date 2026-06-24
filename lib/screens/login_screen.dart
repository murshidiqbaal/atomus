import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../theme/app_colors.dart';
import '../utils/logger.dart';
import '../widgets/app_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/neu_box.dart';
import 'main_layout.dart';
import 'teacher/teacher_main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          final destination = state.isTeacher
              ? const TeacherMainLayout()
              : const MainLayout();
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
        } else if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 40.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const NeuBox(
                    width: 80,
                    height: 80,
                    borderRadius: 20,
                    child: Icon(
                      Icons.school_rounded,
                      size: 32,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Atomus Academics',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ATOMUS PORTAL',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Username Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          'EMAIL',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.primary.withOpacity(0.6),
                                letterSpacing: 2.0,
                              ),
                        ),
                      ),
                      NeuInset(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        borderRadius: 16,
                        child: TextField(
                          controller: _usernameController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'atomus@gmail.com',
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

                  const SizedBox(height: 24),

                  // Password Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          'PORTAL PASSWORD',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.primary.withOpacity(0.6),
                                letterSpacing: 2.0,
                              ),
                        ),
                      ),
                      NeuInset(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        borderRadius: 16,
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscureText,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter password',
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
                                _obscureText
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  //toggle password visibility
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: TextButton(
                  //     onPressed: () {
                  //       Navigator.of(context).push(
                  //         MaterialPageRoute(
                  //           builder: (_) => const ForgotPasswordScreen(),
                  //         ),
                  //       );
                  //     },
                  //     child: Text(
                  //       'Forgot Password?',
                  //       style: TextStyle(
                  //         color: AppColors.primary.withOpacity(0.7),
                  //         fontWeight: FontWeight.w700,
                  //         fontSize: 13,
                  //         letterSpacing: 0.5,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  const SizedBox(height: 40),

                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return CustomButton(
                        text: 'SIGN IN',
                        isLoading: state.status == AuthStatus.loading,
                        onPressed: () {
                          if (_usernameController.text.isEmpty ||
                              _passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your credentials'),
                                backgroundColor: AppColors.error,
                              ),
                            );
                            return;
                          }
                          context.read<AuthBloc>().add(
                            LoginRequested(
                              username: _usernameController.text.trim(),
                              password: _passwordController.text,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 60),

                  // Generate Test Credentials (Teacher context fallback description)
                  // Text(
                  //   'For mock credentials, check database config.',
                  //   style: TextStyle(
                  //     color: AppColors.textSecondary.withOpacity(0.8),
                  //     fontSize: 12,
                  //     fontWeight: FontWeight.w600,
                  //   ),
                  // ),

                  // const SizedBox(height: 16),

                  // // Bypass Button for Testing
                  // TextButton.icon(
                  //   onPressed: () {
                  //     Navigator.of(context).pushReplacement(
                  //       MaterialPageRoute(
                  //         builder: (_) => const TeacherMainLayout(),
                  //       ),
                  //     );
                  //   },
                  //   icon: Icon(
                  //     Icons.fast_forward_rounded,
                  //     color: AppColors.primary.withOpacity(0.6),
                  //     size: 18,
                  //   ),
                  //   label: Text(
                  //     'BYPASS TO TEACHER DASHBOARD (DEV ONLY)',
                  //     style: TextStyle(
                  //       color: AppColors.primary.withOpacity(0.6),
                  //       fontWeight: FontWeight.w800,
                  //       fontSize: 12,
                  //       letterSpacing: 1.0,
                  //     ),
                  //   ),
                  // ),

                  // const SizedBox(height: 20),
                  const NeuDivider(),
                  const SizedBox(height: 32),

                  Text(
                    'Need concierge assistance?',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      //navigate to registrar whatspp number +917356471760
                      final uri = Uri.parse('https://wa.me/917356471760');
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          AppLogger.warning(
                            'LoginScreen',
                            'Could not launch URL: $uri',
                          );
                        }
                      } catch (e) {
                        AppLogger.error(
                          'LoginScreen',
                          'Error launching URL: $uri',
                          e,
                        );
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please contact Institution Registrar at +917356471760 for assistance.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Contact Institution Registrar',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
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
