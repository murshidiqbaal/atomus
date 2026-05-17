import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _authKey = 'is_logged_in';

  Future<void> _setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, value);
  }

  Future<bool> _getLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }

  Future<bool> login(String identifier, String password) async {
    try {
      final isEmail = identifier.contains('@');
      final isPhone = !isEmail && RegExp(r'^\+?[0-9]{7,15}$').hasMatch(identifier);
      
      final AuthResponse res;
      String filterField;
      String filterValue = identifier;

      if (isEmail) {
        res = await _supabase.auth.signInWithPassword(
          email: identifier,
          password: password,
        );
        filterField = 'email';
      } else if (isPhone) {
        // Normalize phone number: Ensure it starts with + if it's a phone
        if (!identifier.startsWith('+')) {
          // You might want to add a default country code here if needed
          // For now, assuming user enters it or it's handled by Supabase
          filterValue = identifier; 
        }
        res = await _supabase.auth.signInWithPassword(
          phone: identifier,
          password: password,
        );
        filterField = 'phone';
      } else {
        throw Exception('Please enter a valid email or phone number.');
      }

      if (res.session != null) {
        print('Auth successful, checking parents table for: $identifier');
        // Validate against parents table
        final parentData = await _supabase
            .from('parents')
            .select()
            .eq(filterField, filterValue)
            .maybeSingle();

        if (parentData == null) {
          print('User not found in parents table.');
          // If not in parents table, sign them out immediately
          await _supabase.auth.signOut();
          throw Exception('This account is not registered as an Atomus Parent.');
        }

        print('Parent validation successful.');
        await _setLoggedIn(true);
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
      await _setLoggedIn(false);
    } catch (e) {
      print('Logout error: $e');
    }
  }

  Future<bool> isAuthenticated() async {
    final hasFlag = await _getLoggedIn();
    final session = _supabase.auth.currentSession;
    final isValidSession = session != null && !session.isExpired;
    
    // Return true only if both flag and session are valid
    // This adds an extra layer of security/check for the gateway
    return hasFlag && isValidSession;
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

  Future<Map<String, String>> createParentWithPhone(String phone) async {
    try {
      final random = Random();
      const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%^&*';
      String generatedPassword = '';
      for (int i = 0; i < 10; i++) {
        generatedPassword += chars[random.nextInt(chars.length)];
      }

      final AuthResponse res = await _supabase.auth.signUp(
        phone: phone,
        password: generatedPassword,
        data: {
          'role': 'parent',
        },
      );

      if (res.user != null) {
        return {
          'phone': phone,
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
