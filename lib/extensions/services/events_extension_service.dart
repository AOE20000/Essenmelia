import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event.dart';
import '../../providers/tags_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/filtered_events_provider.dart';
import '../extension_api_registry.dart';
import '../extension_manager.dart';
import '../base_extension.dart';
import '../utils/mock_data_generator.dart';

/// 事件相关的扩展 API 实现
class EventsExtensionApiHandler {
  final Ref _ref;

  // 虚拟沙箱数据 (移出 ExtensionManager)
  static final Map<String, List<Event>> _virtualEvents = {};

  EventsExtensionApiHandler(this._ref);

  void register(ExtensionApiRegistry registry) {
    registry.register(
      'getEvents',
      _getEvents,
      permission: ExtensionPermission.readEvents,
      operation: 'Read All Tasks and Steps',
      operationEn: 'Read All Tasks and Steps',
      category: 'Data Reading',
      categoryEn: 'Data Reading',
    );
    registry.register(
      'addEvent',
      _addEvent,
      permission: ExtensionPermission.addEvents,
      operation: 'Add New Task',
      operationEn: 'Add New Task',
      category: 'Data Writing',
      categoryEn: 'Data Writing',
    );
    registry.register(
      'deleteEvent',
      _deleteEvent,
      permission: ExtensionPermission.deleteEvents,
      operation: 'Delete Task',
      operationEn: 'Delete Task',
      category: 'Data Writing',
      categoryEn: 'Data Writing',
    );
    registry.register(
      'updateEvent',
      _updateEvent,
      permission: ExtensionPermission.updateEvents,
      operation: 'Update Task',
      operationEn: 'Update Task',
      category: 'Data Writing',
      categoryEn: 'Data Writing',
    );
    registry.register(
      'getTags',
      _getTags,
      permission: ExtensionPermission.readTags,
      operation: 'Read All Tags',
      operationEn: 'Read All Tags',
      category: 'Data Reading',
      categoryEn: 'Data Reading',
    );
    registry.register(
      'addTag',
      _addTag,
      permission: ExtensionPermission.manageTags,
      operation: 'Add New Tag',
      operationEn: 'Add New Tag',
      category: 'Data Writing',
      categoryEn: 'Data Writing',
    );
    registry.register(
      'addStep',
      _addStep,
      permission: ExtensionPermission.updateEvents,
      operation: 'Add Step to Task',
      operationEn: 'Add Step to Task',
      category: 'Data Writing',
      categoryEn: 'Data Writing',
    );
    registry.register(
      'setSearchQuery',
      _setSearchQuery,
      permission: ExtensionPermission.navigation,
      operation: 'Trigger Global Search Filter',
      operationEn: 'Trigger Global Search Filter',
      category: 'Navigation',
      categoryEn: 'Navigation',
    );
    registry.register(
      'publishEvent',
      _publishEvent,
      permission: ExtensionPermission.systemInfo,
      operation: 'Publish System Broadcast',
      operationEn: 'Publish System Broadcast',
      category: 'System Info',
      categoryEn: 'System Info',
    );
  }

  Future<dynamic> _publishEvent(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final name = params['name'] as String;
    final data = params['data'] as Map<String, dynamic>;
    final extensionId = params['extensionId'] as String;

    if (isUntrusted) return;

    _ref
        .read(extensionManagerProvider)
        .broadcastEvent(name, data, senderId: extensionId);
  }

  String _getSandboxId(Map<String, dynamic> params) {
    return params['sandboxId'] ?? 'default';
  }

  Future<dynamic> _getEvents(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final eventsAsync = _ref.read(eventsProvider);
    final realEvents = eventsAsync.when(
      data: (events) => events,
      loading: () => <Event>[],
      error: (_, _) => <Event>[],
    );

    final sandboxId = _getSandboxId(params);
    final sandboxEvents = _virtualEvents[sandboxId] ?? [];

    if (isUntrusted) {
      // 漏洞修复：对不信任扩展禁用 mixReal，防止侧信道攻击
      return [
        ...sandboxEvents,
        ...MockDataGenerator.generateEvents(
          count: 12,
          realData: realEvents,
          mixReal: false,
        ),
      ];
    }

    return [...realEvents, ...sandboxEvents];
  }

  Future<dynamic> _getTags(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final tagsAsync = _ref.read(tagsProvider);
    final realTags = tagsAsync.when(
      data: (tags) => tags,
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );

    if (isUntrusted) {
      // 混淆逻辑：返回真实标签库的一部分，或者添加一些虚假标签
      return [...realTags.take(3), '虚拟标签A', '虚拟标签B'];
    }

    return realTags;
  }

  Future<dynamic> _addTag(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final tag = params['tag'] as String;

    if (isUntrusted) {
      // Fake success, but don't actually write
      return;
    }

    await _ref.read(tagsProvider.notifier).addTag(tag);
  }

  Future<dynamic> _addEvent(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final title = params['title'] as String;
    final description = params['description'] as String?;
    final tags = (params['tags'] as List?)?.cast<String>();
    final imageUrl = params['imageUrl'] as String?;
    final stepDisplayMode = params['stepDisplayMode'] as String?;
    final stepSuffix = params['stepSuffix'] as String?;
    final reminderTimeStr = params['reminderTime'] as String?;
    final reminderTime = reminderTimeStr != null
        ? DateTime.parse(reminderTimeStr)
        : null;
    final reminderRecurrence = params['reminderRecurrence'] as String?;
    final reminderScheme = params['reminderScheme'] as String?;

    if (isUntrusted) {
      final virtualEvent = Event()
        ..title = '[模拟] $title'
        ..description = description
        ..createdAt = DateTime.now()
        ..tags = tags
        ..imageUrl = imageUrl
        ..stepDisplayMode = stepDisplayMode
        ..stepSuffix = stepSuffix
        ..reminderTime = reminderTime
        ..reminderRecurrence = reminderRecurrence
        ..reminderScheme = reminderScheme;

      final sandboxId = _getSandboxId(params);
      _virtualEvents[sandboxId] = [
        ...(_virtualEvents[sandboxId] ?? []),
        virtualEvent,
      ];
      return;
    }

    await _ref
        .read(eventsProvider.notifier)
        .addEvent(
          title: title,
          description: description,
          tags: tags,
          imageUrl: imageUrl,
          stepDisplayMode: stepDisplayMode,
          stepSuffix: stepSuffix,
          reminderTime: reminderTime,
          reminderRecurrence: reminderRecurrence,
          reminderScheme: reminderScheme,
        );
  }

  Future<dynamic> _deleteEvent(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final id = params['id'] as String;

    if (isUntrusted) {
      final sandboxId = _getSandboxId(params);
      _virtualEvents[sandboxId]?.removeWhere((e) => e.id == id);
      return;
    }

    await _ref.read(eventsProvider.notifier).deleteEvent(id);
  }

  Future<dynamic> _updateEvent(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final Map<String, dynamic> eventJson;
    if (params['event'] is Event) {
      eventJson = (params['event'] as Event).toJson();
    } else if (params['event'] is Map) {
      eventJson = Map<String, dynamic>.from(params['event'] as Map);
    } else {
      return;
    }

    final event = Event.fromJson(eventJson);

    if (isUntrusted) {
      final sandboxId = _getSandboxId(params);
      final sandbox = _virtualEvents[sandboxId] ?? [];
      final index = sandbox.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        sandbox[index] = event;
      }
      return;
    }

    await _ref
        .read(eventsProvider.notifier)
        .updateEvent(
          id: event.id,
          title: event.title,
          description: event.description,
          tags: event.tags,
          imageUrl: event.imageUrl,
          stepDisplayMode: event.stepDisplayMode,
          stepSuffix: event.stepSuffix,
          reminderTime: event.reminderTime,
          reminderRecurrence: event.reminderRecurrence,
          reminderScheme: event.reminderScheme,
        );
  }

  Future<dynamic> _addStep(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final eventId = params['eventId'] as String;
    final description = params['description'] as String;

    if (isUntrusted) {
      final sandboxId = _getSandboxId(params);
      final sandbox = _virtualEvents[sandboxId] ?? [];
      final event = sandbox.where((e) => e.id == eventId).firstOrNull;
      if (event != null) {
        final step = EventStep()
          ..description = description
          ..timestamp = DateTime.now();
        event.steps = [...event.steps, step];
      }
      return;
    }

    await _ref.read(eventsProvider.notifier).addStep(eventId, description);
  }

  Future<dynamic> _setSearchQuery(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final query = params['query'] as String;
    // 搜索过滤通常不涉及敏感隐私，即便 untrusted 也可以执行，或者由框架决定是否拦截
    _ref.read(searchProvider.notifier).setQuery(query);
  }
}

/// 提供自动注册的 Provider
final eventsExtensionServiceProvider = Provider((ref) {
  final registry = ref.watch(extensionApiRegistryProvider);
  final handler = EventsExtensionApiHandler(ref);
  handler.register(registry);
  return handler;
});
