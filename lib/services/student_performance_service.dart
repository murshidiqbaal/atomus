import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dummy_data.dart';
import '../models/student_performance_model.dart';

class StudentPerformanceService {
  static final _supabase = Supabase.instance.client;

  /// Returns the weight of an attendance status
  static double getAttendanceWeight(String status) {
    switch (status.trim().toLowerCase()) {
      case 'present':
        return 1.0;
      case 'late':
        return 0.75;
      case 'leave':
        return 0.50;
      case 'absent':
        return 0.0;
      default:
        return -1.0; // Indicates unmarked or ignored
    }
  }

  /// Fetches raw data from Supabase, calculates metrics, computes ranking,
  /// upserts records in 'student_academic_performance', and returns the performance model.
  static Future<StudentAcademicPerformanceModel> calculateAndStorePerformance(
    String studentId,
  ) async {
    try {
      // 1. Fetch Student Details
      final studentData = await _supabase
          .from('students')
          .select('campus_id, course_id, batch_id')
          .eq('id', studentId)
          .maybeSingle();

      if (studentData == null) {
        throw Exception('Student not found in database for ID: $studentId');
      }

      final campusId = studentData['campus_id'] as String?;
      final courseId = studentData['course_id'] as String?;
      final batchId = studentData['batch_id'] as String?;

      // 2. Fetch Attendance Records (dual-table fallback strategy)
      // Check subject_attendance first as per core requirement
      List<dynamic> attendanceRecords = [];
      try {
        attendanceRecords = await _supabase
            .from('subject_attendance')
            .select()
            .eq('student_id', studentId);
      } catch (e) {
        print(
          'subject_attendance table access failed/not available: $e. Falling back to attendance.',
        );
      }

      // If empty or lookup failed, fall back to the active production attendance table
      if (attendanceRecords.isEmpty) {
        attendanceRecords = await _supabase
            .from('attendance')
            .select()
            .eq('student_id', studentId);
      }

      // 3. Process Attendance
      double totalAttendanceWeightSum = 0.0;
      int totalPeriods = 0;
      int absentCount = 0;
      int lateCount = 0;
      int leaveCount = 0;

      for (final record in attendanceRecords) {
        final status = record['status'] as String? ?? '';
        final weight = getAttendanceWeight(status);
        if (weight >= 0.0) {
          totalAttendanceWeightSum += weight;
          totalPeriods++;
          if (status.trim().toLowerCase() == 'absent') {
            absentCount++;
          } else if (status.trim().toLowerCase() == 'late') {
            lateCount++;
          } else if (status.trim().toLowerCase() == 'leave') {
            leaveCount++;
          }
        }
      }

      final attendancePercentage = totalPeriods > 0
          ? (totalAttendanceWeightSum / totalPeriods) * 100.0
          : 100.0; // Default to 100.0% if no marked records

      // 4. Fetch Marks and Exams
      final marksData = await _supabase
          .from('marks')
          .select('''
            *,
            exams (
              name,
              total_marks
            ),
            subjects (
              name
            )
          ''')
          .eq('student_id', studentId);

      // 5. Process Marks
      double totalMarksObtained = 0.0;
      double totalPossibleMarks = 0.0;
      final Set<String> examIds = {};

      for (final m in marksData) {
        final obtained = (m['marks_obtained'] as num?)?.toDouble() ?? 0.0;
        final possible = (m['total_marks'] as num?)?.toDouble() ?? 0.0;
        totalMarksObtained += obtained;
        totalPossibleMarks += possible;
        if (m['exam_id'] != null) {
          examIds.add(m['exam_id'] as String);
        }
      }

      final marksPercentage = totalPossibleMarks > 0
          ? (totalMarksObtained / totalPossibleMarks) * 100.0
          : 0.0; // Default to 0.0% if no exams/marks uploaded

      // 6. Calculate Composite Score (30% Attendance, 70% Marks)
      double academicPerformanceScore = 0.0;
      if (totalPossibleMarks > 0 && totalPeriods > 0) {
        academicPerformanceScore =
            (marksPercentage * 0.70) + (attendancePercentage * 0.30);
      } else if (totalPossibleMarks > 0) {
        academicPerformanceScore = marksPercentage;
      } else {
        academicPerformanceScore = attendancePercentage;
      }

      final progressStatus = StudentPerformanceModel.getStatusLabel(
        academicPerformanceScore,
      );

      // 7. Resolve Subjects and calculate Subject-Wise Performance breakdowns
      final Map<String, String> subjectIdToName = {};
      final List<String> courseSubjectIds = [];

      // Resolve from subjects table for the student's course
      try {
        var query = _supabase.from('subjects').select('id, name, course_id');
        if (courseId != null) {
          query = query.eq('course_id', courseId);
        }
        query = query.eq('is_active', true);

        final subjectsList = await query;
        for (final s in subjectsList) {
          final sId = s['id'] as String;
          final sName = s['name'] as String;
          subjectIdToName[sId] = sName;
          courseSubjectIds.add(sId);
        }
      } catch (e) {
        print('Error pre-fetching subjects table: $e');
      }

      // Group attendance by subject_id
      final Map<String, List<Map<String, dynamic>>> attendanceBySubject = {};
      for (final r in attendanceRecords) {
        final sId = r['subject_id'] as String?;
        if (sId != null) {
          attendanceBySubject
              .putIfAbsent(sId, () => [])
              .add(Map<String, dynamic>.from(r));
        }
      }

      // Group marks by subject_id
      final Map<String, List<Map<String, dynamic>>> marksBySubject = {};
      for (final m in marksData) {
        final sId = m['subject_id'] as String?;
        if (sId != null) {
          marksBySubject
              .putIfAbsent(sId, () => [])
              .add(Map<String, dynamic>.from(m));
        }
      }

      // Filter and only show corresponding course subjects
      final List<String> finalSubjectIds = courseSubjectIds.isNotEmpty
          ? courseSubjectIds.toSet().toList()
          : <String>{...attendanceBySubject.keys, ...marksBySubject.keys}.toList();

      final List<SubjectPerformance> subjectWiseList = [];

      for (final subId in finalSubjectIds) {
        final subName =
            subjectIdToName[subId] ??
            'Subject (${subId.substring(0, min(8, subId.length))})';

        // Subject attendance
        final subAttendance = attendanceBySubject[subId] ?? [];
        double subAttendanceWeightSum = 0.0;
        int subAttendanceMarkedCount = 0;
        for (final r in subAttendance) {
          final w = getAttendanceWeight(r['status'] as String? ?? '');
          if (w >= 0.0) {
            subAttendanceWeightSum += w;
            subAttendanceMarkedCount++;
          }
        }
        final subAttendancePct = subAttendanceMarkedCount > 0
            ? (subAttendanceWeightSum / subAttendanceMarkedCount) * 100.0
            : attendancePercentage;

        // Subject marks
        final subMarks = marksBySubject[subId] ?? [];
        double subMarksObtained = 0.0;
        double subTotalPossible = 0.0;
        for (final m in subMarks) {
          subMarksObtained += (m['marks_obtained'] as num?)?.toDouble() ?? 0.0;
          subTotalPossible += (m['total_marks'] as num?)?.toDouble() ?? 0.0;
        }
        
        // Subject proficiency = average marks by all exams
        final subMarksPct = subTotalPossible > 0
            ? (subMarksObtained / subTotalPossible) * 100.0
            : 0.0;

        // Combined score is now set strictly to the average marks percentage
        final double subCombined = subMarksPct;

        subjectWiseList.add(
          SubjectPerformance(
            subjectId: subId,
            subjectName: subName,
            attendancePercentage: subAttendancePct,
            marksPercentage: subMarksPct,
            combinedScore: subCombined,
            status: StudentPerformanceModel.getStatusLabel(subCombined),
          ),
        );
      }

      subjectWiseList.sort(
        (a, b) => b.combinedScore.compareTo(a.combinedScore),
      );

      // 8. Compute Dynamic Rankings inside Course
      int performanceRank = 1;
      if (courseId != null) {
        // Fetch current performance scores of all students in the course
        final allCoursePerformances = await _supabase
            .from('student_academic_performance')
            .select('student_id, academic_performance_score')
            .eq('course_id', courseId);

        final List<Map<String, dynamic>> performanceList = [];
        bool currentIncluded = false;

        for (final p in allCoursePerformances) {
          final sId = p['student_id'] as String;
          double score =
              (p['academic_performance_score'] as num?)?.toDouble() ?? 0.0;
          if (sId == studentId) {
            score = academicPerformanceScore;
            currentIncluded = true;
          }
          performanceList.add({'student_id': sId, 'score': score});
        }

        if (!currentIncluded) {
          performanceList.add({
            'student_id': studentId,
            'score': academicPerformanceScore,
          });
        }

        // Sort descending by performance score
        performanceList.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double),
        );

        // Find current student's rank
        for (int i = 0; i < performanceList.length; i++) {
          if (performanceList[i]['student_id'] == studentId) {
            performanceRank = i + 1;
            break;
          }
        }

        // Recalculate and update rankings for all other students in this course
        for (int i = 0; i < performanceList.length; i++) {
          final sId = performanceList[i]['student_id'] as String;
          final rankVal = i + 1;
          if (sId != studentId) {
            await _supabase
                .from('student_academic_performance')
                .update({'performance_rank': rankVal})
                .eq('student_id', sId);
          }
        }
      }

      // 9. Upsert calculations into 'student_academic_performance'
      final upsertData = {
        'student_id': studentId,
        'campus_id': campusId,
        'course_id': courseId,
        'batch_id': batchId,
        'attendance_percentage': double.parse(
          attendancePercentage.toStringAsFixed(2),
        ),
        'marks_percentage': double.parse(marksPercentage.toStringAsFixed(2)),
        'academic_performance_score': double.parse(
          academicPerformanceScore.toStringAsFixed(2),
        ),
        'progress_status': progressStatus,
        'performance_rank': performanceRank,
        'total_exams': examIds.length,
        'total_periods': totalPeriods,
        'present_periods': double.parse(
          totalAttendanceWeightSum.toStringAsFixed(2),
        ),
        'absent_periods': absentCount,
        'late_periods': lateCount,
        'leave_periods': leaveCount,
        'calculated_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase
          .from('student_academic_performance')
          .upsert(upsertData, onConflict: 'student_id');

      // 10. Return the standard analytical performance model
      return StudentAcademicPerformanceModel(
        attendancePercentage: attendancePercentage,
        marksPercentage: marksPercentage,
        academicPerformanceScore: academicPerformanceScore,
        progressStatus: progressStatus,
        performanceRank: performanceRank,
        subjectWisePerformance: subjectWiseList,
        totalExams: examIds.length,
        totalPeriods: totalPeriods,
        presentPeriods: totalAttendanceWeightSum,
        absentPeriods: absentCount,
        latePeriods: lateCount,
        leavePeriods: leaveCount,
      );
    } catch (e) {
      print('StudentPerformanceService error: $e');
      rethrow;
    }
  }

  /// Backward compatibility wrapper for classic local calculation
  static StudentPerformanceModel calculatePerformance(
    List<AttendanceRecord> attendance,
    List<ExamSession> exams,
  ) {
    return calculatePerformanceLocalFallback(attendance, exams);
  }

  /// Keep the classic local static calculation as a fallback for offline/preview modes
  static StudentPerformanceModel calculatePerformanceLocalFallback(
    List<AttendanceRecord> attendance,
    List<ExamSession> exams,
  ) {
    double totalAttendanceWeightSum = 0.0;
    int totalAttendanceMarkedCount = 0;

    for (final record in attendance) {
      final weight = getAttendanceWeight(record.status);
      if (weight >= 0.0) {
        totalAttendanceWeightSum += weight;
        totalAttendanceMarkedCount++;
      }
    }

    final overallAttendancePercentage = totalAttendanceMarkedCount > 0
        ? (totalAttendanceWeightSum / totalAttendanceMarkedCount) * 100.0
        : 100.0;

    double totalMarksObtained = 0.0;
    double totalPossibleMarks = 0.0;

    for (final session in exams) {
      for (final mark in session.subjects) {
        totalMarksObtained += mark.marksObtained;
        totalPossibleMarks += mark.totalMarks;
      }
    }

    final overallMarksPercentage = totalPossibleMarks > 0
        ? (totalMarksObtained / totalPossibleMarks) * 100.0
        : 0.0;

    double overallAcademicPerformance = 0.0;
    if (totalPossibleMarks > 0 && totalAttendanceMarkedCount > 0) {
      overallAcademicPerformance =
          (overallMarksPercentage * 0.70) +
          (overallAttendancePercentage * 0.30);
    } else if (totalPossibleMarks > 0) {
      overallAcademicPerformance = overallMarksPercentage;
    } else {
      overallAcademicPerformance = overallAttendancePercentage;
    }

    final overallStatus = StudentPerformanceModel.getStatusLabel(
      overallAcademicPerformance,
    );

    // Subject-wise breakdowns fallback
    final Map<String, String> subjectIdToName = {};
    final Map<String, String> subjectNameToId = {};

    for (final session in exams) {
      for (final mark in session.subjects) {
        if (mark.subjectId != null) {
          subjectIdToName[mark.subjectId!] = mark.subject;
          subjectNameToId[mark.subject] = mark.subjectId!;
        }
      }
    }

    final Map<String, List<ExamMark>> marksBySubject = {};
    for (final session in exams) {
      for (final mark in session.subjects) {
        final key = mark.subject;
        marksBySubject.putIfAbsent(key, () => []).add(mark);
      }
    }

    final Map<String, List<AttendanceRecord>> attendanceBySubject = {};
    for (final record in attendance) {
      if (record.subjectId != null) {
        final name =
            subjectIdToName[record.subjectId!] ??
            'Subject (${record.subjectId!.substring(0, min(8, record.subjectId!.length))})';
        attendanceBySubject.putIfAbsent(name, () => []).add(record);
      }
    }

    final allSubjectNames = <String>{
      ...marksBySubject.keys,
      ...attendanceBySubject.keys,
    };

    final List<SubjectPerformance> subjectWiseList = [];

    for (final subjectName in allSubjectNames) {
      final subAttendance = attendanceBySubject[subjectName] ?? [];
      double subAttendanceWeightSum = 0.0;
      int subAttendanceMarkedCount = 0;

      for (final r in subAttendance) {
        final w = getAttendanceWeight(r.status);
        if (w >= 0.0) {
          subAttendanceWeightSum += w;
          subAttendanceMarkedCount++;
        }
      }

      final subAttendancePct = subAttendanceMarkedCount > 0
          ? (subAttendanceWeightSum / subAttendanceMarkedCount) * 100.0
          : overallAttendancePercentage;

      final subMarks = marksBySubject[subjectName] ?? [];
      double subMarksObtained = 0.0;
      double subTotalPossible = 0.0;

      for (final m in subMarks) {
        subMarksObtained += m.marksObtained;
        subTotalPossible += m.totalMarks;
      }

      final subMarksPct = subTotalPossible > 0
          ? (subMarksObtained / subTotalPossible) * 100.0
          : 0.0;

      // Subject combined score is exactly the average marks percentage
      final double subCombined = subMarksPct;

      final subStatus = StudentPerformanceModel.getStatusLabel(subCombined);
      final subId = subjectNameToId[subjectName] ?? subjectName;

      subjectWiseList.add(
        SubjectPerformance(
          subjectId: subId,
          subjectName: subjectName,
          attendancePercentage: subAttendancePct,
          marksPercentage: subMarksPct,
          combinedScore: subCombined,
          status: subStatus,
        ),
      );
    }

    subjectWiseList.sort((a, b) => b.combinedScore.compareTo(a.combinedScore));

    return StudentPerformanceModel(
      attendancePercentage: overallAttendancePercentage,
      marksPercentage: overallMarksPercentage,
      academicPerformanceScore: overallAcademicPerformance,
      progressStatus: overallStatus,
      performanceRank: 1,
      subjectWisePerformance: subjectWiseList,
      totalExams: exams.length,
      totalPeriods: attendance.length,
      presentPeriods: totalAttendanceWeightSum,
      absentPeriods: attendance.where((r) => r.status.trim().toLowerCase() == 'absent').length,
      latePeriods: attendance.where((r) => r.status.trim().toLowerCase() == 'late').length,
      leavePeriods: attendance.where((r) => r.status.trim().toLowerCase() == 'leave').length,
    );
  }
}
