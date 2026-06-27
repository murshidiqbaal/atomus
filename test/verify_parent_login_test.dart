import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atomus/services/parent_identity_service.dart';
import 'package:atomus/repositories/auth_repository.dart';

void main() {
  setUpAll(() async {
    // Initialize Supabase client
    try {
      SharedPreferences.setMockInitialValues({});
      await Supabase.initialize(
        url: 'https://txtvvlxaurqovghtngzm.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
      );
    } catch (_) {
      // already initialized
    }
  });

  test('Verify case-insensitive parent login and auto-linking', () async {
    print('=== STARTING PARENT LOGIN VERIFICATION TEST ===');
    final supabase = Supabase.instance.client;
    final authRepository = AuthRepository();

    // Reset Farhan Khan auth fields in DB first
    const farhanEmail = 'farhan.parent@email.com';
    print('\n--- resetting Farhan Khan auth fields in DB ---');
    try {
      await supabase
          .from('parents')
          .update({
            'auth_user_id': null,
            'auth_id': null,
          })
          .eq('email', farhanEmail);
      print('Reset successful.');
    } catch (e) {
      print('Reset error: $e');
    }

    // Sign in with mixed-case email
    const loginEmail = 'Farhan.Parent@email.com';
    const password = '79900000';
    print('\n--- signing in with mixed-case email: $loginEmail ---');
    
    // Log out first to ensure clean state
    try {
      await supabase.auth.signOut();
    } catch (_) {}

    final role = await authRepository.login(loginEmail, password);
    print('Login returned role: $role');
    expect(role, LoginUserRole.parent);

    // Verify parent is linked correctly in the DB
    final user = supabase.auth.currentUser;
    expect(user, isNotNull);
    print('Logged in user ID: ${user!.id}');

    final updatedParent = await supabase
        .from('parents')
        .select()
        .eq('email', farhanEmail)
        .single();

    print('Updated Parent Profile in DB:');
    print('  - id: ${updatedParent['id']}');
    print('  - email: ${updatedParent['email']}');
    print('  - auth_user_id: ${updatedParent['auth_user_id']}');
    print('  - auth_id: ${updatedParent['auth_id']}');

    expect(updatedParent['auth_user_id'], user.id);
    expect(updatedParent['auth_id'], user.id);

    print('\n[SUCCESS] Parent Verification completed successfully!');
  });

  test('Verify case-insensitive teacher login and auto-linking', () async {
    print('=== STARTING TEACHER LOGIN VERIFICATION TEST ===');
    final supabase = Supabase.instance.client;
    final authRepository = AuthRepository();

    // Reset Murshi (teacher) auth fields in DB first
    const teacherEmail = 'murshidiqbaalkm10@gmail.com';
    print('\n--- resetting Murshi auth fields in DB ---');
    try {
      await supabase
          .from('teachers')
          .update({
            'auth_id': null,
          })
          .eq('email', teacherEmail);
      print('Reset successful.');
    } catch (e) {
      print('Reset error: $e');
    }

    // Sign in with mixed-case email
    const loginEmail = 'MurshidIqbaalKM10@gmail.com';
    const password = 'HelloWorld';
    print('\n--- signing in with mixed-case email: $loginEmail ---');
    
    // Log out first to ensure clean state
    try {
      await supabase.auth.signOut();
    } catch (_) {}

    final role = await authRepository.login(loginEmail, password);
    print('Login returned role: $role');
    expect(role, LoginUserRole.teacher);

    // Verify teacher is linked correctly in the DB
    final user = supabase.auth.currentUser;
    expect(user, isNotNull);
    print('Logged in user ID: ${user!.id}');

    final updatedTeacher = await supabase
        .from('teachers')
        .select()
        .eq('email', teacherEmail)
        .single();

    print('Updated Teacher Profile in DB:');
    print('  - id: ${updatedTeacher['id']}');
    print('  - email: ${updatedTeacher['email']}');
    print('  - auth_id: ${updatedTeacher['auth_id']}');

    expect(updatedTeacher['auth_id'], user.id);

    print('\n[SUCCESS] Teacher Verification completed successfully!');
  });
}
