import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../models/event.dart';
import '../../providers/db_provider.dart';
import '../../providers/events_provider.dart';
import '../../providers/filtered_events_provider.dart';
import '../extension_api_registry.dart';
import '../extension_manager.dart';
import '../utils/mock_data_generator.dart';

/// 事件相关的扩展 API 实现
class EventsExtensionApiHandler {
  final Ref _ref;

  // 虚拟沙箱数据 (移出 ExtensionManager)
  static final Map<String, List<Event>> _virtualEvents = {};

  EventsExtensionApiHandler(this._ref);

  void register(ExtensionApiRegistry registry) {
    registry.register('getEvents', _getEvents);
    registry.register('addEvent', _addEvent);
    registry.register('deleteEvent', _deleteEvent);
    registry.register('updateEvent', _updateEvent);
    registry.register('addStep', _addStep);
    registry.register('setSearchQuery', _setSearchQuery);
    registry.register('publishEvent', _publishEvent);
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
      return [
        ...sandboxEvents,
        ...MockDataGenerator.generateEvents(
          count: 12,
          realData: realEvents,
          mixReal: true,
        ),
      ];
    }

    return [...realEvents, ...sandboxEvents];
  }

  Future<dynamic> _addEvent(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final title = params['title'] as String;
    final description = params['description'] as String?;
    final tags = (params['tags'] as List?)?.cast<String>();

    if (isUntrusted) {
      final virtualEvent = Event()
        ..title = '[模拟] $title'
        ..description = description
        ..createdAt = DateTime.now()
        ..tags = tags;

      final sandboxId = _getSandboxId(params);
      _virtualEvents[sandboxId] = [
        ...(_virtualEvents[sandboxId] ?? []),
        virtualEvent,
      ];
      return;
    }

    await _ref
        .read(eventsProvider.notifier)
        .addEvent(title: title, description: description, tags: tags);
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
    final event = params['event'] as Event;

    if (isUntrusted) {
      final sandboxId = _getSandboxId(params);
      final sandbox = _virtualEvents[sandboxId] ?? [];
      final index = sandbox.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        sandbox[index] = event;
      }
      return;
    }

    // 这里原逻辑是直接操作 Hive，保持一致
    // 注意：这里的 logic 依赖于 activePrefixProvider，需要通过 ref 读取
    final activePrefix = _ref.read(activePrefixProvider);
    final boxName = '${activePrefix}_events';
    final box = Hive.box<Event>(boxName);
    await box.put(event.id, event);
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
