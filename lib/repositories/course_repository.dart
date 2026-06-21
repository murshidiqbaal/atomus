import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dummy_data.dart';

class CourseRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Course>> getCourses() async {
    try {
      final response = await _supabase
          .from('courses')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => Course.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching courses: $e');
      return [];
    }
  }

  Future<List<Subject>> getSubjects(String courseId) async {
    try {
      final response = await _supabase
          .from('subjects')
          .select()
          .eq('course_id', courseId)
          .eq('is_active', true)
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => Subject.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching subjects: $e');
      return [];
    }
  }
}
