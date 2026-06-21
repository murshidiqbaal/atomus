import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../screens/reset_password_screen.dart';
import '../utils/logger.dart';

class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

class PasswordRecoveryService {
  final AuthRepository _authRepository;
  StreamSubscription<AuthState>? _recoverySubscription;
  bool _isNavigating = false;

  PasswordRecoveryService({required AuthRepository authRepository})
      : _authRepository = authRepository;

  void initialize() {
    AppLogger.info('PasswordRecoveryService', 'Initializing password recovery listener...');
    _recoverySubscription?.cancel();
    _recoverySubscription = _authRepository.listenPasswordRecovery((event, session) {
      AppLogger.info('PasswordRecoveryService', 'Password recovery event received: $event');
      _handleRecoveryEvent();
    });
  }

  void _handleRecoveryEvent() {
    if (_isNavigating) return;
    _isNavigating = true;
    _tryNavigate();
  }

  void _tryNavigate() {
    final context = NavigatorService.navigatorKey.currentContext;
    if (context != null) {
      AppLogger.info('PasswordRecoveryService', 'Navigator context ready. Pushing ResetPasswordScreen.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        (route) => false,
      );
      _isNavigating = false;
    } else {
      AppLogger.warning('PasswordRecoveryService', 'Navigator context not ready yet. Retrying in 100ms...');
      Future.delayed(const Duration(milliseconds: 100), _tryNavigate);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    AppLogger.info('PasswordRecoveryService', 'Requesting password reset for: $email');
    await _authRepository.sendPasswordResetEmail(email);
  }

  Future<void> updatePassword(String newPassword) async {
    AppLogger.info('PasswordRecoveryService', 'Updating password...');
    await _authRepository.updatePassword(newPassword);
    AppLogger.info('PasswordRecoveryService', 'Password updated successfully. Logging out.');
    await _authRepository.logout();
  }

  void dispose() {
    AppLogger.info('PasswordRecoveryService', 'Disposing password recovery service...');
    _recoverySubscription?.cancel();
  }
}
