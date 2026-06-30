import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../blocs/connectivity/connectivity_cubit.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import '../widgets/custom_button.dart';
import '../widgets/neu_box.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _isLoading = false;

  Future<void> _handleRetry() async {
    setState(() {
      _isLoading = true;
    });
    // Manually trigger the connectivity check
    await context.read<ConnectivityCubit>().checkConnection();
    // Keep the loading spinner visible for 800ms for stable UI feedback
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: NeuBox(
                  borderRadius: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Beautiful Icon Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark 
                              ? AppColors.glassHighlight.withOpacity(0.08)
                              : AppColors.neuDark.withOpacity(0.3),
                          border: Border.all(
                            color: isDark
                                ? AppColors.glassBorder.withOpacity(0.3)
                                : AppColors.neuLight,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.wifiOff,
                          size: 56,
                          color: isDark ? AppColors.accent : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Heading
                      Text(
                        'Connection Lost',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontFamily: 'Playfair Display',
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Subtitle
                      Text(
                        'It seems you are offline. Please check your network connection and try again.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      
                      // Retry Custom Button
                      CustomButton(
                        text: 'TRY AGAIN',
                        isLoading: _isLoading,
                        onPressed: _handleRetry,
                        icon: LucideIcons.refreshCw,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
