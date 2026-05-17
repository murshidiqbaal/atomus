import 'dart:math';
import '../models/dummy_data.dart';
import '../models/student_performance_model.dart';

class StudentPerformanceService {
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

  /// Calculates dynamic performance analytics for a student
  static StudentPerformanceModel calculatePerformance(
    List<AttendanceRecord> attendance,
    List<ExamSession> exams,
  ) {
    // 1. Calculate overall attendance percentage
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
        : 100.0; // Default to 100% if no marked records

    // 2. Calculate overall marks percentage
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
        : 0.0; // Default to 0% if no marks available

    // 3. Composite score (70% marks, 30% attendance)
    // If no exams are available yet, overall academic performance is purely driven by attendance (or vice-versa)
    double overallAcademicPerformance = 0.0;
    if (totalPossibleMarks > 0 && totalAttendanceMarkedCount > 0) {
      overallAcademicPerformance =
          (overallMarksPercentage * 0.70) + (overallAttendancePercentage * 0.30);
    } else if (totalPossibleMarks > 0) {
      overallAcademicPerformance = overallMarksPercentage;
    } else {
      overallAcademicPerformance = overallAttendancePercentage;
    }

    final overallStatus = StudentPerformanceModel.getStatusLabel(overallAcademicPerformance);

    // 4. Calculate Subject-Wise Performance
    // Build a subject mapping dictionary from exams
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

    // Group exams by subject name
    final Map<String, List<ExamMark>> marksBySubject = {};
    for (final session in exams) {
      for (final mark in session.subjects) {
        final key = mark.subject;
        marksBySubject.putIfAbsent(key, () => []).add(mark);
      }
    }

    // Group attendance by subject name (resolving id to name where possible)
    final Map<String, List<AttendanceRecord>> attendanceBySubject = {};
    for (final record in attendance) {
      if (record.subjectId != null) {
        final name = subjectIdToName[record.subjectId!] ?? 'Subject (${record.subjectId!.substring(0, min(8, record.subjectId!.length))})';
        attendanceBySubject.putIfAbsent(name, () => []).add(record);
      } else {
        // Attendance with null subject_id is treated as General/Institution wide, but let's not mix it into subjects
      }
    }

    // All subject names found across exams and attendance
    final allSubjectNames = <String>{
      ...marksBySubject.keys,
      ...attendanceBySubject.keys,
    };

    final List<SubjectPerformance> subjectWiseList = [];

    for (final subjectName in allSubjectNames) {
      // Subject Attendance calculation
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

      // If this subject has no specific attendance records, it inherits the overall attendance average
      final subAttendancePct = subAttendanceMarkedCount > 0
          ? (subAttendanceWeightSum / subAttendanceMarkedCount) * 100.0
          : overallAttendancePercentage;

      // Subject Marks calculation
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

      // Combine score for this subject
      double subCombinedScore = 0.0;
      if (subTotalPossible > 0 && subAttendanceMarkedCount > 0) {
        subCombinedScore = (subMarksPct * 0.70) + (subAttendancePct * 0.30);
      } else if (subTotalPossible > 0) {
        subCombinedScore = subMarksPct;
      } else {
        subCombinedScore = subAttendancePct;
      }

      final subStatus = StudentPerformanceModel.getStatusLabel(subCombinedScore);
      final subId = subjectNameToId[subjectName] ?? subjectName;

      subjectWiseList.add(
        SubjectPerformance(
          subjectId: subId,
          subjectName: subjectName,
          attendancePercentage: subAttendancePct,
          marksPercentage: subMarksPct,
          combinedScore: subCombinedScore,
          status: subStatus,
        ),
      );
    }

    // Sort subject list by combined score descending for clean visual presentations
    subjectWiseList.sort((a, b) => b.combinedScore.compareTo(a.combinedScore));

    return StudentPerformanceModel(
      attendancePercentage: overallAttendancePercentage,
      marksPercentage: overallMarksPercentage,
      academicPerformance: overallAcademicPerformance,
      progressStatus: overallStatus,
      subjectWisePerformance: subjectWiseList,
    );
  }
}
