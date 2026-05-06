import 'dart:async';

class AuthRepository {
  Future<bool> login(String username, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    return true; // Always succeed for demo
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<bool> isAuthenticated() async {
    return false; // Initially not authenticated
  }
}
