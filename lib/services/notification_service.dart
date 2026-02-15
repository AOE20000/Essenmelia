import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/foundation.dart';
import '../models/event.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );
  }

  Future<void> scheduleEventReminder(
    Event event, {
    required String channelName,
    required String channelDescription,
    required String notificationTitle,
  }) async {
    if (event.reminderTime == null) return;

    final id = event.reminderId ?? event.id.hashCode;

    DateTimeComponents? matchComponents;
    if (event.reminderRecurrence != null &&
        event.reminderRecurrence != 'none') {
      switch (event.reminderRecurrence) {
        case 'daily':
          matchComponents = DateTimeComponents.time;
          break;
        case 'weekly':
          matchComponents = DateTimeComponents.dayOfWeekAndTime;
          break;
        case 'monthly':
          matchComponents = DateTimeComponents.dayOfMonthAndTime;
          break;
      }
    }

    // If no recurrence and time is in the past, don't schedule
    if (matchComponents == null &&
        event.reminderTime!.isBefore(DateTime.now())) {
      return;
    }

    await _notifications.zonedSchedule(
      id,
      notificationTitle,
      event.title,
      tz.TZDateTime.from(event.reminderTime!, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'event_reminders',
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
      payload: event.id,
    );
  }

  Future<void> cancelReminder(int reminderId) async {
    await _notifications.cancel(reminderId);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    required String channelName,
    required String channelDescription,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'system_notifications',
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}
