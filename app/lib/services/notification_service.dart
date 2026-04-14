import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// Notification configuration constants to keep strings organized.
class NotificationConfig {
  static const String mainChannelId = 'game_notifications';
  static const String mainChannelName = 'Game Alerts';
  static const String mainChannelDesc =
      'Important updates like new high scores and achievements.';

  static const String reminderChannelId = 'daily_reminders';
  static const String reminderChannelName = 'Daily Reminders';
  static const String reminderChannelDesc =
      'Friendly nudges to keep your brain sharp!';

  static const int instantNotifyId = 0;
  static const int dailyReminderId = 1;

  // Actions
  static const String actionPlayId = 'action_play';
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initializes the notification system and sets up local timezone.
  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Timezone Setup
      tz.initializeTimeZones();
      try {
        final TimezoneInfo timeZoneName =
            await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(timeZoneName as String));
      } catch (e) {
        debugPrint(
            'NotificationService: Could not set local timezone, falling back to UTC: $e');
        tz.setLocalLocation(tz.getLocation('UTC'));
      }

      // 2. Platform Settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      final iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        notificationCategories: [
          DarwinNotificationCategory(
            'game_category',
            actions: [
              DarwinNotificationAction.plain('action_play', 'Play Now!'),
            ],
          ),
        ],
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // 3. Plugin Initialization
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = true;
      debugPrint('NotificationService: Initialized successfully');
    } catch (e) {
      debugPrint('NotificationService Error: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
        'Notification tapped: ID=${response.id}, Action=${response.actionId}, Payload=${response.payload}');
    // Here you could navigate back to the game or reset state
  }

  /// Request permissions specifically for Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      debugPrint('NotificationService: Android permission granted: $granted');
      return granted;
    } else if (Platform.isIOS) {
      final iosPlugin =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      debugPrint('NotificationService: iOS permission granted: $granted');
      return granted;
    }
    return false;
  }

  /// Show an immediate alert to the user.
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
    bool useBigText = false,
  }) async {
    final BigTextStyleInformation? bigTextStyleInformation = useBigText
        ? BigTextStyleInformation(
            body,
            contentTitle: title,
            summaryText: 'Game Update',
          )
        : null;

    final androidDetails = AndroidNotificationDetails(
      NotificationConfig.mainChannelId,
      NotificationConfig.mainChannelName,
      channelDescription: NotificationConfig.mainChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: bigTextStyleInformation,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationConfig.actionPlayId,
          'Play Now!',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'game_category',
      ),
    );

    await _notificationsPlugin.show(
      NotificationConfig.instantNotifyId,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Cancels all active notifications. Useful when user opens the app.
  Future<void> dismissAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Schedules a recurring daily reminder.
  Future<void> scheduleDailyReminder(
      {required int hour, required int minute}) async {
    await _notificationsPlugin.zonedSchedule(
      NotificationConfig.dailyReminderId,
      'Time for some strategy!',
      'Your Big Blue Blocks puzzle awaits. Ready to beat your score?',
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationConfig.reminderChannelId,
          NotificationConfig.reminderChannelName,
          channelDescription: NotificationConfig.reminderChannelDesc,
          importance: Importance.low,
          priority: Priority.low,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint(
        'NotificationService: Daily reminder scheduled for $hour:$minute');
  }

  /// Cancels specific notification (e.g. daily reminder).
  Future<void> cancelDailyReminder() async {
    await _notificationsPlugin.cancel(NotificationConfig.dailyReminderId);
    debugPrint('NotificationService: Daily reminder cancelled');
  }

  /// Helper to calculate the next instance of a specific time.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
