import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dummy_data.dart';
import '../services/parent_identity_service.dart';
import '../services/student_hive_service.dart';
import '../services/student_performance_service.dart';

class StudentRepository {
  final _supabase = Supabase.instance.client;
  final _parentIdentityService = ParentIdentityService();

  Future<StudentInfo?> getStudentInfo([String? parentId]) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        final cached = StudentHiveService().getCachedStudentInfo(allowStale: true);
        if (cached != null) return StudentInfo.fromMap(cached);
        return null;
      }

      final String resolvedParentId;
      if (parentId != null) {
        resolvedParentId = parentId;
      } else {
        final parent = await _parentIdentityService.resolveCurrentParent();
        resolvedParentId = parent['id']?.toString() ?? '';
      }

      print('Fetching linked student for Parent ID: $resolvedParentId');

      final studentData = await _supabase
          .from('students')
          .select('''
            *,
            parents!inner (
              id,
              full_name,
              phone_number,
              email
            ),
            campuses (
              id,
              name,
              payment_qr_url,
              payment_qr_drive_id
            )
          ''')
          .eq('parent_id', resolvedParentId)
          .maybeSingle();

      if (studentData == null) {
        final cached = StudentHiveService().getCachedStudentInfo(allowStale: true);
        if (cached != null) return StudentInfo.fromMap(cached);
        return null;
      }

      print('Successfully fetched student: ${studentData['full_name']}');
      await StudentHiveService().saveStudentInfo(studentData);
      return StudentInfo.fromMap(studentData);
    } catch (e) {
      print('NOTICE [getStudentInfo offline fallback]: $e');
      final cached = StudentHiveService().getCachedStudentInfo(allowStale: true);
      if (cached != null) {
        return StudentInfo.fromMap(cached);
      }
      return null;
    }
  }

  Future<void> updateStudent(StudentInfo student) async {
    try {
      final parent = await _parentIdentityService.resolveCurrentParent();
      await _supabase
          .from('students')
          .update(student.toMap())
          .eq('id', student.id)
          .eq('parent_id', parent['id'].toString());
    } catch (e) {
      print('Error updating student: $e');
      throw Exception('Failed to update profile details.');
    }
  }

  Future<List<ExamSession>> getExamSessions(String studentId) async {
    try {
      final response = await _supabase
          .from('marks')
          .select('''
            *,
            exams (
              name,
              exam_date,
              is_daily
            ),
            subjects (
              name
            )
          ''')
          .eq('student_id', studentId);

      final List<dynamic> data = response as List<dynamic>;

      // Cache raw exams data to Hive
      final rawExams = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await StudentHiveService().saveExamSessions(rawExams);

      return _processExamSessions(data);
    } catch (e) {
      print('NOTICE [getExamSessions offline fallback]: $e');
      final cachedData = StudentHiveService().getCachedExamSessions(allowStale: true);
      if (cachedData != null && cachedData.isNotEmpty) {
        return _processExamSessions(cachedData);
      }
      return [];
    }
  }

  List<ExamSession> _processExamSessions(List<dynamic> data) {
    final Map<String, List<ExamMark>> mergedMarksByExamName = {};
    final Map<String, Map<String, dynamic>> examDetailsByExamName = {};

    for (var item in data) {
      final examData = item['exams'] ?? item;
      final examName =
          (examData['name'] ?? examData['title'] ?? 'Examination')
              .toString()
              .trim();
      final isDaily = examData['is_daily'] as bool? ?? false;
      final markDate = item['mark_date'] as String? ?? '';

      final examKey = isDaily
          ? '${examName.toLowerCase()}_$markDate'
          : examName.toLowerCase();

      if (!mergedMarksByExamName.containsKey(examKey)) {
        mergedMarksByExamName[examKey] = [];
        examDetailsByExamName[examKey] = Map<String, dynamic>.from(item as Map);
      }

      final newMark = ExamMark.fromMap(Map<String, dynamic>.from(item as Map));
      final subjectKey = newMark.subject.trim().toLowerCase();

      final existingIndex = mergedMarksByExamName[examKey]!.indexWhere(
        (m) => m.subject.trim().toLowerCase() == subjectKey,
      );

      if (existingIndex >= 0) {
        final existingMark = mergedMarksByExamName[examKey]![existingIndex];
        if (newMark.marksObtained > existingMark.marksObtained) {
          mergedMarksByExamName[examKey]![existingIndex] = newMark;
        }
      } else {
        mergedMarksByExamName[examKey]!.add(newMark);
      }
    }

    return mergedMarksByExamName.entries.map((entry) {
      return ExamSession.fromMap(
        examDetailsByExamName[entry.key]!,
        entry.value,
      );
    }).toList();
  }

  Future<List<AttendanceRecord>> getAttendance({
    String? studentId,
    String? batchId,
    String? courseId,
    String? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final key = '${studentId ?? "all"}_${batchId ?? ""}_${courseId ?? ""}';
    try {
      var query = _supabase.from('attendance').select('''
        *,
        subjects (
          name
        )
      ''');

      if (studentId != null) query = query.eq('student_id', studentId);
      if (batchId != null) query = query.eq('batch_id', batchId);
      if (courseId != null) query = query.eq('course_id', courseId);
      if (subjectId != null) query = query.eq('subject_id', subjectId);

      if (startDate != null) {
        query = query.gte(
          'attendance_date',
          startDate.toIso8601String().split('T')[0],
        );
      }
      if (endDate != null) {
        query = query.lte(
          'attendance_date',
          endDate.toIso8601String().split('T')[0],
        );
      }

      final response = await query.order('attendance_date', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      // Cache raw attendance records to Hive
      final rawList = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await StudentHiveService().saveAttendance(key, rawList);

      return _processAttendanceRecords(data);
    } catch (e) {
      print('NOTICE [getAttendance offline fallback]: $e');
      final cached = StudentHiveService().getCachedAttendance(key, allowStale: true);
      if (cached != null && cached.isNotEmpty) {
        return _processAttendanceRecords(cached);
      }
      return [];
    }
  }

  List<AttendanceRecord> _processAttendanceRecords(List<dynamic> data) {
    final List<AttendanceRecord> records = data
        .map((item) => AttendanceRecord.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    final Map<String, AttendanceRecord> uniqueRecords = {};
    for (final record in records) {
      final dateKey =
          '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
      final sessionKey = record.sessionType ?? 'null';
      final periodKey = record.periodNumber?.toString() ?? 'null';
      final subjectKey = record.subjectId ?? 'null';
      final key = '${dateKey}_${sessionKey}_${periodKey}_$subjectKey';

      if (!uniqueRecords.containsKey(key)) {
        uniqueRecords[key] = record;
      } else {
        final existing = uniqueRecords[key]!;
        final recordWeight = StudentPerformanceService.getAttendanceWeight(
          record.status,
        );
        final existingWeight = StudentPerformanceService.getAttendanceWeight(
          existing.status,
        );
        if (recordWeight > existingWeight) {
          uniqueRecords[key] = record;
        }
      }
    }

    return uniqueRecords.values.toList();
  }

  /// Fetches stored student performance from the student_academic_performance table
  Future<Map<String, dynamic>?> getStudentPerformanceFromDb(
    String studentId,
  ) async {
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
