import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/event.dart';
import '../../providers/events_provider.dart';
import '../../providers/filtered_events_provider.dart';
import '../runtime/api/extension_api_registry.dart';
import '../manager/extension_manager.dart';
import '../core/extension_permission.dart';
import '../security/extension_auth_notifier.dart';
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
    final extId = params['extensionId'] as String;
    final userSandboxId = params['sandboxId'] ?? 'default';

    // 获取扩展配置的沙箱组 ID
    // 如果未配置，默认为 extId (独立隔离)
    // 如果配置了组名 (如 "group1")，则前缀为 "group1"
    final groupId = _ref
        .read(extensionAuthStateProvider.notifier)
        .getSandboxId(extId);

    // 使用 groupId 作为沙箱键的前缀，实现同组共享
    return '${groupId}_$userSandboxId';
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
      // 随机化数量以增加真实感
      final randomCount = 8 + DateTime.now().millisecond % 12; // 8-19
      return [
        ...sandboxEvents,
        ...MockDataGenerator.generateEvents(
          count: randomCount,
          realData: realEvents,
          mixReal: false,
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

    // 安全修复：受限模式下禁止更改全局搜索状态，防止 UI 干扰
    if (isUntrusted) return;

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
