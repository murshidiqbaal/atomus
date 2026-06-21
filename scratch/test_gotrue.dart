import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // Check if we can reference these methods and classes
  final client = Supabase.instance.client;

  // Checking resetPasswordForEmail
  Future<void> Function(String, {String? redirectTo})? _ =
      client.auth.resetPasswordForEmail;

  // Checking updateUser
  Future<UserResponse> Function(UserAttributes)? _ = client.auth.updateUser;

  print("Compile check successful");
}
