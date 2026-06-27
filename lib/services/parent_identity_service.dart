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

    final checks = <({String column, String value})>[];

    // 1. Direct ID matches (UUIDs)
    checks.add((column: 'id', value: user.id));
    checks.add((column: 'auth_user_id', value: user.id));
    checks.add((column: 'auth_id', value: user.id));

    // 2. Email match (case-insensitive via ilike in _tryResolve)
    if (user.email != null && user.email!.trim().isNotEmpty) {
      checks.add((column: 'email', value: user.email!.trim()));
    }

    // 3. Phone/Username match with variations
    if (user.phone != null && user.phone!.trim().isNotEmpty) {
      final phone = user.phone!.trim();
      final variations = <String>[phone];

      // Variation: without leading '+'
      if (phone.startsWith('+')) {
        variations.add(phone.substring(1));
      }

      // Variation: last 10 digits for local format
      final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length >= 10) {
        final last10 = digitsOnly.substring(digitsOnly.length - 10);
        if (!variations.contains(last10)) {
          variations.add(last10);
        }
      }

      for (final variation in variations) {
        checks.add((column: 'phone_number', value: variation));
        checks.add((column: 'username', value: variation));
      }
    }

    for (final check in checks) {
      final parent = await _tryResolve(check.column, check.value);
      if (parent != null) return parent;
    }

    throw Exception('This account is not linked to an Atomus parent profile.');
  }

  Future<Map<String, dynamic>?> _tryResolve(String column, String value) async {
    try {
      final isTextColumn = column == 'email' ||
          column == 'phone_number' ||
          column == 'username';
      final query = _supabase.from('parents').select();
      final parent = await (isTextColumn
              ? query.ilike(column, value)
              : query.eq(column, value))
          .maybeSingle();
      if (parent == null) return null;
      return Map<String, dynamic>.from(parent);
    } catch (_) {
      return null;
    }
  }
}
