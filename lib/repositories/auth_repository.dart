import 'dart:async';
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
        res = await _supabase.auth.signInWithPassword(
          phone: username,
          password: password,
        );
      }
      return res.session != null;
    } on AuthException catch (e) {
      print('Login error: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      print('Login error: $e');
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
}
