import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'theme/app_theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/student_repository.dart';
import 'repositories/fee_repository.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/auth/auth_event.dart';
import 'blocs/student/student_bloc.dart';
import 'blocs/fee/fee_bloc.dart';
import 'blocs/theme/theme_bloc.dart';
import 'blocs/theme/theme_state.dart';
import 'screens/splash_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: SupabaseConstants.url,
    anonKey: SupabaseConstants.anonKey,
  );

  runApp(const AtomusApp());
}

class AtomusApp extends StatelessWidget {
  const AtomusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
        RepositoryProvider(create: (_) => StudentRepository()),
        RepositoryProvider(create: (_) => FeeRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => ThemeBloc()),
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            )..add(AppStarted()),
          ),
          BlocProvider(
            create: (context) => StudentBloc(
              studentRepository: context.read<StudentRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => FeeBloc(
              feeRepository: context.read<FeeRepository>(),
            ),
          ),
        ],
        child: BlocBuilder<ThemeBloc, ThemeState>(
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
        ),
      ),
    );
  }
}
