import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../theme/app_colors.dart';
import '../widgets/app_background.dart';
import 'login_screen.dart';
import 'main_layout.dart';
import 'teacher/teacher_main_layout.dart';

/// Minimal premium animated splash.
/// Two controllers: one runs once (entrance), one loops (aura pulse).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _aura;

  // Entrance phases (single controller, staggered intervals).
  late final Animation<double> _iconFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _wordmarkFade;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _underlineWidth;

  // Continuous aura pulse around the icon.
  late final Animation<double> _auraScale;
  late final Animation<double> _auraOpacity;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _aura = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _iconFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _iconScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _wordmarkFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.45, 0.85, curve: Curves.easeOut),
    );
    _wordmarkSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entrance,
            curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic),
          ),
        );
    _underlineWidth = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
    );

    _auraScale = Tween<double>(
      begin: 1.0,
      end: 1.22,
    ).animate(CurvedAnimation(parent: _aura, curve: Curves.easeInOut));
    _auraOpacity = Tween<double>(
      begin: 0.35,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _aura, curve: Curves.easeOut));

    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _aura.dispose();
    super.dispose();
  }

  void _handoff(AuthState state) {
    final navigator = Navigator.of(context);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final Widget destination;
      if (state.status == AuthStatus.authenticated) {
        destination = state.isTeacher
            ? const TeacherMainLayout()
            : const MainLayout();
      } else {
        destination = const LoginScreen();
      }
      navigator.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, animation, _) => destination,
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 700),
        ),
      );
    });
  }

  // Precache the splash image so the first frame doesn't flash empty
  // on cold start. didChangeDependencies fires before build.
  bool _imagePrecached = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagePrecached) {
      precacheImage(
        const AssetImage('assets/app_icon/appicon.png'),
        context,
      );
      _imagePrecached = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated ||
            state.status == AuthStatus.unauthenticated) {
          _handoff(state);
        }
      },
      child: AppBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Single scale factor driven off the shortest side of the
                // available area. Clamped so very small phones (~320 logical
                // px) and very large tablets stay within sane visual bounds.
                final shortest = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight;
                final double scale =
                    (shortest / 390.0).clamp(0.72, 1.35).toDouble();

                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24 * scale,
                      vertical: 24 * scale,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AnimatedMark(
                          scale: scale,
                          iconFade: _iconFade,
                          iconScale: _iconScale,
                          auraScale: _auraScale,
                          auraOpacity: _auraOpacity,
                        ),
                        SizedBox(height: 44 * scale),
                        // FittedBox guards against pixel overflow when the
                        // wordmark would be wider than the viewport on
                        // tiny landscape constraints.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _Wordmark(
                            controller: _entrance,
                            scale: scale,
                          ),
                        ),
                        SizedBox(height: 22 * scale),
                        _Underline(progress: _underlineWidth, scale: scale),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMark extends StatelessWidget {
  const _AnimatedMark({
    required this.scale,
    required this.iconFade,
    required this.iconScale,
    required this.auraScale,
    required this.auraOpacity,
  });

  final double scale;
  final Animation<double> iconFade;
  final Animation<double> iconScale;
  final Animation<double> auraScale;
  final Animation<double> auraOpacity;

  @override
  Widget build(BuildContext context) {
    final double frame   = 200 * scale;
    final double aura    = 160 * scale;
    final double icon    = 132 * scale;
    final double padIcon =  18 * scale;
    final double blur    =  32 * scale;
    final double spread  =   2 * scale;

    return SizedBox(
      width: frame,
      height: frame,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft expanding aura ring -- continuous loop. Wrapped in
          // RepaintBoundary so the looping repaint never invalidates
          // the icon layer above it.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: auraScale,
              builder: (_, _) => Opacity(
                opacity: auraOpacity.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: auraScale.value,
                  child: Container(
                    width: aura,
                    height: aura,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.6),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Icon -- one-shot fade + scale.
          FadeTransition(
            opacity: iconFade,
            child: ScaleTransition(
              scale: iconScale,
              child: Container(
                width: icon,
                height: icon,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: blur,
                      spreadRadius: spread,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(padIcon),
                  child: Image.asset(
                    'assets/app_icon/appicon.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.controller, required this.scale});

  final AnimationController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    const letters = ['A', 'T', 'O', 'M', 'U', 'S'];
    // Entrance duration range for wordmark is 0.45 to 0.85
    // Let's divide this 0.40 duration into staggered intervals for 6 letters.
    // Each letter will start 0.04 apart and take 0.20 to animate.
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(letters.length, (index) {
        final start = 0.45 + (index * 0.045);
        final end = (start + 0.20).clamp(0.0, 1.0);

        final fade = CurvedAnimation(
          parent: controller,
          curve: Interval(start, end, curve: Curves.easeOut),
        );

        final slide =
            Tween<Offset>(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: controller,
                curve: Interval(start, end, curve: Curves.easeOutBack),
              ),
            );

        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 5 * scale),
              child: Text(
                letters[index],
                style: TextStyle(
                  fontSize: 32 * scale,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1.0,
                  letterSpacing: 2.0 * scale,
                  shadows: const [
                    Shadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Thin animated underline that grows out from the centre under the
/// wordmark. Renders nothing until [progress] > 0 so it has no visual
/// weight during the icon's entrance.
class _Underline extends StatelessWidget {
  const _Underline({required this.progress, required this.scale});

  final Animation<double> progress;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, _) {
          final t = progress.value;
          return Opacity(
            opacity: t,
            child: Container(
              height: 2 * scale,
              width: 56 * scale * t,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.0),
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
