import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NotificationModel {
  final String id;
  final String parentId;
  final String studentId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
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
      default:
        return AppColors.primary;
    }
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id']?.toString() ?? '',
      parentId: map['parent_id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'attendance',
      isRead: map['is_read'] ?? false,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      parentId: parentId,
      studentId: studentId,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
