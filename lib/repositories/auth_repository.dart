import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/parent_identity_service.dart';

enum LoginUserRole { parent, teacher }

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ParentIdentityService _parentIdentityService = ParentIdentityService();
  static const String _authKey    = 'is_logged_in';
  static const String _roleKey    = 'user_role';

  Future<void> _setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, value);
  }

  Future<bool> _getLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }

  Future<void> _saveRole(LoginUserRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role == LoginUserRole.teacher ? 'teacher' : 'parent');
  }

  Future<LoginUserRole> getSavedRole() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_roleKey) ?? 'parent';
    return saved == 'teacher' ? LoginUserRole.teacher : LoginUserRole.parent;
  }

  // Returns LoginUserRole on success, throws on failure.
  Future<LoginUserRole> login(String identifier, String password) async {
    try {
      final isEmail = identifier.contains('@');
      final isPhone = !isEmail && RegExp(r'^\+?[0-9]{7,15}$').hasMatch(identifier);

      final AuthResponse res;
      if (isEmail) {
        res = await _supabase.auth.signInWithPassword(
          email: identifier, password: password,
        );
      } else if (isPhone) {
        res = await _supabase.auth.signInWithPassword(
          phone: identifier, password: password,
        );
      } else {
        throw Exception('Please enter a valid email or phone number.');
      }

      if (res.session == null) throw Exception('Authentication failed.');

      // 1. Check teachers table first
      final teacherRole = await _resolveTeacher();
      if (teacherRole != null) {
        final teacherId = teacherRole['id'] as String;
        final currentAuthId = teacherRole['auth_user_id'] as String?;
        final user = _supabase.auth.currentUser;
        if (user != null && (currentAuthId == null || currentAuthId != user.id)) {
          try {
            await _supabase
                .from('teachers')
                .update({'auth_user_id': user.id})
                .eq('id', teacherId);
          } catch (e) {
            print('Error linking auth_user_id to teacher: $e');
          }
        }

        await _setLoggedIn(true);
        await _saveRole(LoginUserRole.teacher);
        return LoginUserRole.teacher;
      }

      // 2. Fall back to parents table
      Map<String, dynamic>? parentData;
      try {
        parentData = await _parentIdentityService.resolveCurrentParent();
      } catch (_) {
        parentData = null;
      }

      if (parentData != null) {
        await _setLoggedIn(true);
        await _saveRole(LoginUserRole.parent);
        return LoginUserRole.parent;
      }

      await _supabase.auth.signOut();
      throw Exception('This account is not registered in Atomus.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Authentication failed. Please check your credentials.');
    }
  }

  Future<Map<String, dynamic>?> _resolveTeacher() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final email = user.email;
      final phone = user.phone;
      final uid   = user.id;

      // Try multiple columns just like ParentIdentityService does
      for (final col in ['auth_user_id', 'id', 'email', 'phone_number']) {
        final val = col == 'email'   ? email
                  : col == 'phone_number' ? phone
                  : uid;
        if (val == null) continue;
        try {
          final rows = await _supabase
              .from('teachers')
              .select('id, full_name, email, auth_user_id')
              .eq(col, val)
              .limit(1);
          if (rows.isNotEmpty) return rows.first;
        } catch (_) {}
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      await _setLoggedIn(false);
    } catch (e) {
      // ignore logout errors silently
    }
  }

  Future<bool> isAuthenticated() async {
    final hasFlag = await _getLoggedIn();
    final session = _supabase.auth.currentSession;
    final isValidSession = session != null && !session.isExpired;
    return hasFlag && isValidSession;
  }

  // ── Parent account creation helpers (unchanged) ─────────────

  Future<Map<String, String>> generatePatientCredentials() async {
    try {
      final random = Random();
      final String uniqueId =
          DateTime.now().millisecondsSinceEpoch.toString().substring(5);
      final String randomSuffix =
          random.nextInt(9999).toString().padLeft(4, '0');
      final String generatedEmail = 'patient_${uniqueId}_$randomSuffix@atomus.com';
      const String chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
      String generatedPassword = '';
      for (int i = 0; i < 10; i++) {
        generatedPassword += chars[random.nextInt(chars.length)];
      }
      final AuthResponse res = await _supabase.auth.signUp(
        email: generatedEmail,
        password: generatedPassword,
        data: {'name': 'Patient $randomSuffix', 'role': 'patient'},
      );
      if (res.user != null) {
        return {'email': generatedEmail, 'password': generatedPassword};
      }
      throw Exception('Failed to create patient account in Supabase.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Could not generate patient credentials.');
    }
  }

  Future<Map<String, String>> createParentWithEmail(String email) async {
    try {
      final random = Random();
      const String chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
      String generatedPassword = '';
      for (int i = 0; i < 10; i++) {
        generatedPassword += chars[random.nextInt(chars.length)];
      }
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: generatedPassword,
        data: {'role': 'parent'},
      );
      if (res.user != null) {
        return {'email': email, 'password': generatedPassword};
      }
      throw Exception('Failed to create parent account in Supabase.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Could not create parent credentials.');
    }
  }

  Future<Map<String, String>> createParentWithPhone(String phone) async {
    try {
      final random = Random();
      const String chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
      String generatedPassword = '';
      for (int i = 0; i < 10; i++) {
        generatedPassword += chars[random.nextInt(chars.length)];
      }
      final AuthResponse res = await _supabase.auth.signUp(
        phone: phone,
        password: generatedPassword,
        data: {'role': 'parent'},
      );
      if (res.user != null) {
        return {'phone': phone, 'password': generatedPassword};
      }
      throw Exception('Failed to create parent account in Supabase.');
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Could not create parent credentials.');
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'atomus://reset-password',
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to send password reset email.');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to update password.');
    }
  }

  StreamSubscription<AuthState> listenPasswordRecovery(
      void Function(AuthChangeEvent event, Session? session) callback) {
    return _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        callback(data.event, data.session);
      }
    });
  }
}
