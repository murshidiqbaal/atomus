import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/notification_model.dart';
import '../../repositories/notification_repository.dart';
import '../../services/notification_service.dart';
import 'notification_event.dart';
import 'notification_state.dart';

class NotificationBloc
    extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _repository;

  NotificationBloc({required NotificationRepository repository})
      : _repository = repository,
        super(const NotificationState()) {
    on<LoadNotifications>(_onLoad);
    on<StartNotificationStream>(_onStartStream);
    on<MarkNotificationRead>(_onMarkRead);
    on<MarkAllNotificationsRead>(_onMarkAllRead);
  }

  Future<void> _onLoad(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(status: NotificationStatus.loading));
    try {
      final notifications = await _repository.getNotifications();
      final unread = notifications.where((n) => !n.isRead).length;
      await NotificationService.instance.setBadgeCount(unread);
      emit(state.copyWith(
        status: NotificationStatus.success,
        notifications: notifications,
        unreadCount: unread,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: NotificationStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Subscribes to a Supabase realtime stream and re-emits state on every change.
  /// flutter_bloc's emit.forEach handles stream cancellation automatically
  /// when the event handler completes or is superseded.
  Future<void> _onStartStream(
    StartNotificationStream event,
    Emitter<NotificationState> emit,
  ) async {
    await emit.forEach<List<NotificationModel>>(
      _repository.notificationsStream(),
      onData: (notifications) {
        final unread = notifications.where((n) => !n.isRead).length;
        NotificationService.instance.setBadgeCount(unread);
        return state.copyWith(
          status: NotificationStatus.success,
          notifications: notifications,
          unreadCount: unread,
        );
      },
      onError: (_, __) => state.copyWith(
        status: NotificationStatus.failure,
        errorMessage: 'Realtime connection error',
      ),
    );
  }

  Future<void> _onMarkRead(
    MarkNotificationRead event,
    Emitter<NotificationState> emit,
  ) async {
    await _repository.markAsRead(event.notificationId);
    final updated = state.notifications
        .map((n) => n.id == event.notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    final unread = updated.where((n) => !n.isRead).length;
    await NotificationService.instance.setBadgeCount(unread);
    emit(state.copyWith(notifications: updated, unreadCount: unread));
  }

  Future<void> _onMarkAllRead(
    MarkAllNotificationsRead event,
    Emitter<NotificationState> emit,
  ) async {
    await _repository.markAllAsRead();
    final updated =
        state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    await NotificationService.instance.setBadgeCount(0);
    emit(state.copyWith(notifications: updated, unreadCount: 0));
  }
}
