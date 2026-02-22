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
import '../l10n/l10n_provider.dart';

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
      StorageService.cleanupOrphanImages(activePrefix).then((count) {
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
      ..reminderScheme = reminderScheme;

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
        );
        event.calendarEventId = calId;
      } else {
        event.reminderId =
            DateTime.now().millisecondsSinceEpoch.toInt() % 1000000;
        final l10n = ref.read(l10nProvider);
        try {
          await NotificationService().scheduleEventReminder(
            event,
            channelName: l10n.eventReminder,
            channelDescription: l10n.eventReminderChannelDesc,
            notificationTitle: l10n.eventReminder,
          );
        } catch (e) {
          debugPrint(
            'EventsNotifier: Failed to schedule reminder for new event: $e',
          );
        }
      }
    }

    await _box!.put(event.id, event);

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
    String? imageUrl,
    String? stepDisplayMode,
    String? stepSuffix,
    DateTime? reminderTime,
    String? reminderRecurrence,
    String? reminderScheme,
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
      if (imageUrl != null) {
        if (imageUrl.startsWith('http')) {
          event.imageUrl = await StorageService.downloadAndSaveImage(imageUrl);
        } else {
          event.imageUrl = imageUrl;
        }
      }
      if (stepDisplayMode != null) event.stepDisplayMode = stepDisplayMode;
      if (stepSuffix != null) event.stepSuffix = stepSuffix;

      // Handle reminder updates
      if (reminderTime != event.reminderTime ||
          reminderRecurrence != event.reminderRecurrence ||
          reminderScheme != event.reminderScheme ||
          title != null ||
          description != null) {
        // 1. If scheme switches from calendar, or time/title changes and it was calendar, we need to handle it
        // Note: if it was calendar and still is, addEvent(existingEventId) will perform update

        // If new scheme is not calendar, and old scheme was calendar, delete old calendar entry
        if (reminderScheme != 'calendar' && event.calendarEventId != null) {
          await CalendarService().deleteEvent(event.calendarEventId!);
          event.calendarEventId = null;
        }

        // If new scheme is not notification, and old scheme was notification, cancel old notification
        if (reminderScheme != 'notification' && event.reminderId != null) {
          await NotificationService().cancelReminder(event.reminderId!);
          event.reminderId = null;
        }

        event.reminderTime = reminderTime;
        event.reminderRecurrence = reminderRecurrence;
        event.reminderScheme = reminderScheme;

        // 2. Schedule or Update reminder if provided
        if (reminderTime != null) {
          if (reminderScheme == 'calendar') {
            // Use addEvent's existingEventId parameter for overwrite or create
            final calId = await CalendarService().addEvent(
              title: title ?? event.title,
              description: description ?? event.description ?? '',
              startTime: reminderTime,
              recurrence: reminderRecurrence,
              existingEventId: event.calendarEventId,
            );
            event.calendarEventId = calId;
          } else {
            // For notification scheme, usually re-generate ID and schedule
            event.reminderId =
                DateTime.now().millisecondsSinceEpoch.toInt() % 1000000;
            final l10n = ref.read(l10nProvider);
            try {
              await NotificationService().scheduleEventReminder(
                event,
                channelName: l10n.eventReminder,
                channelDescription: l10n.eventReminderChannelDesc,
                notificationTitle: l10n.eventReminder,
              );
            } catch (e) {
              debugPrint(
                'EventsNotifier: Failed to schedule reminder for updated event: $e',
              );
            }
          }
        }
      }

      await event.save();
    }
  }

  Future<void> deleteEvent(String id) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(id);
    if (event != null) {
      // 1. If there's a local image, try to delete file to save space
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
      // 2. If there's a scheduled reminder, cancel it
      if (event.reminderId != null) {
        await NotificationService().cancelReminder(event.reminderId!);
      }

      // Critical fix: delete calendar event first, wait for completion before deleting local DB record
      // Avoids UI refresh losing calendarEventId and failing to clean up system calendar
      if (event.calendarEventId != null) {
        debugPrint(
          'EventsNotifier: Starting cleanup for calendar event ${event.calendarEventId}',
        );
        final success = await CalendarService().deleteEvent(
          event.calendarEventId!,
        );
        if (success) {
          debugPrint(
            'EventsNotifier: Successfully cleaned up calendar event ${event.calendarEventId}',
          );
        } else {
          debugPrint(
            'EventsNotifier: Failed to clean up calendar event ${event.calendarEventId} - it might persist in system calendar',
          );
        }
      }

      // 3. Finally delete from local database
      await event.delete();
      debugPrint('EventsNotifier: Deleted local event record $id');
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
      // Create a new list to trigger change detection if needed, though modifying HiveObject fields usually requires save() on parent
      final steps = List<EventStep>.from(event.steps);

      if (delta > 0) {
        // Mark first 'delta' uncompleted steps as completed
        int count = 0;
        for (var step in steps) {
          if (!step.completed) {
            step.completed = true;
            count++;
            if (count >= delta) break;
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
