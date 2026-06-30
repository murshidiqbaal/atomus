class DailyReportModel {
  final String id;
  final String studentId;
  final String? studentName; // Added student name
  final String? subjectId; // Nullable for general course-level reports
  final String dateStr; // 'yyyy-MM-dd'
  final String behaviorRating; // 'Excellent' | 'Good' | 'Average' | 'Needs Improvement' | 'Poor'
  final String studyEngagement; // 'Active' | 'Passive' | 'Distracted'
  final String homeworkStatus; // 'Completed' | 'Not Completed' | 'Partial' | 'N/A'
  final String remarks;
  final String teacherId;
  final String teacherName;
  final DateTime createdAt;
  final String? subjectName;

  // New fields for daily class reports
  final String? status; // 'normal' | 'need_improvement'
  final String? comment;
  final String? sessionType; // 'forenoon' | 'afternoon'
  final String? topicsCovered;
  final String? homework;
  final String? generalRemarks;

  DailyReportModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.subjectId,
    required this.dateStr,
    required this.behaviorRating,
    required this.studyEngagement,
    required this.homeworkStatus,
    required this.remarks,
    required this.teacherId,
    required this.teacherName,
    required this.createdAt,
    this.subjectName,
    this.status,
    this.comment,
    this.sessionType,
    this.topicsCovered,
    this.homework,
    this.generalRemarks,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'student_name': studentName,
      'subject_id': subjectId,
      'date_str': dateStr,
      'behavior_rating': behaviorRating,
      'study_engagement': studyEngagement,
      'homework_status': homeworkStatus,
      'remarks': remarks,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'comment': comment,
      'session_type': sessionType,
      'topics_covered': topicsCovered,
      'homework': homework,
      'general_remarks': generalRemarks,
    };
  }

  factory DailyReportModel.fromMap(Map<String, dynamic> map) {
    final studentNameVal = map['students']?['full_name'] as String? ?? map['student_name'] as String?;
    // If the map contains fields from daily_student_reports joined with daily_class_reports
    if (map.containsKey('status') || map.containsKey('daily_class_reports')) {
      final classReport = map['daily_class_reports'] as Map<String, dynamic>?;
      final teacherMap = classReport?['teachers'] as Map<String, dynamic>?;
      final teacherName = teacherMap?['full_name'] as String? ?? classReport?['teacher_name'] as String? ?? '';
      return DailyReportModel(
        id: map['id'] as String,
        studentId: map['student_id'] as String,
        studentName: studentNameVal,
        subjectId: classReport?['subject_id'] as String?,
        dateStr: classReport?['report_date'] as String? ?? map['date_str'] as String? ?? '',
        behaviorRating: map['status'] == 'need_improvement' ? 'Needs Improvement' : 'Excellent',
        studyEngagement: 'Active',
        homeworkStatus: 'Completed',
        remarks: map['comment'] as String? ?? '',
        teacherId: classReport?['teacher_id'] as String? ?? '',
        teacherName: teacherName,
        createdAt: DateTime.parse(
          map['created_at'] as String? ?? DateTime.now().toIso8601String(),
        ),
        subjectName: classReport?['subjects']?['name']?.toString() ?? classReport?['subject_name']?.toString(),
        status: map['status'] as String?,
        comment: map['comment'] as String?,
        sessionType: classReport?['session_type'] as String?,
        topicsCovered: classReport?['topics_covered'] as String?,
        homework: classReport?['homework'] as String?,
        generalRemarks: classReport?['general_remarks'] as String?,
      );
    }

    return DailyReportModel(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      studentName: studentNameVal,
      subjectId: map['subject_id'] as String?,
      dateStr: map['date_str'] as String,
      behaviorRating: map['behavior_rating'] as String,
      studyEngagement: map['study_engagement'] as String,
      homeworkStatus: map['homework_status'] as String,
      remarks: map['remarks'] as String? ?? '',
      teacherId: map['teacher_id'] as String? ?? '',
      teacherName: map['teacher_name'] as String? ?? '',
      createdAt: DateTime.parse(
        map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      subjectName: map['subjects']?['name']?.toString() ?? map['subject_name']?.toString(),
    );
  }

  DailyReportModel copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? subjectId,
    String? dateStr,
    String? behaviorRating,
    String? studyEngagement,
    String? homeworkStatus,
    String? remarks,
    String? teacherId,
    String? teacherName,
    DateTime? createdAt,
    String? subjectName,
    String? status,
    String? comment,
    String? sessionType,
    String? topicsCovered,
    String? homework,
    String? generalRemarks,
  }) {
    return DailyReportModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      subjectId: subjectId ?? this.subjectId,
      dateStr: dateStr ?? this.dateStr,
      behaviorRating: behaviorRating ?? this.behaviorRating,
      studyEngagement: studyEngagement ?? this.studyEngagement,
      homeworkStatus: homeworkStatus ?? this.homeworkStatus,
      remarks: remarks ?? this.remarks,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      createdAt: createdAt ?? this.createdAt,
      subjectName: subjectName ?? this.subjectName,
      status: status ?? this.status,
      comment: comment ?? this.comment,
      sessionType: sessionType ?? this.sessionType,
      topicsCovered: topicsCovered ?? this.topicsCovered,
      homework: homework ?? this.homework,
      generalRemarks: generalRemarks ?? this.generalRemarks,
    );
  }
}
