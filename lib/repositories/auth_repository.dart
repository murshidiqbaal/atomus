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
        final currentAuthId = teacherRole['auth_id'] as String?;
        final user = _supabase.auth.currentUser;
        if (user != null && (currentAuthId == null || currentAuthId != user.id)) {
          try {
            await _supabase
                .from('teachers')
                .update({'auth_id': user.id})
                .eq('id', teacherId);
          } catch (e) {
            print('Error linking auth_id to teacher: $e');
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
        final parentId = parentData['id'] as String;
        final currentAuthUserId = parentData['auth_user_id'] as String?;
        final currentAuthId = parentData['auth_id'] as String?;
        final user = _supabase.auth.currentUser;
        if (user != null &&
            (currentAuthUserId == null || currentAuthUserId != user.id ||
             currentAuthId == null || currentAuthId != user.id)) {
          try {
            await _supabase
                .from('parents')
                .update({
                  'auth_user_id': user.id,
                  'auth_id': user.id,
                })
                .eq('id', parentId);
          } catch (e) {
            print('Error linking auth_user_id/auth_id to parent: $e');
          }
        }

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

      final checks = <({String column, String value})>[];

      // 1. Direct ID matches (UUIDs)
      checks.add((column: 'auth_id', value: uid));
      checks.add((column: 'id', value: uid));

      // 2. Email match (case-insensitive via ilike)
      if (email != null && email.trim().isNotEmpty) {
        checks.add((column: 'email', value: email.trim()));
      }

      // 3. Phone number match with variations (case-insensitive via ilike)
      if (phone != null && phone.trim().isNotEmpty) {
        final trimmedPhone = phone.trim();
        final variations = <String>[trimmedPhone];

        // Variation: without leading '+'
        if (trimmedPhone.startsWith('+')) {
          variations.add(trimmedPhone.substring(1));
        }

        // Variation: last 10 digits
        final digitsOnly = trimmedPhone.replaceAll(RegExp(r'\D'), '');
        if (digitsOnly.length >= 10) {
          final last10 = digitsOnly.substring(digitsOnly.length - 10);
          if (!variations.contains(last10)) {
            variations.add(last10);
          }
        }

        for (final variation in variations) {
          checks.add((column: 'phone_number', value: variation));
        }
      }

      for (final check in checks) {
        try {
          final isTextColumn = check.column == 'email' || check.column == 'phone_number';
          final query = _supabase.from('teachers').select('id, full_name, email, auth_id');
          final rows = await (isTextColumn
                  ? query.ilike(check.column, check.value)
                  : query.eq(check.column, check.value))
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
    if (!hasFlag) return false;

    final session = _supabase.auth.currentSession;
    if (session == null) return false;

    // If the access token is expired, attempt to refresh the session.
    if (session.isExpired) {
      try {
        final res = await _supabase.auth.refreshSession();
        return res.session != null;
      } on AuthException catch (_) {
        // The session is invalid/revoked (e.g. password changed elsewhere).
        // Clear flag and sign out so the user goes back to the login screen.
        try {
          await _supabase.auth.signOut();
          await _setLoggedIn(false);
        } catch (_) {}
        return false;
      } catch (_) {
        // Any other exception (like network connection failure) should not prevent
        // the user from entering the dashboard to see cached offline data.
        return true;
      }
    }

    return true;
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
