import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> login(String username, String password) async {
    try {
      final isEmail = username.contains('@');
      
      final AuthResponse res;
      if (isEmail) {
        res = await _supabase.auth.signInWithPassword(
          email: username,
          password: password,
        );
      } else {
        // Supabase doesn't support phone login with password easily without phone auth setup
        // But if we have phone in parents table, we could fetch email first.
        // For now, assuming email login is primary as per Supabase standards.
        throw Exception('Please use your email to login.');
      }

      if (res.session != null) {
        print('Auth successful, checking parents table for: $username');
        // Validate against parents table
        final parentData = await _supabase
            .from('parents')
            .select()
            .eq('email', username)
            .maybeSingle();

        if (parentData == null) {
          print('User not found in parents table.');
          // If not in parents table, sign them out immediately
          await _supabase.auth.signOut();
          throw Exception('This account is not registered as an Atomus Parent.');
        }

        print('Parent validation successful.');
        return true;
      }
      return false;
    } on AuthException catch (e) {
      print('Login error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Login error: $e');
      if (e is Exception) rethrow;
      throw Exception('Authentication failed. Please check your credentials.');
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  Future<bool> isAuthenticated() async {
    final session = _supabase.auth.currentSession;
    return session != null && !session.isExpired;
  }

  Future<Map<String, String>> generatePatientCredentials() async {
    try {
      final random = Random();
      final String uniqueId = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
      final String randomSuffix = random.nextInt(9999).toString().padLeft(4, '0');
      
      final String generatedEmail = 'patient_${uniqueId}_$randomSuffix@atomus.com';
      
      const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
      String generatedPassword = '';
      for (int i = 0; i < 10; i++) {
        generatedPassword += chars[random.nextInt(chars.length)];
      }

      final AuthResponse res = await _supabase.auth.signUp(
        email: generatedEmail,
        password: generatedPassword,
        data: {
          'name': 'Patient $randomSuffix',
          'role': 'patient',
        },
      );

      if (res.user != null) {
        return {
          'email': generatedEmail,
          'password': generatedPassword,
        };
      } else {
        throw Exception('Failed to create patient account in Supabase.');
      }
    } on AuthException catch (e) {
      print('Signup error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Generate patient error: $e');
      throw Exception('Could not generate patient credentials.');
    }
  }
  Future<Map<String, String>> createParentWithEmail(String email) async {
    try {
      final random = Random();
      const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
      String generatedPassword = '';
      for (int i = 0; i < 10; i++) {
        generatedPassword += chars[random.nextInt(chars.length)];
      }

      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: generatedPassword,
        data: {
          'role': 'parent',
        },
      );

      if (res.user != null) {
        return {
          'email': email,
          'password': generatedPassword,
        };
      } else {
        throw Exception('Failed to create parent account in Supabase.');
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Could not create parent credentials.');
    }
  }
}
