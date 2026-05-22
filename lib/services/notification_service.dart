import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../repositories/notification_repository.dart';

/// Top-level handler — required to be outside any class.
/// Called when the app is in background/terminated and a data message arrives.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized by the time this runs.
  // Just handle silently; local notification is shown by FCM automatically
  // when the app is in background if notification payload is included.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Attendance alert channel (high importance so it shows as a heads-up)
  static const AndroidNotificationChannel _attendanceChannel =
      AndroidNotificationChannel(
        'atomus_attendance',
        'Attendance Alerts',
        description: 'Alerts when a student is marked absent',
        importance: Importance.max,
        playSound: true,
      );

  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
        'atomus_general',
        'General Notifications',
        description: 'Marks, fees and announcement updates',
        importance: Importance.high,
      );

  Future<void> initialize(NotificationRepository repository) async {
    // Register the background handler before anything else.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request platform permissions.
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // Initialize flutter_local_notifications.
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create Android notification channels.
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_attendanceChannel);
    await androidPlugin?.createNotificationChannel(_generalChannel);

    // Foreground message → show local notification.
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // Background tap → app opened from notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);

    // App was terminated and opened via notification.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessageOpen(initial);

    // Save FCM token to Supabase parents table.
    final token = await _fcm.getToken();
    if (token != null) await repository.updateFcmToken(token);

    // Refresh token listener (token can rotate).
    _fcm.onTokenRefresh.listen(
      (newToken) => repository.updateFcmToken(newToken),
    );
  }

  void _handleMessageOpen(RemoteMessage message) {
    // Navigation to the notification screen is handled by the UI layer
    // using a global navigator key or deep-link routing if needed.
  }

  void _onNotificationTap(NotificationResponse response) {
    // Called when the user taps a local notification.
    // Extend with navigator key routing if needed.
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? 'general';
    final channelId = type == 'attendance'
        ? _attendanceChannel.id
        : _generalChannel.id;
    final channelName = type == 'attendance'
        ? _attendanceChannel.name
        : _generalChannel.name;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title,
      ),
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Updates the app icon badge count.
  Future<void> setBadgeCount(int count) async {
    try {
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(count);
      }
    } catch (_) {}
  }
}
