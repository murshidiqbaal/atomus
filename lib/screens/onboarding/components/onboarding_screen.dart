import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/custom_card.dart';
import '../../../widgets/neu_box.dart';
import 'onboarding_model.dart';
import 'onboarding_page_widget.dart';
import 'onboarding_provider.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static const List<OnboardingModel> _pages = [
    OnboardingModel(
      title: 'Welcome to ATOMUS',
      description: 'Your complete tuition management companion. Track attendance, marks, fees, reports, announcements, and student progress from anywhere.',
      icon: LucideIcons.school,
      color: Colors.blue,
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingModel(
      title: 'Daily Reports & Homework',
      description: 'Receive teacher reports, topics covered, homework, and personalized improvement comments every day.',
      icon: LucideIcons.clipboardList,
      color: Colors.green,
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF047857)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingModel(
      title: 'Attendance & Progress',
      description: 'Monitor attendance percentages, exam results, and academic performance with beautiful analytics.',
      icon: LucideIcons.trendingUp,
      color: Colors.orange,
      backgroundGradient: LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFC2410C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    OnboardingModel(
      title: 'Instant Notifications',
      description: 'Get instant updates about attendance, exams, fees, announcements, and important notices.',
      icon: LucideIcons.bellRing,
      color: Colors.purple,
      backgroundGradient: LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingProvider(),
      child: const _OnboardingContent(),
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: provider.notificationScreenVisible
                ? const _NotificationPermissionView()
                : _buildOnboardingFlow(context, provider, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingFlow(
      BuildContext context, OnboardingProvider provider, bool isDark) {
    return Column(
      key: const ValueKey('onboarding_pages_view'),
      children: [
        // Top Section: Skip Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Align(
            alignment: Alignment.topRight,
            child: provider.isLastPage
                ? const SizedBox(height: 40)
                : TextButton(
                    onPressed: provider.skipOnboarding,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.accent : AppColors.primary,
                      ),
                    ),
                  ),
          ),
        ),

        // Middle Section: PageView
        Expanded(
          child: PageView.builder(
            controller: provider.pageController,
            onPageChanged: provider.setCurrentPage,
            itemCount: OnboardingScreen._pages.length,
            itemBuilder: (context, index) {
              return OnboardingPageWidget(
                model: OnboardingScreen._pages[index],
                index: index,
              );
            },
          ),
        ),

        // Bottom Section: Navigation controls
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Worm Indicator
              SmoothPageIndicator(
                controller: provider.pageController,
                count: OnboardingScreen._pages.length,
                effect: WormEffect(
                  spacing: 24,
                  dotWidth: 10,
                  dotHeight: 10,
                  activeDotColor: OnboardingScreen._pages[provider.currentPage].color,
                  dotColor: isDark
                      ? Colors.white.withOpacity(0.15)
                      : Colors.black.withOpacity(0.1),
                ),
              ),
              const SizedBox(height: 32),

              // Button Controls
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: provider.isLastPage
                    ? SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: TextButton(
                          onPressed: provider.nextPage,
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text(
                            'GET STARTED',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Previous Button
                          Opacity(
                            opacity: provider.currentPage > 0 ? 1.0 : 0.0,
                            child: IgnorePointer(
                              ignoring: provider.currentPage == 0,
                              child: TextButton(
                                onPressed: provider.previousPage,
                                child: Text(
                                  'PREVIOUS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Next Button
                          GestureDetector(
                            onTap: provider.nextPage,
                            child: NeuBox(
                              width: 100,
                              height: 48,
                              borderRadius: 16,
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'NEXT',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? AppColors.accent : AppColors.primary,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      LucideIcons.chevronRight,
                                      size: 16,
                                      color: isDark ? AppColors.accent : AppColors.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationPermissionView extends StatefulWidget {
  const _NotificationPermissionView();

  @override
  State<_NotificationPermissionView> createState() =>
      _NotificationPermissionViewState();
}

class _NotificationPermissionViewState
    extends State<_NotificationPermissionView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: 'Notification Permission Screen',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              
              // Pulsing Bell Notification Icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.15),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.bellRing,
                      size: 64,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 1),

              // Title
              Text(
                'Stay Updated',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 12),

              // Description
              Container(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  'Receive attendance alerts, fee reminders, exam updates, and important announcements instantly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(flex: 2),

              // Allow Notifications Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: TextButton(
                  onPressed: () => provider.requestNotificationPermission(context),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'ALLOW NOTIFICATIONS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Maybe Later Button
              TextButton(
                onPressed: () => provider.completeOnboarding(context),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
