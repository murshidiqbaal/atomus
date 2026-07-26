import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dummy_data.dart';
import '../services/course_hive_service.dart';

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
      final mapList = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await CourseHiveService().saveCourses(mapList);

      return data.map((item) => Course.fromMap(item)).toList();
    } catch (e) {
      print('NOTICE [getCourses offline fallback]: $e');
      final cached = CourseHiveService().getCachedCourses(allowStale: true);
      if (cached != null) {
        return cached.map((item) => Course.fromMap(item)).toList();
      }
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
      final mapList = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await CourseHiveService().saveSubjects(courseId, mapList);

      return data.map((item) => Subject.fromMap(item)).toList();
    } catch (e) {
      print('NOTICE [getSubjects offline fallback]: $e');
      final cached = CourseHiveService().getCachedSubjects(courseId, allowStale: true);
      if (cached != null) {
        return cached.map((item) => Subject.fromMap(item)).toList();
      }
      return [];
    }
  }
}
