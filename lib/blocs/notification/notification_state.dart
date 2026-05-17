import 'package:equatable/equatable.dart';
import '../../models/notification_model.dart';

enum NotificationStatus { initial, loading, success, failure }

class NotificationState extends Equatable {
  final NotificationStatus status;
  final List<NotificationModel> notifications;
  final int unreadCount;
  final String? errorMessage;

  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.unreadCount = 0,
    this.errorMessage,
  });

  List<NotificationModel> get unread =>
      notifications.where((n) => !n.isRead).toList();

  List<NotificationModel> ofType(String type) =>
      notifications.where((n) => n.type == type).toList();

  NotificationState copyWith({
    NotificationStatus? status,
    List<NotificationModel>? notifications,
    int? unreadCount,
    String? errorMessage,
  }) {
    return NotificationState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, notifications, unreadCount, errorMessage];
}
