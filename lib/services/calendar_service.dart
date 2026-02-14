import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  Future<bool> requestPermissions() async {
    var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
    }
    return permissionsGranted.isSuccess && permissionsGranted.data!;
  }

  Future<String?> addEvent({
    required String title,
    required String description,
    required DateTime startTime,
    String? recurrence,
    String? existingEventId,
  }) async {
    try {
      if (!await requestPermissions()) {
        debugPrint('CalendarService: No permissions to add/update event.');
        return null;
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      // Find the best writable calendar based on Android Provider best practices:
      // 1. Prefer cloud-synced accounts (Google, Xiaomi, etc.)
      // 2. Avoid "LOCAL" account types if a synced one exists
      // 3. Prefer "Primary" or "Default" calendars
      final calendars = calendarsResult.data ?? [];

      // Sort calendars to put preferred ones at the top
      final sortedCalendars = List<Calendar>.from(calendars)
        ..sort((a, b) {
          // Helper to check if an account is likely cloud-synced
          bool isSynced(Calendar c) {
            final name = c.accountName?.toLowerCase() ?? '';
            final type =
                c.accountType?.toLowerCase() ??
                ''; // Note: accountType might not be in all plugin versions
            return name.contains('google') ||
                name.contains('xiaomi') ||
                name.contains('@') || // Likely an email account
                (type != 'local' && type.isNotEmpty);
          }

          final aSynced = isSynced(a);
          final bSynced = isSynced(b);
          if (aSynced != bSynced) return aSynced ? -1 : 1;

          final aPrimary = a.name?.toLowerCase().contains('primary') ?? false;
          final bPrimary = b.name?.toLowerCase().contains('primary') ?? false;
          if (aPrimary != bPrimary) return aPrimary ? -1 : 1;

          final aDefault = a.isDefault ?? false;
          final bDefault = b.isDefault ?? false;
          if (aDefault != bDefault) return aDefault ? -1 : 1;

          return 0;
        });

      final calendar = sortedCalendars.firstWhere(
        (c) => c.isReadOnly == false,
        orElse: () => calendars.first,
      );

      final calendarId = calendar.id;
      debugPrint(
        'CalendarService: Target Calendar -> Name: ${calendar.name}, Account: ${calendar.accountName}, ID: ${calendar.id}',
      );

      final event = Event(
        calendarId,
        eventId: existingEventId,
        title: title,
        description: description,
        start: tz.TZDateTime.from(startTime, tz.local),
        end: tz.TZDateTime.from(
          startTime.add(const Duration(hours: 1)),
          tz.local,
        ),
        allDay: false,
        status: EventStatus.Confirmed,
        availability: Availability.Busy,
      );

      // Add a default reminder 10 minutes before
      event.reminders = [Reminder(minutes: 10)];

      if (recurrence != null && recurrence != 'none') {
        RecurrenceFrequency? frequency;
        switch (recurrence) {
          case 'daily':
            frequency = RecurrenceFrequency.Daily;
            break;
          case 'weekly':
            frequency = RecurrenceFrequency.Weekly;
            break;
          case 'monthly':
            frequency = RecurrenceFrequency.Monthly;
            break;
        }
        if (frequency != null) {
          event.recurrenceRule = RecurrenceRule(frequency);
        }
      }

      final result = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (result?.isSuccess == true) {
        debugPrint(
          'CalendarService: Successfully ${existingEventId == null ? 'created' : 'updated'} event: ${result?.data}',
        );
        return result?.data;
      } else {
        debugPrint(
          'CalendarService: Failed to ${existingEventId == null ? 'create' : 'update'} event. Error: ${result?.errors.map((e) => e.errorMessage).join(', ')}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('CalendarService: Exception during addEvent: $e');
      return null;
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    try {
      if (!await requestPermissions()) {
        debugPrint('CalendarService: No permissions to delete event.');
        return false;
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      final calendars = calendarsResult.data ?? [];

      if (calendars.isEmpty) {
        debugPrint('CalendarService: No calendars found for deletion.');
        return false;
      }

      // Since we don't store the calendarId, we try to delete from all writable calendars
      // or at least find the one it was likely added to.
      bool anySuccess = false;
      for (var calendar in calendars) {
        if (calendar.isReadOnly == false) {
          final result = await _deviceCalendarPlugin.deleteEvent(
            calendar.id,
            eventId,
          );
          if (result.isSuccess && result.data == true) {
            debugPrint(
              'CalendarService: Successfully deleted event $eventId from calendar ${calendar.name}',
            );
            anySuccess = true;
            break; // Stop if we found it and deleted it
          }
        }
      }

      if (!anySuccess) {
        debugPrint(
          'CalendarService: Could not delete event $eventId from any writable calendar.',
        );
      }
      return anySuccess;
    } catch (e) {
      debugPrint('CalendarService: Exception during deleteEvent: $e');
      return false;
    }
  }
}
