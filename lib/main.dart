import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'theme/app_theme.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'screens/splash_screen.dart';
import 'utils/logger.dart';

import 'app_bootstrap.dart';
import 'app_providers.dart';
import 'services/password_recovery_service.dart';
import 'blocs/connectivity/connectivity_cubit.dart';
import 'blocs/connectivity/connectivity_state.dart';
import 'screens/no_internet_screen.dart';

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
    AppProviders(
      bootstrapResult: bootstrapResult,
      child: const AtomusApp(),
    ),
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
          builder: (context, child) => ConnectivityWrapper(child: child ?? const SizedBox.shrink()),
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
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: state.isOffline
                  ? const PopScope(
                      canPop: false,
                      key: ValueKey('no_internet_screen'),
                      child: NoInternetScreen(),
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('online_placeholder'),
                    ),
            ),
          ],
        );
      },
    );
  }
}

