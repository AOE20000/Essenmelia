import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  Timer? _pollingTimer;
  String? _activePrefix;
  final Set<String> _triggeredInLastMinute = {};
  DateTime? _lastCheckTime;
  bool _isAppInBackground = false;

  /// Cache of events that have reminders set, to avoid full scanning Hive every minute
  List<Event> _reminderCache = [];
  bool _isCacheDirty = true;

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

  /// Start polling for reminders every minute
  void startPolling(String prefix) {
    _activePrefix = prefix;
    _isCacheDirty = true;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _checkReminders(),
    );
    // Run an initial check
    _checkReminders();
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _reminderCache.clear();
  }

  void setAppInBackground(bool inBackground) {
    if (_isAppInBackground != inBackground) {
      _isAppInBackground = inBackground;
      if (!inBackground) {
        // App resumed, force a check
        _checkReminders();
      }
    }
  }

  /// Mark the cache as dirty so it will be reloaded on next check
  void notifyDataChanged() {
    _isCacheDirty = true;
  }

  Future<void> _checkReminders() async {
    if (_activePrefix == null) return;

    final now = DateTime.now();

    // Clear the triggered cache if we are in a new minute
    if (_lastCheckTime != null &&
        (_lastCheckTime!.minute != now.minute ||
            _lastCheckTime!.hour != now.hour ||
            _lastCheckTime!.day != now.day)) {
      _triggeredInLastMinute.clear();
    }
    _lastCheckTime = now;

    try {
      if (_isCacheDirty) {
        final boxName = '${_activePrefix}_events';
        if (!Hive.isBoxOpen(boxName)) return;

        final box = Hive.box<Event>(boxName);
        _reminderCache = box.values
            .where(
              (e) => e.reminderTime != null || (e.reminders ?? []).isNotEmpty,
            )
            .toList();
        _isCacheDirty = false;
        debugPrint(
          'NotificationService: Reminder cache reloaded. Found ${_reminderCache.length} events.',
        );
      }

      if (_reminderCache.isEmpty) return;

      for (final event in _reminderCache) {
        bool eventUpdated = false;

        // 1. Handle Legacy Reminder (Backward compatibility)
        if (event.reminderTime != null) {
          if (_shouldTriggerLegacy(event, now)) {
            final triggerKey =
                '${event.id}_legacy_${now.year}${now.month}${now.day}${now.hour}${now.minute}';
            if (!_triggeredInLastMinute.contains(triggerKey)) {
              _triggeredInLastMinute.add(triggerKey);
              await _triggerNotification(
                event,
                event.reminderId ?? event.id.hashCode,
              );
            }
          }
        }

        // 2. Handle New Multi-reminders
        if ((event.reminders ?? []).isNotEmpty) {
          for (final reminder in event.reminders!) {
            if (_shouldTriggerReminder(reminder, now)) {
              final triggerKey =
                  '${event.id}_${reminder.id}_${now.year}${now.month}${now.day}${now.hour}${now.minute}';
              if (!_triggeredInLastMinute.contains(triggerKey)) {
                // Check cycles limit
                if (reminder.totalCycles != null && reminder.totalCycles! > 0) {
                  final current = reminder.currentCycle ?? 0;
                  if (current >= reminder.totalCycles!) {
                    continue; // Already finished all cycles
                  }
                  reminder.currentCycle = current + 1;
                  eventUpdated = true;
                }

                _triggeredInLastMinute.add(triggerKey);
                await _triggerNotification(event, reminder.id);
              }
            }
          }
        }

        if (eventUpdated) {
          await event.save();
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error during polling check: $e');
    }
  }

  Future<void> _triggerNotification(Event event, int id) async {
    await showNotification(
      id: id,
      title: '事件提醒',
      body: event.title,
      payload: event.id,
      channelName: '事件提醒',
      channelDescription: '用于事件的定时提醒',
    );
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

  bool _shouldTriggerLegacy(Event event, DateTime now) {
    return _checkTriggerLogic(
      time: event.reminderTime!,
      recurrence: event.reminderRecurrence ?? 'none',
      repeatValue: event.reminderRepeatValue,
      repeatUnit: event.reminderRepeatUnit,
      now: now,
    );
  }

  bool _shouldTriggerReminder(EventReminder reminder, DateTime now) {
    return _checkTriggerLogic(
      time: reminder.time,
      recurrence: reminder.recurrence,
      repeatValue: reminder.repeatValue,
      repeatUnit: reminder.repeatUnit,
      now: now,
    );
  }

  bool _checkTriggerLogic({
    required DateTime time,
    required String recurrence,
    int? repeatValue,
    String? repeatUnit,
    required DateTime now,
  }) {
    // 1. Exact match (ignoring seconds)
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day &&
        time.hour == now.hour &&
        time.minute == now.minute) {
      return true;
    }

    // 2. Recurrence match
    if (recurrence == 'none') {
      return false;
    }

    // Only trigger if current time is after the initial reminder time
    if (now.isBefore(time)) return false;

    switch (recurrence) {
      case 'daily':
        return time.hour == now.hour && time.minute == now.minute;
      case 'weekly':
        return time.weekday == now.weekday &&
            time.hour == now.hour &&
            time.minute == now.minute;
      case 'monthly':
        return time.day == now.day &&
            time.hour == now.hour &&
            time.minute == now.minute;
      case 'yearly':
        return time.month == now.month &&
            time.day == now.day &&
            time.hour == now.hour &&
            time.minute == now.minute;
      case 'custom':
        if (repeatValue == null || repeatUnit == null) {
          return false;
        }

        final diff = now.difference(time);
        int diffInUnit;
        switch (repeatUnit) {
          case 'minute':
            diffInUnit = diff.inMinutes;
            break;
          case 'hour':
            diffInUnit = diff.inHours;
            break;
          case 'day':
            diffInUnit = diff.inDays;
            break;
          case 'week':
            diffInUnit = (diff.inDays / 7).floor();
            break;
          case 'month':
            diffInUnit = ((now.year - time.year) * 12) + now.month - time.month;
            break;
          case 'year':
            diffInUnit = now.year - time.year;
            break;
          default:
            return false;
        }

        // Check if the difference is a multiple of the repeat value
        if (diffInUnit > 0 && diffInUnit % repeatValue == 0) {
          // Also need to check if the time components match for coarser units
          switch (repeatUnit) {
            case 'hour':
              return time.minute == now.minute;
            case 'day':
            case 'week':
              return time.hour == now.hour && time.minute == now.minute;
            case 'month':
              return time.day == now.day &&
                  time.hour == now.hour &&
                  time.minute == now.minute;
            case 'year':
              return time.month == now.month &&
                  time.day == now.day &&
                  time.hour == now.hour &&
                  time.minute == now.minute;
            case 'minute':
              return true;
            default:
              return false;
          }
        }
        break;
    }

    return false;
  }

  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
