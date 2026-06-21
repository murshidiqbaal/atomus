import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NotificationModel {
  final String id;
  final String? parentId;
  final String? teacherId;
  final String? studentId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? receiverId;
  final String? receiverType;
  final String? referenceTable;
  final String? referenceId;
  final String? imageUrl;
  final String? priority;
  final DateTime? readAt;
  final String? createdBy;
  final String? campusId;
  final String? courseId;
  final String? batchId;
  final String? scope;

  const NotificationModel({
    required this.id,
    this.parentId,
    this.teacherId,
    this.studentId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.receiverId,
    this.receiverType,
    this.referenceTable,
    this.referenceId,
    this.imageUrl,
    this.priority,
    this.readAt,
    this.createdBy,
    this.campusId,
    this.courseId,
    this.batchId,
    this.scope,
  });

  bool get isAttendance => type == 'attendance';
  bool get isMarks => type == 'marks';
  bool get isFees => type == 'fees';
  bool get isAnnouncement => type == 'announcements';
  bool get isEmergency => type == 'emergency';

  IconData get icon {
    switch (type) {
      case 'attendance':
        return Icons.event_busy_rounded;
      case 'marks':
        return Icons.grade_rounded;
      case 'fees':
        return Icons.account_balance_wallet_rounded;
      case 'announcements':
        return Icons.campaign_rounded;
      case 'emergency':
        return Icons.warning_amber_rounded;
      case 'reports':
      case 'report_card':
        return Icons.analytics_rounded;
      case 'certificate':
        return Icons.workspace_premium_rounded;
      case 'profile':
        return Icons.person_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'attendance':
        return AppColors.error;
      case 'marks':
        return AppColors.info;
      case 'fees':
        return AppColors.warning;
      case 'announcements':
        return AppColors.accent;
      case 'emergency':
        return AppColors.error;
      case 'reports':
      case 'report_card':
        return Colors.purple;
      case 'certificate':
        return Colors.teal;
      case 'profile':
        return Colors.blueGrey;
      default:
        return AppColors.primary;
    }
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id']?.toString() ?? '',
      parentId: map['parent_id']?.toString(),
      teacherId: map['teacher_id']?.toString(),
      studentId: map['student_id']?.toString(),
      title: map['title']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      type: map['type']?.toString() ?? 'general',
      isRead: map['is_read'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      receiverId: map['receiver_id']?.toString(),
      receiverType: map['receiver_type']?.toString(),
      referenceTable: map['reference_table']?.toString(),
      referenceId: map['reference_id']?.toString(),
      imageUrl: map['image_url']?.toString(),
      priority: map['priority']?.toString(),
      readAt: DateTime.tryParse(map['read_at']?.toString() ?? ''),
      createdBy: map['created_by']?.toString(),
      campusId: map['campus_id']?.toString(),
      courseId: map['course_id']?.toString(),
      batchId: map['batch_id']?.toString(),
      scope: map['scope']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (receiverId != null) 'receiver_id': receiverId,
      if (receiverType != null) 'receiver_type': receiverType,
      if (parentId != null) 'parent_id': parentId,
      if (teacherId != null) 'teacher_id': teacherId,
      if (studentId != null) 'student_id': studentId,
      'title': title,
      'message': message,
      'type': type,
      'is_read': isRead,
      if (readAt != null) 'read_at': readAt!.toUtc().toIso8601String(),
      if (referenceTable != null) 'reference_table': referenceTable,
      if (referenceId != null) 'reference_id': referenceId,
      if (imageUrl != null) 'image_url': imageUrl,
      'priority': priority ?? 'normal',
      if (createdBy != null) 'created_by': createdBy,
      if (campusId != null) 'campus_id': campusId,
      if (courseId != null) 'course_id': courseId,
      if (batchId != null) 'batch_id': batchId,
      'scope': scope ?? 'individual',
    };
  }

  NotificationModel copyWith({
    String? id,
    String? parentId,
    String? teacherId,
    String? studentId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
    String? receiverId,
    String? receiverType,
    String? referenceTable,
    String? referenceId,
    String? imageUrl,
    String? priority,
    DateTime? readAt,
    String? createdBy,
    String? campusId,
    String? courseId,
    String? batchId,
    String? scope,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      receiverId: receiverId ?? this.receiverId,
      receiverType: receiverType ?? this.receiverType,
      referenceTable: referenceTable ?? this.referenceTable,
      referenceId: referenceId ?? this.referenceId,
      imageUrl: imageUrl ?? this.imageUrl,
      priority: priority ?? this.priority,
      readAt: readAt ?? this.readAt,
      createdBy: createdBy ?? this.createdBy,
      campusId: campusId ?? this.campusId,
      courseId: courseId ?? this.courseId,
      batchId: batchId ?? this.batchId,
      scope: scope ?? this.scope,
    );
  }
}
