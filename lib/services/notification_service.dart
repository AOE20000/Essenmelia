import 'dart:async';
import 'package:flutter/services.dart';
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

  final StreamController<NotificationResponse> _responseStream =
      StreamController.broadcast();
  Stream<NotificationResponse> get onResponse => _responseStream.stream;

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
        _responseStream.add(details);
        debugPrint(
          'Notification tapped: ${details.payload} action: ${details.actionId}',
        );
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

    final notificationDetails = NotificationDetails(
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
    );

    try {
      await _notifications.zonedSchedule(
        id,
        notificationTitle,
        event.title,
        tz.TZDateTime.from(event.reminderTime!, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: event.id,
      );
    } on PlatformException catch (e) {
      if (e.code == 'exact_alarms_not_permitted') {
        debugPrint(
          'NotificationService: Exact alarms not permitted, falling back to inexact',
        );
        await _notifications.zonedSchedule(
          id,
          notificationTitle,
          event.title,
          tz.TZDateTime.from(event.reminderTime!, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: matchComponents,
          payload: event.id,
        );
      } else {
        rethrow;
      }
    }
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

  Future<void> showProgress({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
    required String channelName,
    required String channelDescription,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'extension_progress',
          channelName,
          channelDescription: channelDescription,
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: maxProgress,
          progress: progress,
          indeterminate: progress < 0,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        ),
      ),
    );
  }

  Future<void> showWarning({
    required int id,
    required String title,
    required String body,
    required String payload,
    required String actionId,
    required String actionLabel,
    required String channelName,
    required String channelDescription,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'extension_warning',
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              actionId,
              actionLabel,
              showsUserInterface: true,
            ),
          ],
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

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
