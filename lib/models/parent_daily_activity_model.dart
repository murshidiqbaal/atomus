import 'package:intl/intl.dart';

class ParentDailyActivityModel {
  final String? id;
  final String parentId;
  final String? studentId;
  final String? campusId;
  final String? courseId;
  final String? batchId;
  final DateTime openDate;
  final DateTime firstOpenedAt;
  final DateTime lastOpenedAt;
  final int openCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ParentDailyActivityModel({
    this.id,
    required this.parentId,
    this.studentId,
    this.campusId,
    this.courseId,
    this.batchId,
    required this.openDate,
    required this.firstOpenedAt,
    required this.lastOpenedAt,
    required this.openCount,
    this.createdAt,
    this.updatedAt,
  });

  factory ParentDailyActivityModel.fromJson(Map<String, dynamic> json) {
    return ParentDailyActivityModel(
      id: json['id'] as String?,
      parentId: json['parent_id'] as String,
      studentId: json['student_id'] as String?,
      campusId: json['campus_id'] as String?,
      courseId: json['course_id'] as String?,
      batchId: json['batch_id'] as String?,
      openDate: json['open_date'] != null 
          ? DateTime.parse(json['open_date'] as String) 
          : DateTime.now(),
      firstOpenedAt: json['first_opened_at'] != null 
          ? DateTime.parse(json['first_opened_at'] as String).toLocal()
          : DateTime.now(),
      lastOpenedAt: json['last_opened_at'] != null 
          ? DateTime.parse(json['last_opened_at'] as String).toLocal()
          : DateTime.now(),
      openCount: json['open_count'] as int? ?? 1,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'parent_id': parentId,
      'student_id': studentId,
      'campus_id': campusId,
      'course_id': courseId,
      'batch_id': batchId,
      'open_date': DateFormat('yyyy-MM-dd').format(openDate),
      'first_opened_at': firstOpenedAt.toUtc().toIso8601String(),
      'last_opened_at': lastOpenedAt.toUtc().toIso8601String(),
      'open_count': openCount,
    };
    if (id != null) {
      data['id'] = id;
    }
    return data;
  }

  ParentDailyActivityModel copyWith({
    String? id,
    String? parentId,
    String? studentId,
    String? campusId,
    String? courseId,
    String? batchId,
    DateTime? openDate,
    DateTime? firstOpenedAt,
    DateTime? lastOpenedAt,
    int? openCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ParentDailyActivityModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      studentId: studentId ?? this.studentId,
      campusId: campusId ?? this.campusId,
      courseId: courseId ?? this.courseId,
      batchId: batchId ?? this.batchId,
      openDate: openDate ?? this.openDate,
      firstOpenedAt: firstOpenedAt ?? this.firstOpenedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      openCount: openCount ?? this.openCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
