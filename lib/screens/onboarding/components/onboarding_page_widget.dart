import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'onboarding_model.dart';

class OnboardingPageWidget extends StatefulWidget {
  final OnboardingModel model;
  final int index;

  const OnboardingPageWidget({
    super.key,
    required this.model,
    required this.index,
  });

  @override
  State<OnboardingPageWidget> createState() => _OnboardingPageWidgetState();
}

class _OnboardingPageWidgetState extends State<OnboardingPageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = size.width > 600;
    final isLandscape = size.height < size.width;

    return Semantics(
      label: 'Onboarding page ${widget.index + 1}: ${widget.model.title}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: isLandscape
            ? Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Center(child: _buildIllustration(isDark)),
                  ),
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitle(
                            context,
                            isDark,
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 16),
                          _buildDescription(isDark, textAlign: TextAlign.left),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  _buildIllustration(isDark),
                  const Spacer(flex: 1),
                  _buildTitle(context, isDark, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  _buildDescription(isDark, textAlign: TextAlign.center),
                  const Spacer(flex: 3),
                ],
              ),
      ),
    );
  }

  Widget _buildIllustration(bool isDark) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_floatAnimation.value),
          child: child,
        );
      },
      child: Center(
        child: Container(
          width: 240,
          height: 240,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.model.color.withOpacity(isDark ? 0.25 : 0.15),
                widget.model.color.withOpacity(0.0),
              ],
              radius: 0.8,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Floating background shapes
              ...List.generate(3, (index) {
                final double size = 30.0 + (index * 20.0);
                final double top = 20.0 + (index * 45.0);
                final double left = 30.0 + (index * 55.0);
                return Positioned(
                  top: top,
                  left: left,
                  child: AnimatedContainer(
                    duration: const Duration(seconds: 2),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.model.color.withOpacity(0.12),
                        width: 1.5,
                      ),
                      color: widget.model.color.withOpacity(0.02),
                    ),
                  ),
                );
              }),

              // Main premium card frame
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  gradient: widget.model.backgroundGradient,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: widget.model.color.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.model.icon,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(
    BuildContext context,
    bool isDark, {
    required TextAlign textAlign,
  }) {
    return Text(
      widget.model.title,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w900,
        fontSize: 28,
        letterSpacing: -0.5,
        color: isDark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildDescription(bool isDark, {required TextAlign textAlign}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 350),
      child: Text(
        widget.model.description,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
