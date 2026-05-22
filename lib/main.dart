import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'theme/app_theme.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'screens/splash_screen.dart';

import 'app_bootstrap.dart';
import 'app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        return MaterialApp(
          title: 'Atomus',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeState.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

