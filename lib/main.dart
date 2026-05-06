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
import 'screens/splash_screen.dart';

void main() {
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
        child: MaterialApp(
          title: 'Atomus',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
