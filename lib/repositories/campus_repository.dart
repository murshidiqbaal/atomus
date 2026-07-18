import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campus_model.dart';

class CampusRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Campus>> fetchAllCampuses() async {
    try {
      final response = await _supabase.from('campuses').select('*');
      final list = response as List;
      return list.map((c) => Campus.fromMap(c as Map<String, dynamic>)).toList();
    } catch (e) {
      print('CampusRepository: Error fetching all campuses: $e');
      return [];
    }
  }

  Future<List<Campus>> fetchCampusesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _supabase
          .from('campuses')
          .select('*')
          .inFilter('id', ids);
      final list = response as List;
      return list.map((c) => Campus.fromMap(c as Map<String, dynamic>)).toList();
    } catch (e) {
      print('CampusRepository: Error fetching campuses by ids: $e');
      return [];
    }
  }
}
