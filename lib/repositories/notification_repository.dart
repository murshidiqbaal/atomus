import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/dummy_data.dart';

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
      final dbNotifs = (data as List)
          .map((m) => NotificationModel.fromMap(m as Map<String, dynamic>))
          .toList();

      try {
        final now = DateTime.now().toUtc().toIso8601String();
        final announcementData = await _supabase
            .from('announcements')
            .select()
            .eq('is_active', true)
            .lte('start_date', now)
            .or('end_date.is.null,end_date.gt.$now');

        final announcements = (announcementData as List)
            .map((item) => Announcement.fromMap(item as Map<String, dynamic>))
            .toList();

        final prefs = await SharedPreferences.getInstance();
        final readIds = prefs.getStringList('read_announcement_ids') ?? [];

        final announcementNotifs = announcements.map((a) {
          return NotificationModel(
            id: 'announcement_${a.id}',
            parentId: _uid!,
            studentId: '',
            title: a.title,
            message: a.description,
            type: 'announcements',
            isRead: readIds.contains(a.id),
            createdAt: a.createdAt,
          );
        }).toList();

        final allNotifs = [...dbNotifs, ...announcementNotifs];
        allNotifs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return allNotifs;
      } catch (e) {
        print('NotificationRepository.getNotifications announcements fetch error: $e');
        return dbNotifs;
      }
    } catch (e) {
      print('NotificationRepository.getNotifications error: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      if (notificationId.startsWith('announcement_')) {
        final announcementId = notificationId.substring('announcement_'.length);
        final prefs = await SharedPreferences.getInstance();
        final readIds = prefs.getStringList('read_announcement_ids') ?? [];
        if (!readIds.contains(announcementId)) {
          readIds.add(announcementId);
          await prefs.setStringList('read_announcement_ids', readIds);
        }
      } else {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('id', notificationId);
      }
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

      try {
        final now = DateTime.now().toUtc().toIso8601String();
        final announcementData = await _supabase
            .from('announcements')
            .select('id')
            .eq('is_active', true)
            .lte('start_date', now)
            .or('end_date.is.null,end_date.gt.$now');

        final prefs = await SharedPreferences.getInstance();
        final readIds = prefs.getStringList('read_announcement_ids') ?? [];
        for (final a in announcementData) {
          final aid = a['id'].toString();
          if (!readIds.contains(aid)) {
            readIds.add(aid);
          }
        }
        await prefs.setStringList('read_announcement_ids', readIds);
      } catch (e) {
        print('NotificationRepository.markAllAsRead announcements error: $e');
      }
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
        .asyncMap((rows) async {
          final dbNotifs = rows.map((m) => NotificationModel.fromMap(m)).toList();
          try {
            final now = DateTime.now().toUtc().toIso8601String();
            final announcementData = await _supabase
                .from('announcements')
                .select()
                .eq('is_active', true)
                .lte('start_date', now)
                .or('end_date.is.null,end_date.gt.$now');
            
            final announcements = (announcementData as List)
                .map((item) => Announcement.fromMap(item as Map<String, dynamic>))
                .toList();

            final prefs = await SharedPreferences.getInstance();
            final readIds = prefs.getStringList('read_announcement_ids') ?? [];

            final announcementNotifs = announcements.map((a) {
              return NotificationModel(
                id: 'announcement_${a.id}',
                parentId: _uid!,
                studentId: '',
                title: a.title,
                message: a.description,
                type: 'announcements',
                isRead: readIds.contains(a.id),
                createdAt: a.createdAt,
              );
            }).toList();

            final allNotifs = [...dbNotifs, ...announcementNotifs];
            allNotifs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return allNotifs;
          } catch (e) {
            print('Error fetching announcements in stream: $e');
            return dbNotifs;
          }
        });
  }
}
