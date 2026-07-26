import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'app_bootstrap.dart';
import 'app_providers.dart';
import 'blocs/connectivity/connectivity_cubit.dart';
import 'blocs/connectivity/connectivity_state.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'screens/splash_screen.dart';
import 'services/navigator_service.dart';
import 'services/password_recovery_service.dart';
import 'theme/app_theme.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // centralize all synchronous framework exceptions
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.critical(
      'FlutterError',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };

  // centralize all asynchronous uncaught runtime exceptions
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.critical(
      'PlatformDispatcher',
      'Uncaught asynchronous exception',
      error,
      stack,
    );
    return true; // Mark as handled
  };

  // Run structured, non-blocking asynchronous system bootstrap
  final bootstrap = AppBootstrap();
  final bootstrapResult = await bootstrap.bootstrap();

  runApp(
    AppProviders(bootstrapResult: bootstrapResult, child: const AtomusApp()),
  );
}

class AtomusApp extends StatelessWidget {
  const AtomusApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Eagerly instantiate PasswordRecoveryService to listen for deep link auth events
    context.read<PasswordRecoveryService>();

    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        return MaterialApp(
          navigatorKey: NavigatorService.navigatorKey,
          title: 'Atomus',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeState.themeMode,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: ConnectivityWrapper(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, state) {
        return Stack(
          children: [
            child,
            if (state.isOffline)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildOfflineBanner(context),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Material(
      key: const ValueKey('offline_banner'),
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.wifiOff,
                color: Colors.amber,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Mode Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Showing stored local data',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
