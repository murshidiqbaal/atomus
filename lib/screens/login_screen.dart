import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_event.dart';
import '../blocs/auth/auth_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/neu_box.dart';
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainLayout()),
          );
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
                    'Signature Access',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Exclusively for Atomus Parents',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
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
                          'IDENTIFIER',
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Email or Mobile',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.normal,
                            ),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: AppColors.accent,
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
                          'ACCESS KEY',
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
                          obscureText: true,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter Password',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.normal,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppColors.accent,
                              size: 20,
                            ),
                            suffixIcon: Icon(
                              Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 18),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Request New Key',
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.7),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return CustomButton(
                        text: 'AUTHORIZE',
                        isLoading: state.status == AuthStatus.loading,
                        onPressed: () {
                          context.read<AuthBloc>().add(
                            LoginRequested(
                              _usernameController.text,
                              _passwordController.text,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 60),

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
                    onPressed: () {},
                    child: const Text(
                      'Contact Institution Registrar',
                      style: TextStyle(
                        color: AppColors.accent,
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
