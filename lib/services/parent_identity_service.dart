import 'package:supabase_flutter/supabase_flutter.dart';

class ParentIdentityService {
  ParentIdentityService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<Map<String, dynamic>> resolveCurrentParent() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User session not found. Please log in again.');
    }

    final checks = <({String column, String? value})>[
      (column: 'id', value: user.id),
      (column: 'auth_user_id', value: user.id),
      (column: 'auth_id', value: user.id),
      (column: 'email', value: user.email),
      (column: 'phone_number', value: user.phone),
      (column: 'username', value: user.phone),
    ];

    for (final check in checks) {
      final value = check.value?.trim();
      if (value == null || value.isEmpty) continue;
      final parent = await _tryResolve(check.column, value);
      if (parent != null) return parent;
    }

    throw Exception('This account is not linked to an Atomus parent profile.');
  }

  Future<Map<String, dynamic>?> _tryResolve(String column, String value) async {
    try {
      final parent = await _supabase
          .from('parents')
          .select()
          .eq(column, value)
          .maybeSingle();
      if (parent == null) return null;
      return Map<String, dynamic>.from(parent);
    } catch (_) {
      return null;
    }
  }
}
