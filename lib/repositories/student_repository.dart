import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dummy_data.dart';

class StudentRepository {
  final _supabase = Supabase.instance.client;

  Future<StudentInfo?> getStudentInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null)
        throw Exception('User session not found. Please log in again.');

      print('Fetching linked student for Parent Auth ID: ${user.id}');

      // Fetch the student record linked to this parent
      // Relationship: students.parent_id -> parents.id
      final studentData = await _supabase
          .from('students')
          .select('''
            *,
            parents!inner (
              id,
              full_name,
              phone_number,
              email
            )
          ''')
          .eq('parent_id', user.id)
          .maybeSingle();

      if (studentData == null) {
        print('NOTICE: No student record found linked to this parent (Auth ID: ${user.id}).');
        return null;
      }

      print('Successfully fetched student: ${studentData['full_name']}');
      return StudentInfo.fromMap(studentData);
    } catch (e) {
      print('CRITICAL ERROR [getStudentInfo]: $e');
      rethrow;
    }
  }

  Future<void> updateStudent(StudentInfo student) async {
    try {
      await _supabase
          .from('students')
          .update(student.toMap())
          .eq('id', student.id);
    } catch (e) {
      print('Error updating student: $e');
      throw Exception('Failed to update profile details.');
    }
  }

  Future<List<ExamSession>> getExamSessions() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return DummyData.exams;
  }

  Future<List<AttendanceRecord>> getAttendance({
    String? studentId,
    String? batchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('attendance').select();

      if (studentId != null) query = query.eq('student_id', studentId);
      if (batchId != null) query = query.eq('batch_id', batchId);
      
      if (startDate != null) {
        query = query.gte('attendance_date', startDate.toIso8601String().split('T')[0]);
      }
      if (endDate != null) {
        query = query.lte('attendance_date', endDate.toIso8601String().split('T')[0]);
      }

      final response = await query.order('attendance_date', ascending: false);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => AttendanceRecord.fromMap(item)).toList();
    } catch (e) {
      print('Error fetching attendance: $e');
      // Fallback to empty list or handle as needed
      return [];
    }
  }
}
