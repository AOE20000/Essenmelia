import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dynamic_engine.dart';
import 'utils/extension_converter.dart';
import 'base_extension.dart';
import '../models/event.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import 'extension_api_registry.dart';
import 'services/events_extension_service.dart';
import 'services/tags_extension_service.dart';
import 'services/ui_extension_service.dart';
import 'services/system_extension_service.dart';
import 'services/settings_extension_service.dart';
import 'services/extension_store_service.dart';
import 'widgets/permission_management_dialog.dart';
import 'extension_log_manager.dart';
import 'models/repository_extension.dart';
import 'logic_engine.dart';
import '../l10n/l10n_provider.dart';
import '../services/notification_service.dart';

/// 扩展权限状态管理
final extensionAuthStateProvider =
    StateNotifierProvider<ExtensionAuthNotifier, Map<String, List<String>>>((
      ref,
    ) {
      return ExtensionAuthNotifier(ref);
    });

class ExtensionAuthNotifier extends StateNotifier<Map<String, List<String>>> {
  final Ref _ref;
  ExtensionAuthNotifier(this._ref) : super({}) {
    _load();
  }

  static const _boxName = 'extension_auth_v2';
  static const _untrustedPrefix = 'untrusted_';
  static const _runningPrefix = 'running_';
  static const _nextRunPrefix = 'next_run_';
  static const _sandboxPrefix = 'sandbox_';
  static const _manifestHashPrefix = 'hash_';

  /// 内存中维护的暂停状态，不需要持久化
  final Set<String> _pausedExtensions = {};

  Future<void> _load() async {
    final box = await Hive.openBox(_boxName);
    final Map<String, List<String>> loaded = {};
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        loaded[key.toString()] = List<String>.from(
          value is List ? value : [value.toString()],
        );
      }
    }
    state = loaded;
  }

  /// 获取沙箱 ID，默认为扩展 ID 本身 (个体隔离)
  String getSandboxId(String extensionId) {
    final key = '$_sandboxPrefix$extensionId';
    final val = state[key]?.firstOrNull;
    return val ?? extensionId;
  }

  /// 设置沙箱 ID
  Future<void> setSandboxId(String extensionId, String sandboxId) async {
    final box = await Hive.openBox(_boxName);
    final key = '$_sandboxPrefix$extensionId';
    // 如果设置为空或等于 extensionId，则恢复默认
    if (sandboxId.isEmpty || sandboxId == extensionId) {
      await box.delete(key);
      state = Map.from(state)..remove(key);
    } else {
      await box.put(key, [sandboxId]);
      state = {
        ...state,
        key: [sandboxId],
      };
    }
  }

  void setPaused(String extensionId, bool paused) {
    if (paused) {
      _pausedExtensions.add(extensionId);
    } else {
      _pausedExtensions.remove(extensionId);
    }
    // 状态变更触发 UI 刷新（如果需要）
    state = {...state};
  }

  /// Reset all permissions and state
  Future<void> resetAll() async {
    final box = await Hive.openBox(_boxName);
    await box.clear();
    _pausedExtensions.clear();
    state = {};
  }

  bool isPaused(String extensionId) => _pausedExtensions.contains(extensionId);

  Future<void> togglePermission(
    String extensionId,
    ExtensionPermission permission,
  ) async {
    final box = await Hive.openBox(_boxName);
    final currentPerms = List<String>.from(state[extensionId] ?? []);
    final permName = permission.name;

    if (currentPerms.contains(permName)) {
      currentPerms.remove(permName);
    } else {
      currentPerms.add(permName);
    }

    await box.put(extensionId, currentPerms);
    state = {...state, extensionId: currentPerms};
  }

  /// 授予权限并通知扩展（事后授权模式）
  Future<void> grantPermission(
    String extensionId,
    ExtensionPermission permission,
  ) async {
    if (!hasPermission(extensionId, permission)) {
      await togglePermission(extensionId, permission);
    }
  }

  Future<void> setUntrusted(String extensionId, bool untrusted) async {
    final box = await Hive.openBox(_boxName);
    final key = '$_untrustedPrefix$extensionId';
    await box.put(key, [untrusted.toString()]);
    state = {
      ...state,
      key: [untrusted.toString()],
    };
  }

  Future<void> setRunning(String extensionId, bool running) async {
    final box = await Hive.openBox(_boxName);
    final key = '$_runningPrefix$extensionId';
    await box.put(key, [running.toString()]);
    state = {
      ...state,
      key: [running.toString()],
    };

    // 如果停止运行，重置该扩展的所有会话临时授权
    if (!running) {
      _ref.read(sessionPermissionsProvider.notifier).update((sessionState) {
        final newState = Map<String, Set<String>>.from(sessionState);
        newState.remove(extensionId);
        return newState;
      });
      // 清除相关的临时状态
      final nextRunKey = '$_nextRunPrefix$extensionId';
      await box.delete(nextRunKey);
    }
  }

  bool isUntrusted(String extensionId) {
    final key = '$_untrustedPrefix$extensionId';
    final val = state[key]?.firstOrNull;
    return val == 'true';
  }

  bool isRunning(String extensionId) {
    final key = '$_runningPrefix$extensionId';
    final val = state[key]?.firstOrNull;
    // 默认值为 true (启用)
    return val != 'false';
  }

  bool hasPermission(String extensionId, ExtensionPermission permission) {
    return state[extensionId]?.contains(permission.name) ?? false;
  }

  Future<void> setNextRunPermission(String extensionId, String category) async {
    final box = await Hive.openBox(_boxName);
    final key = '$_nextRunPrefix$extensionId';
    final current = List<String>.from(state[key] ?? []);
    if (!current.contains(category)) {
      current.add(category);
      await box.put(key, current);
      state = {...state, key: current};
    }
  }

  List<String> getNextRunPermissions(String extensionId) {
    final key = '$_nextRunPrefix$extensionId';
    return state[key] ?? [];
  }

  Future<void> clearNextRunPermissions(String extensionId) async {
    final box = await Hive.openBox(_boxName);
    final key = '$_nextRunPrefix$extensionId';
    await box.delete(key);
    state = {...state}..remove(key);
  }

  Future<void> setManifestHash(String extensionId, String hash) async {
    final box = await Hive.openBox(_boxName);
    final key = '$_manifestHashPrefix$extensionId';
    await box.put(key, [hash]);
    state = {
      ...state,
      key: [hash],
    };
  }

  String? getManifestHash(String extensionId) {
    final key = '$_manifestHashPrefix$extensionId';
    return state[key]?.firstOrNull;
  }

  Future<bool> consumeNextRunPermission(
    String extensionId,
    String category,
  ) async {
    final key = '$_nextRunPrefix$extensionId';
    final current = List<String>.from(state[key] ?? []);
    if (current.contains(category)) {
      current.remove(category);
      final box = await Hive.openBox(_boxName);
      if (current.isEmpty) {
        await box.delete(key);
        state = {...state}..remove(key);
      } else {
        await box.put(key, current);
        state = {...state, key: current};
      }
      return true;
    }
    return false;
  }

  Future<void> uninstallExtension(String extensionId) async {
    final box = await Hive.openBox(_boxName);

    // 1. 清除权限设置
    await box.delete(extensionId);

    // 2. 清除不信任状态
    await box.delete('$_untrustedPrefix$extensionId');

    // 3. 清除运行状态
    await box.delete('$_runningPrefix$extensionId');

    // 4. 清除沙箱组设置
    await box.delete('$_sandboxPrefix$extensionId');

    // 5. 清除扩展私有设置
    await Hive.deleteBoxFromDisk('ext_$extensionId');

    // 6. 清除本次运行的临时授权
    _ref.read(sessionPermissionsProvider.notifier).update((sessionState) {
      final newState = Map<String, Set<String>>.from(sessionState);
      newState.remove(extensionId);
      return newState;
    });

    // 7. 从存储服务移除扩展
    await _ref
        .read(extensionStoreServiceProvider.notifier)
        .removeExtension(extensionId);

    // 8. 更新状态触发 UI 刷新
    state = {...state}
      ..remove(extensionId)
      ..remove('$_untrustedPrefix$extensionId')
      ..remove('$_runningPrefix$extensionId')
      ..remove('$_sandboxPrefix$extensionId');
  }

  /// 仅用于触发 UI 刷新的辅助方法
  void triggerNotify() {
    state = {...state};
  }
}

/// 扩展管理器 Provider
final extensionManagerProvider = ChangeNotifierProvider<ExtensionManager>((
  ref,
) {
  return ExtensionManager(ref);
});

/// 全局导航 Key，用于在没有 Context 的地方弹出对话框
final navigatorKey = GlobalKey<NavigatorState>();

/// 记录本次会话中已允许的权限 (`Map<extensionId, Set<String>>`)
/// String 可以是 "all" 或具体的 Category 名
final sessionPermissionsProvider = StateProvider<Map<String, Set<String>>>(
  (ref) => {},
);

/// 对话框显示锁，防止并发 API 调用导致多个弹窗冲突
bool _isDialogShowing = false;
Future<void>? _currentDialogFuture;

/// 受控 API 的具体实现
class ExtensionApiImpl implements ExtensionApi {
  final Ref _ref;
  final ExtensionMetadata _metadata;
  final ExtensionManager _manager;

  ExtensionApiImpl(this._ref, this._metadata, this._manager);

  bool _checkPermission(ExtensionPermission permission) {
    final extId = _metadata.id;

    // 1. 检查持久化授权
    final hasPersistent = _ref
        .read(extensionAuthStateProvider.notifier)
        .hasPermission(extId, permission);
    if (hasPersistent) return true;

    // 2. 检查本次会话的临时授权 (通过“受限访问”弹窗获得的授权)
    final sessionPerms = _ref.read(sessionPermissionsProvider)[extId] ?? {};
    if (sessionPerms.contains('all')) return true;

    // 检查具体的权限名
    if (sessionPerms.contains(permission.name)) return true;

    return false;
  }

  String _getSandboxId() {
    return _ref
        .read(extensionAuthStateProvider.notifier)
        .getSandboxId(_metadata.id);
  }

  /// 通用的 API 调用派发器
  Future<dynamic> _invokeApi(
    String methodName, {
    Map<String, dynamic> params = const {},
    ExtensionPermission? permission,
    String? operation,
    String? category,
  }) async {
    final notifier = _ref.read(extensionAuthStateProvider.notifier);
    final extId = _metadata.id;
    final registry = _ref.read(extensionApiRegistryProvider);

    if (!notifier.isRunning(extId)) {
      return null;
    }

    // 1. 获取注册表元数据
    final metadata = registry.getMetadata(methodName);

    // 2. 优先使用显式传入的参数，否则使用元数据中的定义 (Fail-Closed 基础)
    final effectivePermission = permission ?? metadata?.permission;
    final effectiveOperation = operation ?? metadata?.operation;
    final effectiveCategory = category ?? metadata?.category;

    bool isUntrusted = false;

    // 3. 隐私 Shield 拦截逻辑 (针对受限访问模式)
    if (effectiveOperation != null) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final l10n = AppLocalizations.of(context)!;
        final operation = metadata?.getOperation(l10n) ?? effectiveOperation;
        final category =
            metadata?.getCategory(l10n) ??
            effectiveCategory ??
            l10n.extensionCategoryGeneral;

        isUntrusted = !await _shieldIntercept(
          operation,
          category,
          permission: effectivePermission,
        );
      }
    }

    // 4. 显式权限检查 (针对持久化授权)
    // 如果 API 定义了权限，但检查未通过，则强制进入“不信任”模式（返回模拟数据）
    if (!isUntrusted &&
        effectivePermission != null &&
        !_checkPermission(effectivePermission)) {
      isUntrusted = true;
    }

    // 注入扩展元信息和沙箱 ID
    final fullParams = {
      ...params,
      'extensionId': _metadata.id,
      'sandboxId': _getSandboxId(),
    };

    final handler = registry.getHandler(methodName);

    dynamic result;
    bool success = true;
    String? error;

    try {
      if (handler != null) {
        result = await handler(fullParams, isUntrusted: isUntrusted);
      } else {
        debugPrint(
          'Extension framework: No handler registered for $methodName',
        );
        success = false;
        error = 'No handler registered';
      }
    } catch (e) {
      success = false;
      error = e.toString();
      rethrow;
    } finally {
      // 记录全局日志
      _ref
          .read(extensionLogProvider.notifier)
          .addLog(
            ExtensionLogEntry(
              extensionId: _metadata.id,
              extensionName: _metadata.name,
              method: methodName,
              params: params,
              timestamp: DateTime.now(),
              success: success,
              error: error,
              isUntrusted: isUntrusted,
            ),
          );
    }

    return result;
  }

  /// 权限管理拦截逻辑 (非阻塞 + 事后授权模式)
  Future<bool> _shieldIntercept(
    String operation,
    String category, {
    ExtensionPermission? permission,
  }) async {
    final notifier = _ref.read(extensionAuthStateProvider.notifier);
    final extId = _metadata.id;

    // 如果扩展已停用，直接返回假数据
    if (!notifier.isRunning(extId)) {
      await Future.delayed(
        Duration(milliseconds: 100 + (DateTime.now().millisecond % 300)),
      );
      return false;
    }

    // 如果未开启“受限访问”模式，直接通过
    if (!notifier.isUntrusted(extId)) return true;

    // 检查是否有“仅下次允许”的权限，如果有则直接消费并放行
    if (permission != null &&
        await notifier.consumeNextRunPermission(extId, permission.name)) {
      return true;
    }

    // 检查本次会话是否已允许
    final sessionPerms = _ref.read(sessionPermissionsProvider)[extId] ?? {};
    if (sessionPerms.contains('all') ||
        (permission != null && sessionPerms.contains(permission.name))) {
      return true;
    }

    // --- 核心变更：不再等待弹窗，而是立即“暂停”扩展并返回假数据 ---

    // 1. 标记暂停，防止事件干扰
    notifier.setPaused(extId, true);

    // 2. 异步弹出对话框（不 await）
    _showPrivacyDialogAsync(operation, category, permission: permission);

    // 3. 模拟正常耗时后返回 false (引导扩展使用假数据)
    await Future.delayed(Duration(milliseconds: 150 + (extId.hashCode % 150)));
    return false;
  }

  void _showPrivacyDialogAsync(
    String operation,
    String category, {
    ExtensionPermission? permission,
  }) {
    final requestId = '${_metadata.id}_${permission?.name ?? category}';

    // 1. 如果当前扩展的这个类别的请求已经在处理中，直接忽略
    if (_manager._activePrivacyRequests.contains(requestId)) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    _manager._activePrivacyRequests.add(requestId);

    Future.microtask(() async {
      try {
        // 2. 等待之前的对话框关闭
        if (_isDialogShowing && _currentDialogFuture != null) {
          await _currentDialogFuture!.timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
        }

        // 3. 再次检查是否还需要显示
        final authNotifier = _ref.read(extensionAuthStateProvider.notifier);
        if (!authNotifier.isPaused(_metadata.id)) {
          return;
        }

        if (_isDialogShowing) return;

        if (!context.mounted) return;

        _isDialogShowing = true;
        final completer = Completer<void>();
        _currentDialogFuture = completer.future;

        try {
          final decision = await showDialog<PermissionManagementDecision>(
            context: context,
            barrierDismissible: false,
            builder: (context) => PermissionManagementDialog(
              extensionName: _metadata.name,
              operationDescription: operation,
              categoryName: category,
              isPostHoc: true,
            ),
          );

          if (decision != null &&
              decision != PermissionManagementDecision.deny) {
            final authNotifier = _ref.read(extensionAuthStateProvider.notifier);
            final permKey = permission?.name ?? category;

            if (decision == PermissionManagementDecision.allowNextRun) {
              await authNotifier.setNextRunPermission(_metadata.id, permKey);
            } else {
              _ref.read(sessionPermissionsProvider.notifier).update((state) {
                final newState = Map<String, Set<String>>.from(state);
                final extPerms = Set<String>.from(newState[_metadata.id] ?? {});
                if (decision ==
                    PermissionManagementDecision.allowCategoryOnce) {
                  extPerms.add(permKey);
                } else if (decision ==
                    PermissionManagementDecision.allowAllOnce) {
                  extPerms.add('all');
                }
                newState[_metadata.id] = extPerms;
                return newState;
              });

              if (permission != null) {
                _manager.notifyPermissionGranted(_metadata.id, permission);
              }
            }
          }
        } finally {
          _isDialogShowing = false;
          completer.complete();
        }
      } catch (e) {
        debugPrint('Shield: Error in privacy dialog microtask: $e');
      } finally {
        _manager._activePrivacyRequests.remove(requestId);
        _manager.resumeExtension(_metadata.id);
      }
    });
  }

  @override
  Future<List<Event>> getEvents() async {
    final result = await _invokeApi('getEvents');
    return (result as List?)?.cast<Event>() ?? [];
  }

  @override
  Future<List<String>> getTags() async {
    final result = await _invokeApi('getTags');
    return (result as List?)?.cast<String>() ?? [];
  }

  @override
  Future<void> addTag(String tag) async {
    await _invokeApi('addTag', params: {'tag': tag});
  }

  @override
  void navigateTo(String route) {
    _invokeApi('navigateTo', params: {'route': route});
  }

  @override
  void showSnackBar(String message) {
    _invokeApi('showSnackBar', params: {'message': message});
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    await _invokeApi(
      'showNotification',
      params: {'title': title, 'body': body, 'id': id, 'payload': payload},
    );
  }

  @override
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
  }) async {
    final l10n = _ref.read(l10nProvider);
    final result = await _invokeApi(
      'showConfirmDialog',
      params: {
        'title': title,
        'message': message,
        'confirmLabel': confirmLabel ?? l10n.confirm,
        'cancelLabel': cancelLabel ?? l10n.cancel,
      },
    );
    return result ?? false;
  }

  @override
  Future<bool> exportFile(String content, String fileName) async {
    final result = await _invokeApi(
      'exportFile',
      params: {'content': content, 'fileName': fileName},
    );
    return result ?? false;
  }

  @override
  Future<String?> pickFile({List<String>? allowedExtensions}) async {
    final result = await _invokeApi(
      'pickFile',
      params: {'allowedExtensions': allowedExtensions},
    );
    return result as String?;
  }

  @override
  Future<String?> httpGet(String url, {Map<String, String>? headers}) async {
    final result = await _invokeApi(
      'httpGet',
      params: {'url': url, 'headers': headers},
    );
    return result as String?;
  }

  @override
  Future<String?> httpPost(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final result = await _invokeApi(
      'httpPost',
      params: {'url': url, 'headers': headers, 'body': body},
    );
    return result as String?;
  }

  @override
  Future<String?> httpPut(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final result = await _invokeApi(
      'httpPut',
      params: {'url': url, 'headers': headers, 'body': body},
    );
    return result as String?;
  }

  @override
  Future<String?> httpDelete(String url, {Map<String, String>? headers}) async {
    final result = await _invokeApi(
      'httpDelete',
      params: {'url': url, 'headers': headers},
    );
    return result as String?;
  }

  @override
  Future<void> openUrl(String url) async {
    await _invokeApi('openUrl', params: {'url': url});
  }

  @override
  Future<dynamic> call(String method, Map<String, dynamic> params) async {
    // 自动基于注册表元数据进行调用，移除硬编码 switch
    return await _invokeApi(method, params: params);
  }

  @override
  void publishEvent(String name, Map<String, dynamic> data) {
    _invokeApi('publishEvent', params: {'name': name, 'data': data});
  }

  @override
  void setSearchQuery(String query) {
    _invokeApi('setSearchQuery', params: {'query': query});
  }

  @override
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
    await _invokeApi(
      'addEvent',
      params: {
        'title': title,
        'description': description,
        'tags': tags,
        'imageUrl': imageUrl,
        'stepDisplayMode': stepDisplayMode,
        'stepSuffix': stepSuffix,
        'reminderTime': reminderTime?.toIso8601String(),
        'reminderRecurrence': reminderRecurrence,
        'reminderScheme': reminderScheme,
      },
    );
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _invokeApi('deleteEvent', params: {'id': id});
  }

  @override
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
    // 构造一个临时的 Event 对象用于序列化或直接传递参数
    // 在 updateEvent 的 handler 中，我们可以根据 params['event'] 或直接提取参数
    await _invokeApi(
      'updateEvent',
      params: {
        'event': {
          'id': id,
          'title': title,
          'description': description,
          'tags': tags,
          'imageUrl': imageUrl,
          'stepDisplayMode': stepDisplayMode,
          'stepSuffix': stepSuffix,
          'reminderTime': reminderTime?.toIso8601String(),
          'reminderRecurrence': reminderRecurrence,
          'reminderScheme': reminderScheme,
        },
      },
    );
  }

  @override
  Future<void> addStep(String eventId, String description) async {
    await _invokeApi(
      'addStep',
      params: {'eventId': eventId, 'description': description},
    );
  }

  @override
  Future<int> getDbSize() async {
    final result = await _invokeApi('getDbSize');
    return result ?? 0;
  }

  @override
  String getThemeMode() {
    _invokeApi('getThemeMode');
    // 异步 API 转发到同步接口的折中方案：
    // 在 ExtensionApi 中，getThemeMode 和 getLocale 是同步的，
    // 但我们的转发机制是异步的。为了保持兼容性，我们可以直接在实现中读取，
    // 或者将这两个 API 也改为异步（如果 BaseExtension 允许）。
    // 鉴于这两个值在运行时相对稳定，直接读取 Ref 是最简单的。

    final themeOption = _ref.read(themeProvider);
    final context = navigatorKey.currentContext;

    bool isDark = false;
    if (themeOption == ThemeModeOption.system && context != null) {
      isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    } else {
      isDark = themeOption == ThemeModeOption.dark;
    }

    return isDark ? 'dark' : 'light';
  }

  @override
  String getLocale() {
    _invokeApi('getLocale');
    final locale = _ref.read(localeProvider);
    return locale?.languageCode ?? 'zh';
  }

  @override
  Future<T?> getSetting<T>(String key) async {
    final result = await _invokeApi('getSetting', params: {'key': key});
    return result as T?;
  }

  @override
  Future<void> saveSetting<T>(String key, T value) async {
    await _invokeApi('saveSetting', params: {'key': key, 'value': value});
  }
}

/// 动态加载的扩展占位符
class ProxyExtension extends BaseExtension {
  final ExtensionManager? manager;
  ExtensionJsEngine? _engine;

  ProxyExtension(super.metadata, {this.manager});

  @override
  Future<void> onInit(ExtensionApi api) async {
    _engine = ExtensionJsEngine(metadata: metadata, api: api);
    await _engine!.init();
  }

  @override
  Future<void> onDispose() async {
    _engine?.dispose();
    _engine = null;
  }

  @override
  void onExtensionEvent(String name, Map<String, dynamic> data) {
    _engine?.handleEvent(name, data);
  }

  /// 允许外部调用 JS 函数
  Future<dynamic> callJsFunction(String name, [dynamic params]) async {
    return await _engine?.callFunction(name, params);
  }

  @override
  Widget build(BuildContext context, ExtensionApi api) {
    // 如果定义了动态界面，使用动态引擎
    if (metadata.view != null) {
      return DynamicEngine(engine: _engine!);
    }

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        Future.delayed(const Duration(milliseconds: 100)),
        api.getDbSize(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final dbSize = snapshot.data?[1] as int? ?? 0;
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(metadata.name)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Icon(
                  metadata.icon,
                  size: 80,
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  metadata.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '版本 ${metadata.version}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildTag(
                      theme,
                      '纯净模式 (仅元数据)',
                      color: theme.colorScheme.tertiaryContainer,
                      textColor: theme.colorScheme.onTertiaryContainer,
                    ),
                    _buildTag(
                      theme,
                      '存储占用: ${_formatSize(dbSize)}',
                      isSecondary: true,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildInfoSection(theme, '功能描述', metadata.description),
                _buildInfoSection(theme, '开发者', metadata.author),
                _buildInfoSection(theme, '唯一标识 (ID)', metadata.id),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                _buildDeveloperSandbox(theme, api),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeveloperSandbox(ThemeData theme, ExtensionApi api) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                '开发沙箱',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '此扩展目前作为“纯净壳”运行。你可以点击下方按钮测试其申请的权限是否生效。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSandboxAction(theme, '获取事件', Icons.list_alt, () async {
                try {
                  final events = await api.getEvents();
                  api.showSnackBar('成功获取 ${events.length} 个事件');
                } catch (e) {
                  api.showSnackBar('获取失败: $e');
                }
              }),
              _buildSandboxAction(
                theme,
                '发送通知',
                Icons.notification_important_outlined,
                () => api.showSnackBar('来自扩展沙箱的测试通知'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSandboxAction(
    ThemeData theme,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(
    ThemeData theme,
    String text, {
    bool isSecondary = false,
    Color? color,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:
            color ??
            (isSecondary
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color:
              textColor ??
              (isSecondary
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurfaceVariant),
          fontSize: 12,
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildInfoSection(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// 扩展管理器类
class ExtensionManager extends ChangeNotifier {
  final Ref _ref;

  /// 正在显示的隐私对话框，防止短时间内弹出多个
  final Set<String> _activePrivacyRequests = {};

  /// 正在运行的扩展实例 (extensionId -> Instance)
  final Map<String, BaseExtension> _activeExtensions = {};

  /// 外部调用入口扩展
  ProxyExtension? _externalCallExtension;

  /// 所有已安装的扩展“蓝图” (extensionId -> Instance/Proxy for metadata)
  final Map<String, BaseExtension> _installedExtensions = {};

  /// 扩展暂停时的事件缓冲区
  final Map<String, List<Event>> _eventBuffers = {};

  /// 安全限制：扩展文件最大建议大小 (1MB)
  static const _maxSafeSize = 1024 * 1024;

  ExtensionManager(this._ref) {
    _ensureServicesRegistered();
    if (kDebugMode) {
      _registerDebugServiceExtensions();
      _initDebugChannel();
    }
    Future.microtask(() => _init());
  }

  void _initDebugChannel() {
    const channel = MethodChannel('com.example.essenmelia/debug');
    channel.setMethodCallHandler((call) async {
      if (call.method == 'invokeApi') {
        final args = call.arguments as Map;
        final apiMethod = args['method'] as String?;
        final paramsJson = args['params'] as String? ?? '{}';
        final requestId = args['requestId'] as String?;

        if (apiMethod == null) return;

        try {
          final params = jsonDecode(paramsJson) as Map<String, dynamic>;

          // --- 核心变更：通过 ExternalCallExtension 进行分发 ---
          if (_externalCallExtension != null) {
            final result = await _externalCallExtension!.callJsFunction(
              'handleExternalRequest',
              {'method': apiMethod, 'params': params},
            );
            debugPrint('Debug API Result via Extension ($apiMethod): $result');

            // 如果有 requestId，尝试通过 MethodChannel 返回结果给原生层
            if (requestId != null) {
              channel.invokeMethod('apiResult', {
                'requestId': requestId,
                'result': jsonEncode(result),
                'success': true,
              });
            }
          } else {
            debugPrint('ExternalCallExtension is not installed or running');
            if (requestId != null) {
              channel.invokeMethod('apiResult', {
                'requestId': requestId,
                'error': 'ExternalCallExtension not installed or running',
                'success': false,
              });
            }
          }
        } catch (e) {
          debugPrint('Debug API Error: $e');
          if (requestId != null) {
            channel.invokeMethod('apiResult', {
              'requestId': requestId,
              'error': e.toString(),
              'success': false,
            });
          }
        }
      }
    });
  }

  void _registerDebugServiceExtensions() {
    // 注册调试接口：ext.essenmelia.invokeApi
    // 可以通过 adb 调用：
    // adb shell "vmservice-hook ext.essenmelia.invokeApi '{\"method\":\"getEvents\",\"params\":{},\"isUntrusted\":false}'"
    developer.registerExtension('ext.essenmelia.invokeApi', (
      method,
      parameters,
    ) async {
      final apiMethod = parameters['method'];
      if (apiMethod == null) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.invalidParams,
          'Missing method parameter',
        );
      }

      final paramsJson = parameters['params'] ?? '{}';

      try {
        final params = jsonDecode(paramsJson) as Map<String, dynamic>;

        // --- 核心变更：通过 ExternalCallExtension 进行分发 ---
        if (_externalCallExtension != null) {
          final result = await _externalCallExtension!.callJsFunction(
            'handleExternalRequest',
            {'method': apiMethod, 'params': params},
          );
          return developer.ServiceExtensionResponse.result(
            jsonEncode({'success': true, 'result': result}),
          );
        } else {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.extensionError,
            'ExternalCallExtension not initialized',
          );
        }
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Error executing API: $e',
        );
      }
    });
  }

  void _ensureServicesRegistered() {
    _ref.read(eventsExtensionServiceProvider);
    _ref.read(tagsExtensionServiceProvider);
    _ref.read(uiExtensionServiceProvider);
    _ref.read(systemExtensionServiceProvider);
    _ref.read(settingsExtensionServiceProvider);
  }

  Future<void> _init() async {
    // 初始化存储服务
    await _ref.read(extensionStoreServiceProvider.notifier).init();

    // 监听存储服务变更
    _ref.listen(extensionStoreServiceProvider, (previous, next) {
      if (previous != null && !mapEquals(previous, next)) {
        // 当存储内容发生变化时，重新加载动态扩展
        _loadDynamicExtensions();
      }
    });

    // 移除硬编码的外部调用入口初始化
    // 现在改为从本地存储加载，并在 refresh 时根据 ID 激活特定内置实例

    // 监听权限和状态变更
    _ref.listen(extensionAuthStateProvider, (previous, next) {
      if (previous != null) {
        // 1. 检查是否有新授予的权限
        for (var extId in next.keys) {
          if (extId.startsWith('untrusted_') ||
              extId.startsWith('running_') ||
              extId.startsWith('next_run_')) {
            continue;
          }

          final prevPerms = previous[extId] ?? [];
          final nextPerms = next[extId] ?? [];

          if (nextPerms.length > prevPerms.length) {
            final addedNames = nextPerms
                .where((p) => !prevPerms.contains(p))
                .toList();
            for (var name in addedNames) {
              try {
                final perm = ExtensionPermission.values.firstWhere(
                  (p) => p.name == name,
                );
                notifyPermissionGranted(extId, perm);
              } catch (_) {}
            }
          }
        }

        // 2. 只有当“运行状态”真正改变时才触发 refresh()
        // 这样可以避免 setPaused(true) 导致的 microtask 刷新循环
        bool runningChanged = false;
        final allIds = {...previous.keys, ...next.keys};
        for (var id in allIds) {
          if (id.startsWith('running_')) {
            if (!listEquals(previous[id], next[id])) {
              runningChanged = true;
              break;
            }
          }
        }

        if (runningChanged) {
          Future.microtask(() => refresh());
        }
      } else {
        // 首次加载
        Future.microtask(() => refresh());
      }
    });

    // 加载用户已安装的扩展清单（来自本地存储）
    await _loadDynamicExtensions();
  }

  Future<void> _loadDynamicExtensions() async {
    final installed = _ref.read(extensionStoreServiceProvider);

    // 清除现有的动态扩展蓝图（保留内置的）
    _installedExtensions.removeWhere((id, ext) => id != 'external_call');

    for (var entry in installed.entries) {
      final json = entry.value;
      try {
        final metadata = ExtensionMetadata.fromJson(jsonDecode(json));
        final extId = metadata.id;

        // 1. 严格 ID 绑定校验：清单中的 ID 必须与存储键匹配
        if (extId != entry.key) {
          debugPrint(
            'Security Alert: Extension ID mismatch for ${entry.key}. Manifest claims $extId. Skipping.',
          );
          continue;
        }

        // 2. 完整性校验：检查清单内容是否被非法篡改
        final auth = _ref.read(extensionAuthStateProvider.notifier);
        final storedHash = auth.getManifestHash(extId);
        if (storedHash != null) {
          final currentHash = sha256.convert(utf8.encode(json)).toString();
          if (currentHash != storedHash) {
            debugPrint(
              'Security Alert: Extension $extId manifest integrity check failed! Hash mismatch.',
            );
            // 发现篡改时，默认将其标记为不受信任且停止运行，保护用户隐私
            await auth.setUntrusted(extId, true);
            await auth.setRunning(extId, false);
          }
        }

        // 所有扩展初始都作为 Proxy 加载元数据
        _installedExtensions[extId] = ProxyExtension(metadata, manager: this);
      } catch (e) {
        debugPrint('Failed to load extension ${entry.key}: $e');
      }
    }
    // 加载完后刷新一次状态，根据运行状态和逻辑提供者激活真实实例
    refresh();
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 从剪贴板安装扩展（支持 JSON、URL 或 GitHub 链接）
  Future<void> importFromClipboard() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();

      if (text == null || text.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('剪贴板为空')));
        }
        return;
      }

      // 1. 尝试识别是否为 URL
      if (Uri.tryParse(text)?.hasAbsolutePath ?? false) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('检测到 URL，正在下载...')));
        }
        await importFromUrl(text);
        return;
      }

      // 2. 尝试作为内容安装 (JSON)
      await importFromContent(text);
    } catch (e) {
      debugPrint('Import from clipboard failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('剪贴板解析失败: $e')));
      }
    }
  }

  /// 导入扩展（从文件）
  Future<void> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      int successCount = 0;
      int totalCount = result.files.length;
      List<String> failedFiles = [];

      // 显示批量处理状态
      if (totalCount > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在准备安装 $totalCount 个扩展...'),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      for (var file in result.files) {
        if (file.path != null) {
          try {
            String? content;
            final extName = file.extension?.toLowerCase();
            if (extName == 'zip' || extName == 'ezip') {
              final bytes = await File(file.path!).readAsBytes();
              content = ExtensionConverter.extractContentFromZip(bytes);
            } else {
              // 支持 JSON 和 YAML
              final raw = await File(file.path!).readAsString();
              if (extName == 'yaml' ||
                  extName == 'yml' ||
                  (!raw.trim().startsWith('{') &&
                      !raw.trim().startsWith('['))) {
                try {
                  content = jsonEncode(
                    ExtensionMetadata.fromYaml(raw).toJson(),
                  );
                } catch (e) {
                  content = raw; // 可能是 JSON 但后缀写错了
                }
              } else {
                content = raw;
              }
            }

            if (content != null) {
              final ext = await importFromContent(content);
              if (ext != null) {
                successCount++;
              } else {
                failedFiles.add(file.name);
              }
            } else {
              failedFiles.add('${file.name} (解析失败)');
            }
          } catch (e) {
            debugPrint('Error reading file ${file.name}: $e');
            failedFiles.add(file.name);
          }
        }
      }

      if (!context.mounted) return;

      // 批量导入后的总结反馈
      if (totalCount > 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('批量导入完成'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('成功导入: $successCount / $totalCount'),
                if (failedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '以下文件导入失败或已取消:',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ...failedFiles
                      .take(5)
                      .map(
                        (f) => Text(
                          '• $f',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  if (failedFiles.length > 5)
                    Text(
                      '...等 ${failedFiles.length} 个文件',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      } else if (successCount == 1) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('扩展安装成功')));
      }
    }
  }

  /// 导入扩展（从链接/GitHub，支持 ZIP/JSON）
  Future<BaseExtension?> importFromUrl(String url) async {
    try {
      // 1. 处理内置扩展
      if (url.startsWith('builtin://')) {
        final id = url.replaceFirst('builtin://', '');
        return await installBuiltInExtensionById(id);
      }

      // 2. 特殊处理 GitHub 链接
      var finalUrl = url;
      if (url.contains('github.com') &&
          !url.contains('raw.githubusercontent.com') &&
          !url.endsWith('.zip')) {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.length == 2) {
          // 这是一个仓库主页，如 https://github.com/user/repo
          finalUrl =
              'https://github.com/${segments[0]}/${segments[1]}/archive/refs/heads/main.zip';
        } else if (url.contains('/blob/')) {
          // 这是一个具体文件的 blob 链接，转换为 raw
          finalUrl = url
              .replaceFirst('github.com', 'raw.githubusercontent.com')
              .replaceFirst('/blob/', '/');
        }
      }

      debugPrint('Downloading extension from: $finalUrl');
      final response = await http.get(Uri.parse(finalUrl));
      if (response.statusCode == 200) {
        // 如果响应头指示是 ZIP，或者 URL 以 .zip 结尾，尝试按字节处理
        final isZip =
            response.headers['content-type']?.contains('zip') == true ||
            finalUrl.toLowerCase().contains('.zip');

        if (isZip) {
          return await importFromBytes(
            response.bodyBytes,
            fileName: finalUrl.split('/').last,
          );
        } else {
          // 否则尝试作为 JSON 处理
          return await importFromContent(response.body);
        }
      }
    } catch (e) {
      debugPrint('Import from URL failed: $e');
    }
    return null;
  }

  /// 处理导入的二进制内容（主要用于 ZIP）
  Future<BaseExtension?> importFromBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    final content = ExtensionConverter.extractContentFromZip(bytes);
    if (content != null) {
      return await importFromContent(content);
    }
    debugPrint('Failed to extract content from ZIP bytes');
    return null;
  }

  /// 处理导入的内容（核心安装流程，支持新架构多文件）
  Future<BaseExtension?> importFromContent(
    String content, {
    String? logicJs,
    Map<String, dynamic>? viewYaml,
  }) async {
    debugPrint('Processing imported content, length: ${content.length}');
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('Error: navigatorKey.currentContext is null');
      return null;
    }

    try {
      // 1. 安全检查：大小限制
      if (content.length > _maxSafeSize) {
        final proceed = await _showSecurityWarningDialog(
          context,
          '扩展文件过大 (${(content.length / 1024).toStringAsFixed(1)} KB)',
          '大型扩展可能会消耗更多内存或包含大量恶意代码。是否继续加载？',
        );
        if (proceed != true) return null;
      }

      final Map<String, dynamic> data = jsonDecode(content);

      // 如果传入了独立的逻辑或视图，则注入到元数据中
      if (logicJs != null) data['logic'] = logicJs;
      if (viewYaml != null) data['view'] = viewYaml;

      final metadata = ExtensionMetadata.fromJson(data);
      debugPrint('Parsed metadata for extension: ${metadata.id}');

      // 检查是否已存在同名扩展（更新/降级逻辑）
      final oldExtension = _installedExtensions[metadata.id];
      String? oldContent;
      if (oldExtension != null) {
        oldContent = _ref
            .read(extensionStoreServiceProvider.notifier)
            .getExtensionContent(metadata.id);
      }

      if (!context.mounted) return null;

      final installResult = await _showInstallationConfirmDialog(
        context,
        metadata,
        jsonEncode(data),
        oldExtension?.metadata,
        oldContent,
      );

      if (installResult == null || installResult['confirmed'] != true) {
        return null;
      }

      final isUntrustedFromDialog = installResult['isUntrusted'] == true;

      // 使用存储服务保存扩展
      await _ref
          .read(extensionStoreServiceProvider.notifier)
          .saveExtension(metadata.id, jsonEncode(data));

      if (!context.mounted) return null;

      // 注册为占位符
      final newExt = ProxyExtension(metadata, manager: this);
      _installedExtensions[metadata.id] = newExt;

      // 确保新导入的扩展默认是运行状态
      final auth = _ref.read(extensionAuthStateProvider.notifier);
      await auth.setRunning(metadata.id, true);

      // 设置信任级别
      await auth.setUntrusted(metadata.id, isUntrustedFromDialog);

      // 保存清单哈希，用于完整性校验
      final manifestHash = sha256
          .convert(utf8.encode(jsonEncode(data)))
          .toString();
      await auth.setManifestHash(metadata.id, manifestHash);

      // 刷新管理器状态（会触发 _loadExtension）
      refresh();

      // 返回激活后的实例（如果有逻辑提供者，则是真实实例；否则是 Proxy）
      return _activeExtensions[metadata.id] ?? newExt;
    } catch (e) {
      debugPrint('Invalid extension format: $e');
      if (!context.mounted) return null;
      final retry = await _showErrorHandlingDialog(context, e.toString());
      if (retry) {
        // 如果用户选择忽略错误强制安装
      }
      return null;
    }
  }

  Future<bool> _showSecurityWarningDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消导入'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('风险自担，继续'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<bool> _showErrorHandlingDialog(
    BuildContext context,
    String error,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('扩展解析错误'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('导入扩展时发生错误，请检查内容格式是否正确（仅支持 JSON 或 ZIP 包）：'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      error,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('关闭'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<Map<String, dynamic>?> _showInstallationConfirmDialog(
    BuildContext context,
    ExtensionMetadata newMeta,
    String newContent,
    ExtensionMetadata? oldMeta,
    String? oldContent,
  ) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isUpdate = oldMeta != null;

    // 计算权限差异
    final newPerms = newMeta.requiredPermissions.toSet();
    final oldPerms = oldMeta?.requiredPermissions.toSet() ?? {};
    final addedPerms = newPerms.difference(oldPerms);
    final removedPerms = oldPerms.difference(newPerms);

    bool isUntrusted = false; // 默认不开启受限访问（即信任模式）

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              // Handle and Title
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUpdate
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isUpdate
                            ? Icons.system_update_alt
                            : Icons.add_box_outlined,
                        color: isUpdate
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSecondaryContainer,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        isUpdate ? l10n.extensionUpdate : l10n.extensionInstall,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    // Extension Info Card
                    Material(
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Hero(
                                tag: 'ext_icon_${newMeta.id}',
                                child: Icon(
                                  newMeta.icon,
                                  size: 40,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    newMeta.name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    newMeta.id,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Version & Info Section
                    Text(
                      l10n.extensionInformation,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDiffRow(
                      context,
                      l10n.extensionVersion,
                      oldMeta?.version ?? l10n.extensionNotInstalled,
                      newMeta.version,
                      isHighlight: oldMeta?.version != newMeta.version,
                    ),
                    _buildDiffRow(
                      context,
                      l10n.extensionCodeSize,
                      '${oldContent?.length ?? 0} chars',
                      '${newContent.length} chars',
                      isHighlight: oldContent?.length != newContent.length,
                    ),
                    if (isUpdate)
                      FutureBuilder<int>(
                        future: getExtensionDbSize(newMeta.id),
                        builder: (context, snapshot) {
                          final size = snapshot.data ?? 0;
                          return _buildDiffRow(
                            context,
                            l10n.extensionStorageSize,
                            _formatSize(size),
                            _formatSize(size),
                          );
                        },
                      ),
                    const SizedBox(height: 24),

                    // Security Card
                    Material(
                      color: isUntrusted
                          ? theme.colorScheme.errorContainer.withValues(
                              alpha: 0.1,
                            )
                          : theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.1,
                            ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: BorderSide(
                          color:
                              (isUntrusted
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary)
                                  .withValues(alpha: 0.2),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => setState(() => isUntrusted = !isUntrusted),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isUntrusted
                                      ? theme.colorScheme.error.withValues(
                                          alpha: 0.1,
                                        )
                                      : theme.colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isUntrusted
                                      ? Icons.security_rounded
                                      : Icons.verified_user_rounded,
                                  color: isUntrusted
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isUntrusted
                                          ? l10n.extensionRestrictedAccess
                                          : l10n.extensionFullTrust,
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isUntrusted
                                                ? theme.colorScheme.error
                                                : theme.colorScheme.primary,
                                          ),
                                    ),
                                    Text(
                                      isUntrusted
                                          ? l10n.extensionRestrictedAccessDesc
                                          : l10n.extensionFullTrustDesc,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isUntrusted,
                                onChanged: (val) =>
                                    setState(() => isUntrusted = val),
                                activeThumbColor: theme.colorScheme.error,
                                activeTrackColor:
                                    theme.colorScheme.errorContainer,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Permissions Section
                    Row(
                      children: [
                        Text(
                          l10n.extensionPermissionsStatement,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (isUpdate &&
                            addedPerms.isEmpty &&
                            removedPerms.isEmpty)
                          Text(
                            l10n.extensionNoChanges,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (newPerms.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          l10n.extensionNoPermissionsRequired,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            if (!isUpdate)
                              ...newPerms.map(
                                (p) => _buildPermissionItem(
                                  context,
                                  p,
                                  theme.colorScheme.primary,
                                ),
                              )
                            else ...[
                              ...addedPerms.map(
                                (p) => _buildPermissionItem(
                                  context,
                                  p,
                                  Colors.green,
                                  suffix: ' (+)',
                                ),
                              ),
                              ...removedPerms.map(
                                (p) => _buildPermissionItem(
                                  context,
                                  p,
                                  Colors.red,
                                  suffix: ' (-)',
                                  isRemoved: true,
                                ),
                              ),
                              ...newPerms
                                  .intersection(oldPerms)
                                  .map(
                                    (p) => _buildPermissionItem(
                                      context,
                                      p,
                                      theme.colorScheme.outline,
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, {
                          'confirmed': true,
                          'isUntrusted': isUntrusted,
                        }),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isUpdate
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(isUpdate ? l10n.update : l10n.install),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiffRow(
    BuildContext context,
    String label,
    String oldVal,
    String newVal, {
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                if (oldVal != newVal) ...[
                  Flexible(
                    child: Text(
                      oldVal,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline.withValues(alpha: 0.7),
                        decoration: TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
                Flexible(
                  child: Text(
                    newVal,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isHighlight
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isHighlight
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(
    BuildContext context,
    ExtensionPermission permission,
    Color color, {
    String suffix = '',
    bool isRemoved = false,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final registry = _ref.read(extensionApiRegistryProvider);
    final permApis = registry.getRequiredPermissions()[permission] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(permission.icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${permission.getLabel(l10n)}$suffix',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    decoration: isRemoved ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  permission.getDescription(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    decoration: isRemoved ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (permApis.isNotEmpty && !isRemoved) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: permApis.map((api) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          api.getOperation(l10n) ?? api.methodName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取可用的内置扩展列表（以仓库扩展格式返回，统一 UI 处理）
  List<RepositoryExtension> getBuiltInExtensions() {
    return [
      RepositoryExtension(
        id: 'system.external_call',
        name: '指令网关',
        description: '系统级外部请求监控中心。负责拦截、验证并处理来自 ADB、Intent 或第三方应用的 API 调用。',
        author: 'System',
        version: '2.1.0',
        downloadUrl: 'builtin://system.external_call',
        tags: ['System', 'Gateway', 'API'],
      ),
      RepositoryExtension(
        id: 'com.essenmelia.kitchen_sink',
        name: '全能演示 (Kitchen Sink)',
        description: '展示所有可用组件、API 指令与 JS 逻辑的参考扩展 (JS/YAML)',
        author: 'Essenmelia Team',
        version: '2.0.0',
        downloadUrl: 'builtin://com.essenmelia.kitchen_sink',
        tags: ['Demo', 'Reference', 'Kitchen Sink'],
      ),
      RepositoryExtension(
        id: 'com.essenmelia.api_tester',
        name: 'API 测试工具',
        description: '测试扩展 API 的功能与响应 (JS/YAML)',
        author: 'Essenmelia',
        version: '2.0.0',
        downloadUrl: 'builtin://com.essenmelia.api_tester',
        tags: ['Tool', 'Debug', 'API'],
      ),
      RepositoryExtension(
        id: 'com.essenmelia.event_test',
        name: '事件列表测试',
        description: '展示并操作系统中的事件 (JS/YAML)',
        author: 'Essenmelia Team',
        version: '2.0.0',
        downloadUrl: 'builtin://com.essenmelia.event_test',
        tags: ['Test', 'Events'],
      ),
    ];
  }

  /// 根据 ID 安装内置扩展
  Future<BaseExtension?> installBuiltInExtensionById(String id) async {
    // 找到对应的内置仓库条目
    final builtInList = getBuiltInExtensions();
    final repoExt = builtInList.firstWhere(
      (e) => e.id == id,
      orElse: () => throw Exception('Built-in extension not found: $id'),
    );

    // 1. 优先尝试从 Assets 加载（新的文件夹结构）
    try {
      final manifestStr = await rootBundle.loadString(
        'assets/extensions/$id/manifest.yaml',
      );
      final manifestMap = ExtensionMetadata.yamlToMap(manifestStr);

      // 加载配套文件并合并到 Map 中
      try {
        final viewStr = await rootBundle.loadString(
          'assets/extensions/$id/view.yaml',
        );
        manifestMap['view'] = ExtensionMetadata.yamlToMap(viewStr);
      } catch (_) {}

      try {
        final logicStr = await rootBundle.loadString(
          'assets/extensions/$id/logic.yaml',
        );
        manifestMap['logic'] = ExtensionMetadata.yamlToMap(logicStr);
      } catch (_) {}

      // 加载脚本文件
      try {
        final scriptStr = await rootBundle.loadString(
          'assets/extensions/$id/main.js',
        );
        manifestMap['script'] = scriptStr;
      } catch (_) {}

      // 从完整的 Map 实例化元数据，避免中途类型转换错误
      final metadata = ExtensionMetadata.fromJson(manifestMap);
      final result = await importFromContent(jsonEncode(metadata.toJson()));
      return result;
    } catch (e) {
      debugPrint(
        'Offline asset not found for $id, using generated metadata: $e',
      );

      // 如果没有 Asset，根据内置列表生成基础元数据
      final metadata = ExtensionMetadata(
        id: repoExt.id,
        name: repoExt.name,
        description: repoExt.description,
        author: repoExt.author,
        version: repoExt.version,
        icon: Icons.extension,
      );
      return await importFromContent(jsonEncode(metadata.toJson()));
    }
  }

  /// 导出扩展（ZIP 格式）
  Future<void> exportExtensionAsZip(String extensionId) async {
    final ext =
        _installedExtensions[extensionId] ?? _activeExtensions[extensionId];
    if (ext == null) return;

    final zipBytes = ExtensionConverter.createZipPackage(ext.metadata);

    final tempDir = await getTemporaryDirectory();
    final fileName = '${ext.metadata.id}_v${ext.metadata.version}.ezip';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(zipBytes);

    await Share.shareXFiles([
      XFile(file.path),
    ], subject: '导出扩展包 (ZIP): ${ext.metadata.name}');
  }

  Future<void> exportExtension(String extensionId) async {
    final ext =
        _installedExtensions[extensionId] ?? _activeExtensions[extensionId];
    if (ext == null) return;

    // 统一将其序列化为标准的 JSON 格式进行分发
    final data = ext.metadata.toJson();
    final exportContent = const JsonEncoder.withIndent('  ').convert(data);
    final fileName = '${ext.metadata.id}.json';

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(exportContent);

    await Share.shareXFiles([
      XFile(file.path),
    ], subject: '导出扩展包: ${ext.metadata.name}');
  }

  void _loadExtension(BaseExtension extension) {
    final extId = extension.metadata.id;
    // _activeExtensions 记录实例，但不在这里应用“下次允许”权限，
    // 改为在 API 调用时由 _shieldIntercept 实时消费。

    _activeExtensions[extId] = extension;
    final api = getApiFor(extension);
    extension.onInit(api);
  }

  void _unloadExtension(String extensionId) {
    final extension = _activeExtensions.remove(extensionId);
    if (extension != null) {
      extension.onDispose();
      _eventBuffers.remove(extensionId);

      // 如果卸载的是外部调用入口，清除引用
      if (extensionId == 'system.external_call') {
        _externalCallExtension = null;
      }
    }
  }

  /// 供 UI 调用：刷新扩展列表（根据运行状态加载/卸载实例）
  void refresh() {
    final auth = _ref.read(extensionAuthStateProvider.notifier);

    for (var entry in _installedExtensions.entries) {
      final id = entry.key;
      final isRunning = auth.isRunning(id);
      final isLoaded = _activeExtensions.containsKey(id);

      if (isRunning && !isLoaded) {
        // 需要启动
        final realExt = ProxyExtension(entry.value.metadata, manager: this);
        if (id == 'system.external_call') {
          _externalCallExtension = realExt;
        }
        _loadExtension(realExt);
      } else if (!isRunning && isLoaded) {
        // 需要停止
        _unloadExtension(id);
      }
    }

    // 无论运行状态是否改变，只要调用了 refresh，就通知 UI 刷新一次，
    // 以确保初始化加载的扩展能显示出来。
    notifyListeners();
  }

  /// 重置所有扩展相关数据（格式化）
  Future<void> resetAll() async {
    // 1. 停止所有正在运行的扩展
    for (var id in _activeExtensions.keys.toList()) {
      _unloadExtension(id);
    }
    _activeExtensions.clear();
    _externalCallExtension = null;
    _eventBuffers.clear();

    // 2. 重置权限和状态存储
    await _ref.read(extensionAuthStateProvider.notifier).resetAll();

    // 3. 卸载所有已安装扩展并清除存储
    final store = _ref.read(extensionStoreServiceProvider.notifier);
    final installedIds = _installedExtensions.keys
        .where((id) => id != 'external_call')
        .toList();

    // 先清除每个扩展的私有盒子
    for (var id in installedIds) {
      await Hive.deleteBoxFromDisk('extension_storage_$id');
      await Hive.deleteBoxFromDisk('extension_logs_$id');
    }

    // 批量清除元数据存储
    await store.clearAll();

    _installedExtensions.removeWhere((id, _) => id != 'external_call');

    // 4. 清除会话权限
    _ref.read(sessionPermissionsProvider.notifier).state = {};

    notifyListeners();
  }

  /// 通知权限变更（事后授权模式）
  void notifyPermissionGranted(
    String extensionId,
    ExtensionPermission permission,
  ) {
    final ext = _activeExtensions[extensionId];
    if (ext != null) {
      ext.onPermissionGranted(permission);
    }
  }

  /// 分发跨扩展事件
  void broadcastEvent(
    String name,
    Map<String, dynamic> data, {
    String? senderId,
  }) {
    final auth = _ref.read(extensionAuthStateProvider.notifier);

    for (var ext in _activeExtensions.values) {
      final id = ext.metadata.id;
      // 不发给自己，且必须在运行中
      if (id == senderId || !auth.isRunning(id)) continue;

      try {
        ext.onExtensionEvent(name, data);
      } catch (e) {
        debugPrint('Error delivering event $name to extension $id: $e');
      }
    }
  }

  /// 分发事件并处理缓冲
  void notifyEventAdded(Event event) {
    final auth = _ref.read(extensionAuthStateProvider.notifier);

    for (var ext in _activeExtensions.values) {
      final id = ext.metadata.id;
      if (!auth.isRunning(id)) continue;

      if (auth.isPaused(id)) {
        // 扩展暂停中，存入缓冲区
        _eventBuffers.putIfAbsent(id, () => []).add(event);
      } else {
        // 正常运行，直接分发
        ext.onEventAdded(event);
      }
    }
  }

  /// 获取扩展数据库文件的大致大小
  Future<int> getExtensionDbSize(String extensionId) async {
    final handler = _ref
        .read(extensionApiRegistryProvider)
        .getHandler('getDbSize');
    if (handler != null) {
      final result = await handler({
        'extensionId': extensionId,
      }, isUntrusted: false);
      return result as int? ?? 0;
    }
    return 0;
  }

  /// 恢复扩展并清空缓冲区
  void resumeExtension(String extensionId) {
    final auth = _ref.read(extensionAuthStateProvider.notifier);
    if (auth.isPaused(extensionId)) {
      auth.setPaused(extensionId, false);

      final ext = _activeExtensions[extensionId];
      final buffer = _eventBuffers.remove(extensionId);

      if (ext != null && buffer != null) {
        for (var event in buffer) {
          ext.onEventAdded(event);
        }
      }
    }
  }

  List<BaseExtension> get extensions {
    // 必须返回最新的实例（如果已启动则返回真实实例，否则返回蓝图/占位符）
    return _installedExtensions.keys.map((id) {
      return _activeExtensions[id] ?? _installedExtensions[id]!;
    }).toList();
  }

  ExtensionApi getApiFor(BaseExtension extension) {
    return ExtensionApiImpl(_ref, extension.metadata, this);
  }

  /// 完全卸载扩展
  Future<void> removeExtension(String extensionId) async {
    // 1. 先清除权限和运行状态
    await _ref
        .read(extensionAuthStateProvider.notifier)
        .uninstallExtension(extensionId);

    // 2. 卸载实例
    _unloadExtension(extensionId);
    _installedExtensions.remove(extensionId);

    // 3. 从持久化存储中移除
    await _ref
        .read(extensionStoreServiceProvider.notifier)
        .removeExtension(extensionId);

    notifyListeners();
  }
}
