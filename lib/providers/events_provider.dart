import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';
import 'db_provider.dart';
import '../extensions/extension_manager.dart';

import '../services/storage_service.dart';

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
        if (count > 0) debugPrint('后台清理了 $count 个孤儿图片文件');
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
  }) async {
    if (_box == null) await _init();
    final event = Event()
      ..title = title
      ..description = description
      ..createdAt = DateTime.now()
      ..tags = tags
      ..imageUrl = imageUrl;

    await _box!.put(event.id, event);

    // 通知扩展管理器有新事件产生
    ref.read(extensionManagerProvider).notifyEventAdded(event);
  }

  Future<void> deleteEvent(String id) async {
    if (_box == null) await _init();
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
            debugPrint('已删除关联图片文件: ${event.imageUrl}');
          }
        } catch (e) {
          debugPrint('删除图片文件失败: $e');
        }
      }
      // 2. 删除数据库记录
      await _box!.delete(id);
    }
  }

  Future<void> updateEventTags(String eventId, List<String> tags) async {
    if (_box == null) await _init();
    final event = _box!.get(eventId);
    if (event != null) {
      event.tags = tags;
      await event.save();
    }
  }

  Future<void> addStep(String eventId, String description) async {
    if (_box == null) await _init();
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
    if (_box == null) await _init();
    final event = _box!.get(eventId);
    if (event != null && stepIndex < event.steps.length) {
      final steps = List<EventStep>.from(event.steps);
      steps[stepIndex].completed = !steps[stepIndex].completed;
      event.steps = steps;
      await event.save();
    }
  }

  Future<void> updateSteps(String eventId, List<EventStep> newSteps) async {
    if (_box == null) await _init();
    final event = _box!.get(eventId);
    if (event != null) {
      event.steps = newSteps;
      await event.save();
    }
  }

  Future<void> updateTags(String eventId, List<String> tags) async {
    if (_box == null) await _init();
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
