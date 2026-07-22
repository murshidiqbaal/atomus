import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import '../../app_bootstrap.dart';
import '../../services/announcement_hive_service.dart';
import '../../services/course_hive_service.dart';
import '../../services/fee_hive_service.dart';
import '../../services/student_hive_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(const AuthState()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final isAuthenticated = await authRepository.isAuthenticated();
    if (isAuthenticated) {
      final savedRole = await authRepository.getSavedRole();
      final role = savedRole == LoginUserRole.teacher
          ? UserRole.teacher
          : UserRole.parent;
      emit(state.copyWith(status: AuthStatus.authenticated, userRole: role));
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));
    try {
      final loginRole = await authRepository.login(event.username, event.password);
      final role = loginRole == LoginUserRole.teacher
          ? UserRole.teacher
          : UserRole.parent;
      emit(AuthState(status: AuthStatus.authenticated, userRole: role));
    } catch (e) {
      emit(AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      ));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await Supabase.instance.client
            .from('device_tokens')
            .update({'is_active': false})
            .eq('device_token', fcmToken);
      }
    } catch (_) {}

    await authRepository.logout();

    // Clear all Hive caches
    try {
      final bootstrap = AppBootstrap();
      await Future.wait([
        bootstrap.teacherHiveService.clearAll(),
        bootstrap.hiveProfileCacheService.clearAll(),
        bootstrap.teacherProfileHiveService.clearAll(),
        FeeHiveService().clearAll(),
        StudentHiveService().clearAll(),
        AnnouncementHiveService().clearAll(),
        CourseHiveService().clearAll(),
      ]);
    } catch (e) {
      // ignore
    }

    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
