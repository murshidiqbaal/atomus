import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final _supabase = Supabase.instance.client;

  String? get _uid => _supabase.auth.currentUser?.id;

  Future<List<NotificationModel>> getNotifications() async {
    if (_uid == null) return [];
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('parent_id', _uid!)
          .order('created_at', ascending: false)
          .limit(100);
      return (data as List)
          .map((m) => NotificationModel.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('NotificationRepository.getNotifications error: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('NotificationRepository.markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (_uid == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('parent_id', _uid!)
          .eq('is_read', false);
    } catch (e) {
      print('NotificationRepository.markAllAsRead error: $e');
    }
  }

  /// Save the FCM device token so the edge function can target this device.
  Future<void> updateFcmToken(String token) async {
    if (_uid == null) return;
    try {
      await _supabase
          .from('parents')
          .update({
            'fcm_token': token,
            'last_active': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _uid!);
    } catch (e) {
      print('NotificationRepository.updateFcmToken error: $e');
    }
  }

  /// Realtime stream — emits a new list whenever the notifications table changes
  /// for this parent. Supabase Realtime must be enabled for the notifications table.
  Stream<List<NotificationModel>> notificationsStream() {
    if (_uid == null) return const Stream.empty();
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('parent_id', _uid!)
        .order('created_at', ascending: false)
        .map((rows) => rows.map((m) => NotificationModel.fromMap(m)).toList());
  }
}
