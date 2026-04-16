import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';
import 'db_provider.dart';
import '../extensions/manager/extension_manager.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/calendar_service.dart';
import 'tags_provider.dart';

const _undefined = Object();

class EventsNotifier extends StateNotifier<AsyncValue<List<Event>>> {
  final Ref ref;
  final String activePrefix;
  Box<Event>? _box;

  EventsNotifier(this.ref, this.activePrefix)
    : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Wait for database initialization
      await ref.read(dbProvider.future);

      // The prefix is already provided and boxes are opened by dbProvider
      _box = Hive.box<Event>('${activePrefix}_events');

      // Initial load
      state = AsyncValue.data(_box!.values.toList());

      // 后台执行存储清理
      StorageService.cleanupOrphanImages().then((count) {
        if (count > 0) {
          debugPrint('Storage Service: Cleaned up $count orphan image(s)');
        }
      });

      // Watch for changes
      _box!.listenable().addListener(() {
        if (mounted) {
          state = AsyncValue.data(_box!.values.toList());
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String> addEvent({
    required String title,
    String? description,
    List<String>? tags,
    String? imageUrl,
    String? stepDisplayMode,
    String? stepSuffix,
    DateTime? reminderTime,
    String? reminderRecurrence,
    String? reminderScheme,
    int? reminderRepeatValue,
    String? reminderRepeatUnit,
    List<EventReminder>? reminders,
    List<EventStep>? steps,
  }) async {
    if (_box == null) {
      await _init();
    }

    // Auto-download remote images
    String? localImageUrl = imageUrl;
    if (imageUrl != null && imageUrl.startsWith('http')) {
      localImageUrl = await StorageService.downloadAndSaveImage(imageUrl);
    }

    final event = Event()
      ..title = title
      ..description = description
      ..createdAt = DateTime.now()
      ..tags = tags
      ..imageUrl = localImageUrl
      ..stepDisplayMode = stepDisplayMode
      ..stepSuffix = stepSuffix
      ..reminderTime = reminderTime
      ..reminderRecurrence = reminderRecurrence
      ..reminderScheme = reminderScheme
      ..reminderRepeatValue = reminderRepeatValue
      ..reminderRepeatUnit = reminderRepeatUnit
      ..reminders = reminders ?? [];

    if (steps != null) {
      event.steps = steps;
    }

    if (reminderTime != null) {
      if (reminderScheme == 'calendar') {
        final calId = await CalendarService().addEvent(
          title: title,
          description: description ?? '',
          startTime: reminderTime,
          recurrence: reminderRecurrence,
          repeatValue: reminderRepeatValue,
          repeatUnit: reminderRepeatUnit,
        );
        event.calendarEventId = calId;
      } else {
        event.reminderId =
            DateTime.now().millisecondsSinceEpoch.toInt() % 1000000;
      }
    }

    await _box!.put(event.id, event);

    // Notify data changed for reminder polling
    NotificationService().notifyDataChanged();

    // Auto-sync tags to global library
    if (tags != null && tags.isNotEmpty) {
      _syncTags(tags);
    }

    // Notify extension manager of new event
    ref.read(extensionManagerProvider).notifyEventAdded(event);
    return event.id;
  }

  Future<void> updateEvent({
    required String id,
    String? title,
    String? description,
    List<String>? tags,
    dynamic imageUrl = _undefined,
    dynamic stepDisplayMode = _undefined,
    dynamic stepSuffix = _undefined,
    dynamic reminderTime = _undefined,
    dynamic reminderRecurrence = _undefined,
    dynamic reminderScheme = _undefined,
    dynamic reminderRepeatValue = _undefined,
    dynamic reminderRepeatUnit = _undefined,
    dynamic reminders = _undefined,
    List<EventStep>? steps,
  }) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(id);
    if (event != null) {
      if (title != null) event.title = title;
      if (description != null) event.description = description;
      if (steps != null) event.steps = steps;
      if (tags != null) {
        event.tags = tags;
        if (tags.isNotEmpty) {
          _syncTags(tags);
        }
      }

      if (imageUrl != _undefined) {
        final String? url = imageUrl as String?;
        if (url != null && url.startsWith('http')) {
          event.imageUrl = await StorageService.downloadAndSaveImage(url);
        } else {
          event.imageUrl = url;
        }
      }

      if (stepDisplayMode != _undefined) {
        event.stepDisplayMode = stepDisplayMode as String?;
      }
      if (stepSuffix != _undefined) {
        event.stepSuffix = stepSuffix as String?;
      }

      // Handle reminder updates
      final bool hasReminderChanges =
          (reminderTime != _undefined && reminderTime != event.reminderTime) ||
          (reminderRecurrence != _undefined &&
              reminderRecurrence != event.reminderRecurrence) ||
          (reminderScheme != _undefined &&
              reminderScheme != event.reminderScheme) ||
          (reminderRepeatValue != _undefined &&
              reminderRepeatValue != event.reminderRepeatValue) ||
          (reminderRepeatUnit != _undefined &&
              reminderRepeatUnit != event.reminderRepeatUnit) ||
          reminders != _undefined ||
          title != null ||
          description != null;

      if (hasReminderChanges) {
        // 1. Handle legacy reminder cancellation
        final String? oldScheme = event.reminderScheme;
        final DateTime? oldTime = event.reminderTime;
        final String? oldCalendarId = event.calendarEventId;
        final int? oldReminderId = event.reminderId;

        final String? newScheme = reminderScheme != _undefined
            ? reminderScheme as String?
            : oldScheme;
        final DateTime? newTime = reminderTime != _undefined
            ? reminderTime as DateTime?
            : oldTime;

        // If reminder is being removed (newTime is null) OR scheme changed
        try {
          if (oldCalendarId != null &&
              (newTime == null || newScheme != 'calendar')) {
            // Don't block saving if calendar delete fails
            CalendarService().deleteEvent(oldCalendarId).catchError((e) {
              debugPrint(
                'EventsNotifier: Non-blocking calendar delete failed: $e',
              );
              return false;
            });
            event.calendarEventId = null;
          }

          if (oldReminderId != null &&
              (newTime == null || newScheme != 'notification')) {
            NotificationService().cancel(oldReminderId).catchError((e) {
              debugPrint(
                'EventsNotifier: Non-blocking notification cancel failed: $e',
              );
            });
            event.reminderId = null;
          }
        } catch (e) {
          debugPrint('EventsNotifier: Error during reminder cleanup: $e');
        }

        // 2. Handle multi-reminder cancellation
        if (reminders != _undefined && reminders != event.reminders) {
          final oldReminders = List<EventReminder>.from(event.reminders ?? []);
          for (final r in oldReminders) {
            try {
              NotificationService().cancel(r.id).catchError((e) => null);
              if (r.calendarEventId != null) {
                CalendarService()
                    .deleteEvent(r.calendarEventId!)
                    .catchError((e) => false);
              }
            } catch (e) {
              // Ignore loop errors
            }
          }
          // Now safe to update the list
          event.reminders = reminders as List<EventReminder>? ?? [];
        }

        // 3. Update fields
        if (reminderTime != _undefined) {
          event.reminderTime = reminderTime as DateTime?;
        }
        if (reminderRecurrence != _undefined) {
          event.reminderRecurrence = reminderRecurrence as String?;
        }
        if (reminderScheme != _undefined) {
          event.reminderScheme = reminderScheme as String?;
        }
        if (reminderRepeatValue != _undefined) {
          event.reminderRepeatValue = reminderRepeatValue as int?;
        }
        if (reminderRepeatUnit != _undefined) {
          event.reminderRepeatUnit = reminderRepeatUnit as String?;
        }

        // 4. Schedule or Update reminder if provided
        if (event.reminderTime != null) {
          if (event.reminderScheme == 'calendar') {
            try {
              // We await this as we need the ID, but with a catch
              final calId = await CalendarService().addEvent(
                title: title ?? event.title,
                description: description ?? event.description ?? '',
                startTime: event.reminderTime!,
                recurrence: event.reminderRecurrence,
                repeatValue: event.reminderRepeatValue,
                repeatUnit: event.reminderRepeatUnit,
                existingEventId: event.calendarEventId,
              );
              event.calendarEventId = calId;
            } catch (e) {
              debugPrint('EventsNotifier: Calendar add failed: $e');
            }
          } else {
            // For notification scheme, usually re-generate ID and schedule
            event.reminderId =
                DateTime.now().millisecondsSinceEpoch.toInt() % 1000000;
          }
        }
      }

      await event.save();
      NotificationService().notifyDataChanged();
    }
  }

  Future<void> deleteEvent(String id) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(id);
    if (event != null && event.isInBox) {
      if (event.imageUrl != null &&
          event.imageUrl!.isNotEmpty &&
          !event.imageUrl!.startsWith('http') &&
          !event.imageUrl!.startsWith('data:')) {
        try {
          final file = File(event.imageUrl!);
          if (await file.exists()) {
            await file.delete();
            debugPrint(
              'Storage Service: Deleted associated image file: ${event.imageUrl}',
            );
          }
        } catch (e) {
          debugPrint('Storage Service: Failed to delete image file: $e');
        }
      }
      // 2. If there's a scheduled reminder, cancel it (Don't let failures block local deletion)
      try {
        if (event.reminderId != null) {
          NotificationService()
              .cancel(event.reminderId!)
              .catchError((e) => null);
        }
        for (final r in event.reminders ?? []) {
          NotificationService().cancel(r.id).catchError((e) => null);
          if (r.calendarEventId != null) {
            CalendarService()
                .deleteEvent(r.calendarEventId!)
                .catchError((e) => false);
          }
        }
      } catch (e) {
        debugPrint('EventsNotifier: Error cancelling notifications: $e');
      }

      // Critical fix: delete calendar event first
      if (event.calendarEventId != null) {
        debugPrint(
          'EventsNotifier: Starting cleanup for calendar event ${event.calendarEventId}',
        );
        try {
          // Use a timeout to prevent hanging on unsupported platforms or slow services
          await CalendarService()
              .deleteEvent(event.calendarEventId!)
              .timeout(
                const Duration(seconds: 2),
                onTimeout: () {
                  debugPrint('EventsNotifier: Calendar cleanup timed out');
                  return false;
                },
              )
              .catchError((e) {
                debugPrint(
                  'EventsNotifier: Error cleaning up calendar event: $e',
                );
                return false;
              });
        } catch (e) {
          debugPrint('EventsNotifier: Error cleaning up calendar event: $e');
        }
      }

      // 3. Finally delete from local database
      try {
        // Ensure state is updated even if delete() has issues
        final currentList = state.value ?? [];
        state = AsyncValue.data(currentList.where((e) => e.id != id).toList());

        await event.delete();
      } catch (e) {
        // Fallback for Windows or other issues where delete might fail due to unexpected locks
        final key = event.key;
        if (key != null) {
          await _box!.delete(key);
        }
      }
      NotificationService().notifyDataChanged();
      debugPrint('EventsNotifier: Deleted local event record $id');
    } else if (event == null) {
      // If it's not in the main box, check if it's in any sandbox (handled by handler)
      debugPrint('EventsNotifier: Attempted to delete non-existent event $id');
    }
  }

  Future<void> updateEventTags(String eventId, List<String> tags) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(eventId);
    if (event != null) {
      event.tags = tags;
      if (tags.isNotEmpty) {
        _syncTags(tags);
      }
      await event.save();
      NotificationService().notifyDataChanged();
    }
  }

  /// Internal method: Sync tags to global tag library
  void _syncTags(List<String> tags) {
    final tagsNotifier = ref.read(tagsProvider.notifier);
    for (final tag in tags) {
      tagsNotifier.addTag(tag);
    }
  }

  Future<void> addStep(String eventId, String description) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(eventId);
    if (event != null) {
      final step = EventStep()
        ..description = description
        ..timestamp = DateTime.now();

      event.steps = [...event.steps, step];
      await event.save();
    }
  }

  Future<void> toggleStep(String eventId, int stepIndex) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(eventId);
    if (event != null && stepIndex < event.steps.length) {
      final steps = List<EventStep>.from(event.steps);
      steps[stepIndex].completed = !steps[stepIndex].completed;
      event.steps = steps;
      await event.save();
    }
  }

  Future<void> updateSteps(String eventId, List<EventStep> newSteps) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(eventId);
    if (event != null) {
      event.steps = newSteps;
      await event.save();
    }
  }

  Future<void> updateTags(String eventId, List<String> tags) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(eventId);
    if (event != null) {
      event.tags = tags;
      await event.save();
    }
  }

  Future<void> updateSuffix(String eventId, String suffix) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(eventId);
    if (event != null) {
      event.stepSuffix = suffix;
      await event.save();
    }
  }

  Future<void> adjustProgress(String eventId, int delta) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(eventId);
    if (event != null) {
      final steps = List<EventStep>.from(event.steps);

      if (delta > 0) {
        // 1. Find the last completed index to determine "latest progress"
        int lastCompletedIndex = -1;
        for (int i = steps.length - 1; i >= 0; i--) {
          if (steps[i].completed) {
            lastCompletedIndex = i;
            break;
          }
        }

        // 2. Try to complete steps starting from the one AFTER the latest progress
        int count = 0;
        int startIndex = lastCompletedIndex + 1;
        for (int i = startIndex; i < steps.length; i++) {
          if (!steps[i].completed) {
            steps[i].completed = true;
            count++;
            if (count >= delta) break;
          }
        }

        // 3. If we still need to add more (or no steps were available after the latest), append new ones
        if (count < delta) {
          final remaining = delta - count;
          final suffix = event.stepSuffix?.trim() ?? '步骤';
          for (int i = 0; i < remaining; i++) {
            final nextNumber = steps.length + 1;
            final description = '第 $nextNumber $suffix';
            steps.add(EventStep()
              ..description = description
              ..timestamp = DateTime.now()
              ..completed = true);
          }
        }
      } else if (delta < 0) {
        // Mark last 'abs(delta)' completed steps as uncompleted
        int count = 0;
        final target = delta.abs();
        for (var i = steps.length - 1; i >= 0; i--) {
          if (steps[i].completed) {
            steps[i].completed = false;
            count++;
            if (count >= target) break;
          }
        }
      }

      // Assign back to trigger Hive update
      event.steps = steps;
      await event.save();
      NotificationService().notifyDataChanged();
    }
  }

  Future<void> togglePin(String eventId) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(eventId);
    if (event != null) {
      event.pinned = !event.pinned;
      await event.save();
      NotificationService().notifyDataChanged();
    }
  }
}

final eventsProvider =
    StateNotifierProvider<EventsNotifier, AsyncValue<List<Event>>>((ref) {
      final prefix = ref.watch(activePrefixProvider);
      return EventsNotifier(ref, prefix);
    });

// Templates Providers

final templatesProvider = StreamProvider<List<StepTemplate>>((ref) async* {
  await ref.watch(dbProvider.future);
  final activePrefix = ref.read(activePrefixProvider);
  final box = Hive.box<StepTemplate>('${activePrefix}_templates');

  List<StepTemplate> getSortedTemplates() {
    final list = box.values.toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  yield getSortedTemplates();
  yield* box.watch().map((event) => getSortedTemplates());
});

final stepSetTemplatesProvider = StreamProvider<List<StepSetTemplate>>((
  ref,
) async* {
  await ref.watch(dbProvider.future);
  final activePrefix = ref.read(activePrefixProvider);
  final box = Hive.box<StepSetTemplate>('${activePrefix}_set_templates');
  yield box.values.toList();
  yield* box.watch().map((event) => box.values.toList());
});

class TemplatesController {
  final Ref ref;
  TemplatesController(this.ref);

  Future<void> addTemplate(String description) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepTemplate>('${activePrefix}_templates');

    // 获取当前最大的 order
    int maxOrder = -1;
    for (var t in box.values) {
      if (t.order > maxOrder) maxOrder = t.order;
    }

    final template = StepTemplate()
      ..description = description
      ..order = maxOrder + 1;
    await box.put(template.id, template);
  }

  Future<void> updateTemplatesOrder(List<StepTemplate> templates) async {
    await ref.read(dbProvider.future);

    for (int i = 0; i < templates.length; i++) {
      final t = templates[i];
      t.order = i;
      await t.save();
    }
  }

  Future<void> updateTemplate(String id, String description) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepTemplate>('${activePrefix}_templates');
    final template = box.get(id);
    if (template != null) {
      template.description = description;
      await template.save();
    }
  }

  Future<void> deleteTemplate(String id) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepTemplate>('${activePrefix}_templates');
    await box.delete(id);
  }
}

class SetTemplatesController {
  final Ref ref;
  SetTemplatesController(this.ref);

  Future<void> addSetTemplate(String name, List<String> steps) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepSetTemplate>('${activePrefix}_set_templates');
    final template = StepSetTemplate()
      ..name = name
      ..steps = steps
          .map((s) => StepSetTemplateStep()..description = s)
          .toList();
    await box.put(template.id, template);
  }

  Future<void> deleteSetTemplate(String id) async {
    await ref.read(dbProvider.future);
    final activePrefix = ref.read(activePrefixProvider);
    final box = Hive.box<StepSetTemplate>('${activePrefix}_set_templates');
    await box.delete(id);
  }
}

final templatesControllerProvider = Provider((ref) => TemplatesController(ref));
final setTemplatesControllerProvider = Provider(
  (ref) => SetTemplatesController(ref),
);
