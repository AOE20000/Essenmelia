import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';
import 'db_provider.dart';
import '../extensions/extension_manager.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/calendar_service.dart';
import 'tags_provider.dart';

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

  Future<void> addEvent({
    required String title,
    String? description,
    List<String>? tags,
    String? imageUrl,
    String? stepDisplayMode,
    String? stepSuffix,
    DateTime? reminderTime,
    String? reminderRecurrence,
    String? reminderScheme,
  }) async {
    if (_box == null) {
      await _init();
    }
    final event = Event()
      ..title = title
      ..description = description
      ..createdAt = DateTime.now()
      ..tags = tags
      ..imageUrl = imageUrl
      ..stepDisplayMode = stepDisplayMode
      ..stepSuffix = stepSuffix
      ..reminderTime = reminderTime
      ..reminderRecurrence = reminderRecurrence
      ..reminderScheme = reminderScheme;

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
        await NotificationService().scheduleEventReminder(event);
      }
    }

    await _box!.put(event.id, event);

    // 自动同步标签到全局库
    if (tags != null && tags.isNotEmpty) {
      _syncTags(tags);
    }

    // 通知扩展管理器有新事件产生
    ref.read(extensionManagerProvider).notifyEventAdded(event);
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
  }) async {
    if (_box == null) {
      await _init();
    }
    final event = _box!.get(id);
    if (event != null) {
      if (title != null) event.title = title;
      if (description != null) event.description = description;
      if (tags != null) {
        event.tags = tags;
        if (tags.isNotEmpty) {
          _syncTags(tags);
        }
      }
      if (imageUrl != null) event.imageUrl = imageUrl;
      if (stepDisplayMode != null) event.stepDisplayMode = stepDisplayMode;
      if (stepSuffix != null) event.stepSuffix = stepSuffix;

      // Handle reminder updates
      if (reminderTime != event.reminderTime ||
          reminderRecurrence != event.reminderRecurrence ||
          reminderScheme != event.reminderScheme ||
          title != null ||
          description != null) {
        // 1. 如果方案从 calendar 切换走，或者时间/标题变更且原本是 calendar，我们需要处理
        // 注意：如果原本就是 calendar 且现在也是 calendar，addEvent(existingEventId) 会执行更新操作

        // 如果新方案不是 calendar，且旧方案是 calendar，则删除旧日历项
        if (reminderScheme != 'calendar' && event.calendarEventId != null) {
          await CalendarService().deleteEvent(event.calendarEventId!);
          event.calendarEventId = null;
        }

        // 如果新方案不是 notification，且旧方案是 notification，则取消旧通知
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
            // 这里利用 addEvent 的 existingEventId 参数执行覆盖更新或新建
            final calId = await CalendarService().addEvent(
              title: title ?? event.title,
              description: description ?? event.description ?? '',
              startTime: reminderTime,
              recurrence: reminderRecurrence,
              existingEventId: event.calendarEventId,
            );
            event.calendarEventId = calId;
          } else {
            // 如果是通知方案，通常重新生成 ID 并调度
            event.reminderId =
                DateTime.now().millisecondsSinceEpoch.toInt() % 1000000;
            await NotificationService().scheduleEventReminder(event);
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
      // 1. 如果有本地图片，尝试删除文件以节省空间
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
      // 2. 如果有定时提醒，取消它
      if (event.reminderId != null) {
        await NotificationService().cancelReminder(event.reminderId!);
      }

      // 关键修复：先执行日历删除，等待完成后再删除本地数据库记录
      // 避免 UI 刷新导致 calendarEventId 丢失从而无法清理系统日程
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

      // 3. 最后从本地数据库删除
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

  /// 内部方法：同步标签到全局标签库
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
