import 'dart:io';
import 'package:flutter/material.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../repositories/notification_repository.dart';
import '../services/password_recovery_service.dart' show NavigatorService;
import '../screens/attendance/attendance_screen.dart';
import '../screens/marks/marks_screen.dart';
import '../screens/fees/fees_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/reports/ireports_screen.dart';

/// Top-level handler — required to be outside any class.
/// Called when the app is in background/terminated and a data message arrives.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Silent handling; background OS handles showing FCM payload notifications.
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
            AndroidFlutterLocalNotificationsPlugin>();
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

    // Register current device token
    await registerDevice(repository);

    // Refresh token listener (token can rotate).
    _fcm.onTokenRefresh.listen((newToken) {
      repository.updateFcmToken(newToken);
    });
  }

  /// Gather device metadata and register token to Supabase
  Future<void> registerDevice(NotificationRepository repository) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      String platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'web');
      String deviceName = Platform.isAndroid ? 'Android Device' : (Platform.isIOS ? 'iOS Device' : 'Unknown');
      String deviceModel = Platform.localHostname;
      String appVersion = '1.0.0';

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (_) {}

      // Get user type role
      final role = await repository.getRole();
      
      // Explicit registration with device metadata
      await repository.registerDeviceToken(
        token: token,
        userType: role,
        deviceName: deviceName,
        deviceModel: deviceModel,
        platform: platform,
        appVersion: appVersion,
      );
    } catch (e) {
      print('NotificationService.registerDevice error: $e');
    }
  }

  void _handleMessageOpen(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? 'general';
    final refId = message.data['reference_id']?.toString();
    handleDeepLink(type, referenceId: refId);
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      final parts = payload.split('|');
      final type = parts[0];
      final refId = parts.length > 1 ? parts[1] : null;
      handleDeepLink(type, referenceId: refId);
    }
  }

  /// Global navigator-based deep linking
  void handleDeepLink(String type, {String? referenceId}) {
    final context = NavigatorService.navigatorKey.currentContext;
    if (context == null) {
      // Retry in 200ms if navigator is not fully initialized
      Future.delayed(
        const Duration(milliseconds: 200),
        () => handleDeepLink(type, referenceId: referenceId),
      );
      return;
    }

    Widget? targetScreen;
    switch (type.toLowerCase()) {
      case 'attendance':
        targetScreen = const AttendanceScreen();
        break;
      case 'marks':
      case 'exam':
        targetScreen = const MarksScreen();
        break;
      case 'fees':
      case 'receipt':
        targetScreen = const FeesScreen();
        break;
      case 'announcements':
      case 'announcement':
        targetScreen = const NotificationScreen();
        break;
      case 'reports':
      case 'report_card':
        targetScreen = const IReportsScreen();
        break;
      case 'profile':
        targetScreen = const ProfileScreen();
        break;
      default:
        targetScreen = const NotificationScreen();
        break;
    }

    if (targetScreen != null) {
      NavigatorService.navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => targetScreen!),
      );
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final type = message.data['type'] ?? 'general';
    final refId = message.data['reference_id'] ?? '';
    final channelId = type == 'attendance' ? _attendanceChannel.id : _generalChannel.id;
    final channelName = type == 'attendance' ? _attendanceChannel.name : _generalChannel.name;

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
      payload: '$type|$refId',
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
