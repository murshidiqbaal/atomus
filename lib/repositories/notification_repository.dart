import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../models/dummy_data.dart';

class NotificationRepository {
  final _supabase = Supabase.instance.client;

  String? get _uid => _supabase.auth.currentUser?.id;

  Future<String> getRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_role') ?? 'parent';
    } catch (_) {
      return 'parent';
    }
  }

  Future<List<NotificationModel>> getNotifications() async {
    if (_uid == null) return [];
    try {
      // Always use receiver_id — works for parent, teacher, and admin
      final data = await _supabase
          .from('notifications')
          .select()
          .eq('receiver_id', _uid!)
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

        final role = await getRole();

        final announcements = (announcementData as List)
            .map((item) => Announcement.fromMap(item as Map<String, dynamic>))
            .toList();

        final prefs = await SharedPreferences.getInstance();
        final readIds = prefs.getStringList('read_announcement_ids') ?? [];

        final announcementNotifs = announcements.map((a) {
          return NotificationModel(
            id: 'announcement_${a.id}',
            title: a.title,
            message: a.description,
            type: 'announcements',
            isRead: readIds.contains(a.id),
            createdAt: a.createdAt,
            receiverId: _uid!,
            receiverType: role,
            scope: 'broadcast',
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
            .update({
              'is_read': true,
              'read_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', notificationId);
      }
    } catch (e) {
      print('NotificationRepository.markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    if (_uid == null) return;
    try {
      // Always use receiver_id for the filter
      await _supabase
          .from('notifications')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('receiver_id', _uid!)
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
      final role = await getRole();
      await registerDeviceToken(token: token, userType: role);
    } catch (e) {
      print('NotificationRepository.updateFcmToken error: $e');
    }
  }

  /// Register token in central device_tokens table
  Future<void> registerDeviceToken({
    required String token,
    required String userType,
    String? deviceName,
    String? deviceModel,
    String? platform,
    String? appVersion,
  }) async {
    if (_uid == null) return;
    try {
      // 1. Inactivate token on any other users to prevent duplicates
      await _supabase
          .from('device_tokens')
          .update({'is_active': false})
          .eq('device_token', token)
          .neq('user_id', _uid!);

      // 2. Insert or update current token
      final payload = {
        'user_id': _uid!,
        'user_type': userType,
        'device_token': token,
        'device_name': deviceName,
        'device_model': deviceModel,
        'platform': platform,
        'app_version': appVersion,
        'is_active': true,
        'last_used': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      try {
        await _supabase.from('device_tokens').upsert(
          payload,
          onConflict: 'device_token',
        );
      } catch (_) {
        // Fallback manual upsert
        final existing = await _supabase
            .from('device_tokens')
            .select('id')
            .eq('device_token', token)
            .maybeSingle();

        if (existing != null) {
          await _supabase
              .from('device_tokens')
              .update(payload)
              .eq('device_token', token);
        } else {
          await _supabase.from('device_tokens').insert(payload);
        }
      }

      // 3. Keep old schema columns updated for backwards compatibility
      if (userType == 'parent') {
        await _supabase
            .from('parents')
            .update({
              'fcm_token': token,
              'last_active': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', _uid!)
            .select()
            .then((_) {}, onError: (_) {});
      } else if (userType == 'teacher') {
        await _supabase
            .from('teachers')
            .update({
              'fcm_token': token,
              'last_active': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', _uid!)
            .select()
            .then((_) {}, onError: (_) {});
      }
    } catch (e) {
      print('NotificationRepository.registerDeviceToken error: $e');
    }
  }

  /// Mark token inactive during logout
  Future<void> deactivateDeviceToken(String token) async {
    try {
      await _supabase
          .from('device_tokens')
          .update({'is_active': false})
          .eq('device_token', token);
    } catch (e) {
      print('NotificationRepository.deactivateDeviceToken error: $e');
    }
  }

  /// Realtime stream — emits a new list whenever the notifications table changes
  Stream<List<NotificationModel>> notificationsStream() {
    if (_uid == null) return const Stream.empty();

    // Always filter by receiver_id — works for all user types
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', _uid!)
        .order('created_at', ascending: false)
        .asyncMap((rows) async {
          final dbNotifs = rows.map((m) => NotificationModel.fromMap(m)).toList();
          try {
            final role = await getRole();
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
                title: a.title,
                message: a.description,
                type: 'announcements',
                isRead: readIds.contains(a.id),
                createdAt: a.createdAt,
                receiverId: _uid!,
                receiverType: role,
                scope: 'broadcast',
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
