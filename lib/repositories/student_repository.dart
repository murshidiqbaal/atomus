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

  Future<List<ExamSession>> getExamSessions(String studentId) async {
    try {
      // Fetch marks for the student, joining with exam details and subject names
      // Relationship: marks.exam_id -> exams.id
      // Relationship: marks.subject_id -> subjects.id
      final response = await _supabase
          .from('marks')
          .select('''
            *,
            exams (
              name,
              exam_date
            ),
            subjects (
              name
            )
          ''')
          .eq('student_id', studentId);

      final List<dynamic> data = response as List<dynamic>;
      
      // Group results by exam title/name to merge different exam entries representing the same exam session (e.g. uploaded by admin & teacher separately)
      final Map<String, List<ExamMark>> mergedMarksByExamName = {};
      final Map<String, Map<String, dynamic>> examDetailsByExamName = {};

      for (var item in data) {
        final examData = item['exams'] ?? item;
        final examName = (examData['name'] ?? examData['title'] ?? 'Examination').toString().trim();
        final examKey = examName.toLowerCase(); // Case-insensitive merge key
        
        if (!mergedMarksByExamName.containsKey(examKey)) {
          mergedMarksByExamName[examKey] = [];
          examDetailsByExamName[examKey] = item;
        }
        
        final newMark = ExamMark.fromMap(item);
        final subjectKey = newMark.subject.trim().toLowerCase();
        
        // Check if this subject is already uploaded for this merged exam session (e.g., duplicate upload by admin & teacher)
        final existingIndex = mergedMarksByExamName[examKey]!.indexWhere(
          (m) => m.subject.trim().toLowerCase() == subjectKey
        );
        
        if (existingIndex >= 0) {
          final existingMark = mergedMarksByExamName[examKey]![existingIndex];
          // Keep the record with the higher marks
          if (newMark.marksObtained > existingMark.marksObtained) {
            mergedMarksByExamName[examKey]![existingIndex] = newMark;
          }
        } else {
          mergedMarksByExamName[examKey]!.add(newMark);
        }
      }

      return mergedMarksByExamName.entries.map((entry) {
        return ExamSession.fromMap(examDetailsByExamName[entry.key]!, entry.value);
      }).toList();
    } catch (e) {
      print('Error fetching exam sessions: $e');
      return [];
    }
  }

  Future<List<AttendanceRecord>> getAttendance({
    String? studentId,
    String? batchId,
    String? courseId,
    String? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from('attendance').select();

      if (studentId != null) query = query.eq('student_id', studentId);
      if (batchId != null) query = query.eq('batch_id', batchId);
      if (courseId != null) query = query.eq('course_id', courseId);
      if (subjectId != null) query = query.eq('subject_id', subjectId);
      
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

  /// Fetches stored student performance from the student_academic_performance table
  Future<Map<String, dynamic>?> getStudentPerformanceFromDb(String studentId) async {
    try {
      final response = await _supabase
          .from('student_academic_performance')
          .select()
          .eq('student_id', studentId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching student performance from DB: $e');
      return null;
    }
  }
}
