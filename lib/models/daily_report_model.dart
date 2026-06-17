class DailyReportModel {
  final String id;
  final String studentId;
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

  DailyReportModel({
    required this.id,
    required this.studentId,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'subject_id': subjectId,
      'date_str': dateStr,
      'behavior_rating': behaviorRating,
      'study_engagement': studyEngagement,
      'homework_status': homeworkStatus,
      'remarks': remarks,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DailyReportModel.fromMap(Map<String, dynamic> map) {
    return DailyReportModel(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
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
}
