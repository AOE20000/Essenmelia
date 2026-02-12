import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dynamic_engine.dart';

import 'base_extension.dart';
import '../models/event.dart';
import '../providers/db_provider.dart';
import '../providers/events_provider.dart';
import '../providers/tags_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/filtered_events_provider.dart';
import 'utils/mock_data_generator.dart';
import 'widgets/permission_management_dialog.dart';

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

    // 7. 更新状态触发 UI 刷新
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

    // 映射权限到“受限访问”类别
    final categoryMap = {
      ExtensionPermission.readEvents: '数据读取',
      ExtensionPermission.writeEvents: '数据写入',
      ExtensionPermission.readTags: '数据读取',
      ExtensionPermission.network: '网络访问',
      ExtensionPermission.fileSystem: '文件操作',
    };

    final category = categoryMap[permission];
    if (category != null && sessionPerms.contains(category)) {
      return true;
    }

    return false;
  }

  String _getSandboxId() {
    return _ref
        .read(extensionAuthStateProvider.notifier)
        .getSandboxId(_metadata.id);
  }

  /// 权限管理拦截逻辑 (非阻塞 + 事后授权模式)
  Future<bool> _shieldIntercept(String operation, String category) async {
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
    if (await notifier.consumeNextRunPermission(extId, category)) {
      return true;
    }

    // 检查本次会话是否已允许
    final sessionPerms = _ref.read(sessionPermissionsProvider)[extId] ?? {};
    if (sessionPerms.contains('all') || sessionPerms.contains(category)) {
      return true;
    }

    // --- 核心变更：不再等待弹窗，而是立即“暂停”扩展并返回假数据 ---

    // 1. 标记暂停，防止事件干扰
    notifier.setPaused(extId, true);

    // 2. 异步弹出对话框（不 await）
    // 使用 unawaited 避免 lint 警告，确保这是一个真正的 Fire-and-Forget
    _showPrivacyDialogAsync(operation, category);

    // 3. 模拟正常耗时后返回 false (引导扩展使用假数据)
    await Future.delayed(Duration(milliseconds: 150 + (extId.hashCode % 150)));
    return false;
  }

  void _showPrivacyDialogAsync(String operation, String category) {
    final requestId = '${_metadata.id}_$category';

    // 1. 如果当前扩展的这个类别的请求已经在处理中，直接忽略
    if (_manager._activePrivacyRequests.contains(requestId)) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    _manager._activePrivacyRequests.add(requestId);

    Future.microtask(() async {
      try {
        // 2. 等待之前的对话框关闭，增加超时机制防止多个弹窗重叠导致 ANR
        if (_isDialogShowing && _currentDialogFuture != null) {
          debugPrint(
            'Shield: Waiting for previous dialog to close for $requestId',
          );
          await _currentDialogFuture!.timeout(
            const Duration(seconds: 3),
            onTimeout: () => debugPrint('Shield: Wait timeout for $requestId'),
          );
        }

        // 3. 再次检查是否还需要显示（可能在等待期间已经被允许了）
        final authNotifier = _ref.read(extensionAuthStateProvider.notifier);
        if (!authNotifier.isPaused(_metadata.id)) {
          return;
        }

        // 如果之前的对话框还在显示（超时后），则跳过本次，避免堆叠
        if (_isDialogShowing) {
          debugPrint('Shield: Skipping dialog for $requestId due to overlap');
          return;
        }

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
            if (decision == PermissionManagementDecision.allowNextRun) {
              await authNotifier.setNextRunPermission(_metadata.id, category);
            } else {
              _ref.read(sessionPermissionsProvider.notifier).update((state) {
                final newState = Map<String, Set<String>>.from(state);
                final extPerms = Set<String>.from(newState[_metadata.id] ?? {});
                if (decision ==
                    PermissionManagementDecision.allowCategoryOnce) {
                  extPerms.add(category);
                } else if (decision ==
                    PermissionManagementDecision.allowAllOnce) {
                  extPerms.add('all');
                }
                newState[_metadata.id] = extPerms;
                return newState;
              });

              final permissionMapping = {
                '数据读取': ExtensionPermission.readEvents,
                '数据写入': ExtensionPermission.writeEvents,
                '网络访问': ExtensionPermission.network,
                '文件系统': ExtensionPermission.fileSystem,
              };

              final grantedPerm = permissionMapping[category];
              if (grantedPerm != null) {
                _manager.notifyPermissionGranted(_metadata.id, grantedPerm);
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
    final notifier = _ref.read(extensionAuthStateProvider.notifier);
    final extId = _metadata.id;

    // 强制检查运行状态
    if (!notifier.isRunning(extId)) {
      return MockDataGenerator.generateEvents(count: 3);
    }

    // “受限访问”拦截 (异步非阻塞，如果拦截则立即返回 false)
    final intercepted = !await _shieldIntercept('读取您的所有任务列表和步骤', '数据读取');

    final eventsAsync = _ref.read(eventsProvider);
    final realEvents = eventsAsync.when(
      data: (events) => events,
      loading: () => <Event>[],
      error: (_, _) => <Event>[],
    );
    // 获取沙箱数据
    final sandboxEvents = _manager._virtualEvents[_getSandboxId()] ?? [];

    if (intercepted || !_checkPermission(ExtensionPermission.readEvents)) {
      // 如果被拦截或无权限，返回 [沙箱数据] + [模拟假数据]
      // 关键点：必须包含沙箱数据，让扩展确信之前的写入成功了
      return [
        ...sandboxEvents,
        ...MockDataGenerator.generateEvents(
          count: 12,
          realData: realEvents,
          mixReal: true,
        ),
      ];
    }

    // 有权限时，返回 [真实数据] + [沙箱数据]
    return [...realEvents, ...sandboxEvents];
  }

  @override
  Future<List<String>> getTags() async {
    final intercepted = !await _shieldIntercept('查看您创建的所有标签', '数据读取');

    final tagsAsync = _ref.read(tagsProvider);
    final realTags = tagsAsync.when(
      data: (tags) => tags,
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );

    final sandboxTags = _manager._virtualTags[_getSandboxId()] ?? [];

    if (intercepted || !_checkPermission(ExtensionPermission.readTags)) {
      final mockTags = ['工作', '生活', '学习', '健康', '重要'];
      // 合并沙箱标签
      final combined = {...mockTags, ...sandboxTags}.toList();
      return combined..shuffle();
    }

    return [...realTags, ...sandboxTags];
  }

  @override
  void navigateTo(String route) {
    _shieldIntercept('将页面跳转至 $route', '界面导航').then((allowed) {
      if (allowed) {
        // 执行导航
      }
    });
  }

  @override
  void showSnackBar(String message) {
    final notifier = _ref.read(extensionAuthStateProvider.notifier);
    final extId = _metadata.id;

    if (!notifier.isRunning(extId)) return;

    // 欺骗增强：如果扩展试图在隐身模式下发送看起来像“权限错误”的消息来试探系统，
    // 我们将其拦截，防止其干扰用户或暴露拦截状态。
    if (notifier.isUntrusted(extId)) {
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains('permission') ||
          lowerMsg.contains('权限') ||
          lowerMsg.contains('denied') ||
          lowerMsg.contains('缺少')) {
        debugPrint(
          'Shield: Blocked suspicious snackbar from untrusted extension: $message',
        );
        return;
      }
    }

    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Future<bool> exportFile(String content, String fileName) async {
    final intercepted = !await _shieldIntercept(
      '导出文件并调起系统分享: $fileName',
      '文件操作',
    );

    if (intercepted || !_checkPermission(ExtensionPermission.fileSystem)) {
      // 欺骗：即便没导出，也返回 true 让扩展认为操作成功
      _handlePermissionError(ExtensionPermission.fileSystem);
      return true;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        fileNameOverrides: [fileName],
      );
      return result.status == ShareResultStatus.success;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> pickFile({List<String>? allowedExtensions}) async {
    final intercepted = !await _shieldIntercept('从您的设备选择并读取文件', '文件操作');

    if (intercepted || !_checkPermission(ExtensionPermission.fileSystem)) {
      // 欺骗：返回一段模拟的 CSV 或 JSON 内容
      _handlePermissionError(ExtensionPermission.fileSystem);
      return 'id,name,date\n1,Sample Task,2026-02-11\n2,Mock Data,2026-02-12';
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        return utf8.decode(result.files.single.bytes!);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
    return null;
  }

  @override
  Future<String?> httpGet(String url, {Map<String, String>? headers}) async {
    final intercepted = !await _shieldIntercept('访问网络: $url', '网络访问');

    if (intercepted || !_checkPermission(ExtensionPermission.network)) {
      _handlePermissionError(ExtensionPermission.network);
      // 欺骗：根据 URL 返回一些模拟的 JSON
      if (url.contains('api')) {
        return jsonEncode({
          'status': 'success',
          'data': {'info': 'This is mock response from Shield'},
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
      return '<html><body><h1>Success</h1><p>Mock Content</p></body></html>';
    }

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Network error (GET): $e');
    }
    return null;
  }

  @override
  Future<String?> httpPost(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final intercepted = !await _shieldIntercept('发送网络数据到: $url', '网络访问');

    if (intercepted || !_checkPermission(ExtensionPermission.network)) {
      _handlePermissionError(ExtensionPermission.network);
      return jsonEncode({
        'status': 'received',
        'id': 'mock_${DateTime.now().millisecond}',
        'message': 'Data accepted (Mocked)',
      });
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Network error (POST): $e');
    }
    return null;
  }

  @override
  Future<String?> httpPut(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final intercepted = !await _shieldIntercept('更新网络数据: $url', '网络访问');

    if (intercepted || !_checkPermission(ExtensionPermission.network)) {
      _handlePermissionError(ExtensionPermission.network);
      return jsonEncode({
        'status': 'updated',
        'message': 'Data updated (Mocked)',
      });
    }

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Network error (PUT): $e');
    }
    return null;
  }

  @override
  Future<String?> httpDelete(String url, {Map<String, String>? headers}) async {
    final intercepted = !await _shieldIntercept('删除网络资源: $url', '网络访问');

    if (intercepted || !_checkPermission(ExtensionPermission.network)) {
      _handlePermissionError(ExtensionPermission.network);
      return jsonEncode({
        'status': 'deleted',
        'message': 'Resource deleted (Mocked)',
      });
    }

    try {
      final response = await http.delete(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Network error (DELETE): $e');
    }
    return null;
  }

  @override
  Future<void> openUrl(String url) async {
    final intercepted = !await _shieldIntercept('在浏览器中打开链接: $url', '网络访问');

    if (intercepted || !_checkPermission(ExtensionPermission.network)) {
      _handlePermissionError(ExtensionPermission.network);
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  void publishEvent(String name, Map<String, dynamic> data) {
    _manager.broadcastEvent(name, data, senderId: _metadata.id);
  }

  @override
  void setSearchQuery(String query) {
    _ref.read(searchProvider.notifier).setQuery(query);
  }

  void _handlePermissionError(ExtensionPermission permission) {
    final notifier = _ref.read(extensionAuthStateProvider.notifier);
    final extId = _metadata.id;

    // 彻底静默：在任何模式下，API 调用产生的权限错误都不再弹出 Snackbar
    // 这是为了实现“黑盒欺骗”，让扩展和用户（在欺骗期间）都感知不到权限拦截
    debugPrint(
      'Shield: Intercepted ${permission.name} for $extId (Untrusted: ${notifier.isUntrusted(extId)})',
    );
  }

  @override
  Future<void> addEvent({
    required String title,
    String? description,
    List<String>? tags,
  }) async {
    final intercepted = !await _shieldIntercept('创建新任务: $title', '数据写入');

    if (intercepted || !_checkPermission(ExtensionPermission.writeEvents)) {
      // 写入虚拟沙箱，实现黑盒欺骗
      final virtualEvent = Event()
        ..title = '[模拟] $title'
        ..description = description
        ..createdAt = DateTime.now()
        ..tags = tags;

      final sandboxId = _getSandboxId();
      _manager._virtualEvents[sandboxId] = [
        ...(_manager._virtualEvents[sandboxId] ?? []),
        virtualEvent,
      ];

      _handlePermissionError(ExtensionPermission.writeEvents);
      return;
    }

    await _ref
        .read(eventsProvider.notifier)
        .addEvent(title: title, description: description, tags: tags);
  }

  @override
  Future<void> deleteEvent(String id) async {
    final intercepted = !await _shieldIntercept('删除任务', '数据写入');

    if (intercepted || !_checkPermission(ExtensionPermission.writeEvents)) {
      // 从虚拟沙箱中移除
      _manager._virtualEvents[_getSandboxId()]?.removeWhere((e) => e.id == id);
      _handlePermissionError(ExtensionPermission.writeEvents);
      return;
    }

    await _ref.read(eventsProvider.notifier).deleteEvent(id);
  }

  @override
  Future<void> updateEvent(Event event) async {
    final intercepted = !await _shieldIntercept('修改任务: ${event.title}', '数据写入');

    if (intercepted || !_checkPermission(ExtensionPermission.writeEvents)) {
      // 更新虚拟沙箱
      final sandbox = _manager._virtualEvents[_getSandboxId()] ?? [];
      final index = sandbox.indexWhere((e) => e.id == event.id);
      if (index != -1) {
        sandbox[index] = event;
      }
      _handlePermissionError(ExtensionPermission.writeEvents);
      return;
    }

    // 在 Hive 中直接 put 会覆盖旧值
    final box = Hive.box<Event>('${_ref.read(activePrefixProvider)}_events');
    await box.put(event.id, event);
  }

  @override
  Future<void> addStep(String eventId, String description) async {
    final intercepted = !await _shieldIntercept('为任务添加步骤', '数据写入');

    if (intercepted || !_checkPermission(ExtensionPermission.writeEvents)) {
      // 更新虚拟沙箱中的任务步骤
      final sandbox = _manager._virtualEvents[_getSandboxId()] ?? [];
      final event = sandbox.where((e) => e.id == eventId).firstOrNull;
      if (event != null) {
        final step = EventStep()
          ..description = description
          ..timestamp = DateTime.now();
        event.steps = [...event.steps, step];
      }
      _handlePermissionError(ExtensionPermission.writeEvents);
      return;
    }

    await _ref.read(eventsProvider.notifier).addStep(eventId, description);
  }

  @override
  Future<void> addTag(String tag) async {
    final intercepted = !await _shieldIntercept('添加新标签: $tag', '数据写入');

    if (intercepted || !_checkPermission(ExtensionPermission.writeEvents)) {
      // 写入虚拟沙箱
      final sandboxId = _getSandboxId();
      final current = _manager._virtualTags[sandboxId] ?? [];
      if (!current.contains(tag)) {
        _manager._virtualTags[sandboxId] = [...current, tag];
      }
      _handlePermissionError(ExtensionPermission.writeEvents);
      return;
    }

    await _ref.read(tagsProvider.notifier).addTag(tag);
  }

  @override
  Future<int> getDbSize() async {
    return _manager.getExtensionDbSize(_metadata.id);
  }

  @override
  String getThemeMode() {
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
    final locale = _ref.read(localeProvider);
    return locale?.languageCode ?? 'zh';
  }

  @override
  Future<T?> getSetting<T>(String key) async {
    // 先查虚拟沙箱设置
    final sandboxSettings = _manager._virtualSettings[_getSandboxId()];
    if (sandboxSettings != null && sandboxSettings.containsKey(key)) {
      return sandboxSettings[key] as T?;
    }

    // 再查真实 Hive 存储
    final extId = _metadata.id;
    final box = await Hive.openBox('ext_$extId');
    return box.get(key) as T?;
  }

  @override
  Future<void> saveSetting<T>(String key, T value) async {
    final extId = _metadata.id;
    final notifier = _ref.read(extensionAuthStateProvider.notifier);

    // 如果是不信任模式，且没有持久化权限（即可能是流氓行为），我们优先存入沙箱
    if (notifier.isUntrusted(extId)) {
      final sandboxId = _getSandboxId();
      final sandbox = _manager._virtualSettings[sandboxId] ?? {};
      sandbox[key] = value;
      _manager._virtualSettings[sandboxId] = sandbox;
      return;
    }

    // 正常模式下存入 Hive
    final box = await Hive.openBox('ext_$extId');
    await box.put(key, value);
  }
}

/// 动态加载的扩展占位符
class ProxyExtension extends BaseExtension {
  final ExtensionManager? manager;
  void Function(String, Map<String, dynamic>)? _eventHandler;

  ProxyExtension(super.metadata, {this.manager});

  @override
  void onExtensionEvent(String name, Map<String, dynamic> data) {
    _eventHandler?.call(name, data);
  }

  @override
  Widget build(BuildContext context, ExtensionApi api) {
    // 如果定义了动态界面或逻辑，使用动态引擎
    if (metadata.view != null || metadata.logic != null) {
      return DynamicEngine(
        metadata: metadata,
        api: api,
        onRegister: (handler) => _eventHandler = handler,
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        Future.delayed(const Duration(milliseconds: 100)),
        manager != null
            ? manager!.getExtensionDbSize(metadata.id)
            : Future.value(0),
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

  /// 所有已安装的扩展“蓝图” (extensionId -> Instance/Proxy for metadata)
  final Map<String, BaseExtension> _installedExtensions = {};

  /// 存储动态加载的扩展元数据（用于持久化）
  static const _extStoreBox = 'dynamic_extensions_metadata';

  /// 安全限制：扩展文件最大建议大小 (1MB)
  static const _maxSafeSize = 1024 * 1024;

  /// 事件缓冲区：当扩展暂停时，暂存新产生的事件
  final Map<String, List<Event>> _eventBuffers = {};

  /// 虚拟沙箱存储：用于在隐身模式下存储扩展的“虚假写入”数据，实现完美欺骗
  final Map<String, List<Event>> _virtualEvents = {};
  final Map<String, List<String>> _virtualTags = {};
  final Map<String, Map<String, dynamic>> _virtualSettings = {};

  ExtensionManager(this._ref) {
    Future.microtask(() => _init());
  }

  Future<void> _init() async {
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
    final box = await Hive.openBox(_extStoreBox);
    for (var key in box.keys) {
      final json = box.get(key);
      if (json != null) {
        try {
          final metadata = ExtensionMetadata.fromJson(jsonDecode(json));
          // 所有扩展初始都作为 Proxy 加载元数据
          _installedExtensions[metadata.id] = ProxyExtension(
            metadata,
            manager: this,
          );
        } catch (e) {
          debugPrint('Failed to load extension $key: $e');
        }
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

  /// 导入扩展（从文件）
  Future<void> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip'],
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
            final content = await File(file.path!).readAsString();
            final ext = await _processImportedContent(content);
            if (ext != null) {
              successCount++;
            } else {
              failedFiles.add(file.name);
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

  /// 导入扩展（从链接/GitHub）
  Future<BaseExtension?> importFromUrl(String url) async {
    try {
      // 简单处理 GitHub 链接：将 github.com 转换为 raw.githubusercontent.com
      var finalUrl = url;
      if (url.contains('github.com') &&
          !url.contains('raw.githubusercontent.com')) {
        finalUrl = url
            .replaceFirst('github.com', 'raw.githubusercontent.com')
            .replaceFirst('/blob/', '/');
      }

      final response = await http.get(Uri.parse(finalUrl));
      if (response.statusCode == 200) {
        return await _processImportedContent(response.body);
      }
    } catch (e) {
      debugPrint('Import failed: $e');
    }
    return null;
  }

  Future<BaseExtension?> _processImportedContent(String content) async {
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

      final data = jsonDecode(content);
      final metadata = ExtensionMetadata.fromJson(data);
      debugPrint('Parsed metadata for extension: ${metadata.id}');

      // 检查是否已存在同名扩展（更新/降级逻辑）
      final oldExtension = _installedExtensions[metadata.id];
      String? oldContent;
      if (oldExtension != null) {
        final box = await Hive.openBox(_extStoreBox);
        oldContent = box.get(metadata.id);
      }

      if (!context.mounted) return null;

      final installResult = await _showInstallationConfirmDialog(
        context,
        metadata,
        content,
        oldExtension?.metadata,
        oldContent,
      );

      if (installResult == null || installResult['confirmed'] != true) {
        return null;
      }

      final isUntrustedFromDialog = installResult['isUntrusted'] == true;

      final box = await Hive.openBox(_extStoreBox);
      await box.put(metadata.id, content);

      if (!context.mounted) return null;

      // 注册为占位符
      final newExt = ProxyExtension(metadata, manager: this);
      _installedExtensions[metadata.id] = newExt;

      // 确保新导入的扩展默认是运行状态
      final auth = _ref.read(extensionAuthStateProvider.notifier);
      await auth.setRunning(metadata.id, true);

      // 设置信任级别
      await auth.setUntrusted(metadata.id, isUntrustedFromDialog);

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
                const Text('导入扩展时发生错误，请检查 JSON 格式是否正确：'),
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
    final locale = Localizations.maybeLocaleOf(context);
    final isEn = locale?.languageCode == 'en';
    final isUpdate = oldMeta != null;

    // 计算权限差异
    final newPerms = newMeta.requiredPermissions.toSet();
    final oldPerms = oldMeta?.requiredPermissions.toSet() ?? {};
    final addedPerms = newPerms.difference(oldPerms);
    final removedPerms = oldPerms.difference(newPerms);

    bool isUntrusted = false; // 默认不开启隐身盾（即信任模式）

    return showGeneralDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (context, anim1, anim2, child) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Transform.scale(
              scale: anim1.value,
              child: Opacity(
                opacity: anim1.value,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUpdate
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isUpdate
                              ? Icons.system_update_alt
                              : Icons.download_done,
                          color: isUpdate
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSecondaryContainer,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          isUpdate
                              ? (isEn ? 'Update Extension' : '更新扩展')
                              : (isEn ? 'Install Extension' : '安装扩展'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Hero(
                                  tag: 'ext_icon_${newMeta.id}',
                                  child: Icon(
                                    newMeta.icon,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        newMeta.name,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        newMeta.id,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
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
                          const SizedBox(height: 24),
                          Text(
                            isEn ? 'Information' : '版本详情',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDiffRow(
                            context,
                            isEn ? 'Version' : '版本',
                            oldMeta?.version ?? (isEn ? 'N/A' : '未安装'),
                            newMeta.version,
                            isHighlight: oldMeta?.version != newMeta.version,
                          ),
                          _buildDiffRow(
                            context,
                            isEn ? 'Size' : '代码量',
                            '${oldContent?.length ?? 0} chars',
                            '${newContent.length} chars',
                            isHighlight:
                                oldContent?.length != newContent.length,
                          ),
                          if (isUpdate)
                            FutureBuilder<int>(
                              future: getExtensionDbSize(newMeta.id),
                              builder: (context, snapshot) {
                                final size = snapshot.data ?? 0;
                                return _buildDiffRow(
                                  context,
                                  isEn ? 'Storage' : '数据占用',
                                  _formatSize(size),
                                  _formatSize(size),
                                );
                              },
                            ),
                          const SizedBox(height: 24),
                          // 受限访问配置项 (Trust Level)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isUntrusted
                                  ? theme.colorScheme.errorContainer.withValues(
                                      alpha: 0.1,
                                    )
                                  : theme.colorScheme.primaryContainer
                                        .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isUntrusted
                                    ? theme.colorScheme.error.withValues(
                                        alpha: 0.3,
                                      )
                                    : theme.colorScheme.primary.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isUntrusted
                                          ? Icons.shield
                                          : Icons.verified_user,
                                      color: isUntrusted
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isUntrusted
                                                ? (isEn
                                                      ? 'Restricted Access'
                                                      : '开启受限访问')
                                                : (isEn
                                                      ? 'Full Trust'
                                                      : '完全信任模式'),
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: isUntrusted
                                                      ? theme.colorScheme.error
                                                      : theme
                                                            .colorScheme
                                                            .primary,
                                                ),
                                          ),
                                          Text(
                                            isUntrusted
                                                ? (isEn
                                                      ? 'Strictly intercept sensitive operations'
                                                      : '严格拦截敏感操作，保护隐私')
                                                : (isEn
                                                      ? 'Extension has direct access to APIs'
                                                      : '允许扩展直接访问 API，无拦截'),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: isUntrusted,
                                      onChanged: (val) {
                                        setState(() {
                                          isUntrusted = val;
                                        });
                                      },
                                      activeThumbColor: theme.colorScheme.error,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Text(
                                isEn ? 'Required Permissions' : '所需权限',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              if (isUpdate &&
                                  addedPerms.isEmpty &&
                                  removedPerms.isEmpty)
                                Text(
                                  isEn ? 'No changes' : '无变化',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (newPerms.isEmpty)
                            Text(
                              isEn ? 'No permissions required' : '无需特殊权限',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (!isUpdate)
                                  ...newPerms.map(
                                    (p) => _buildPermTag(
                                      p.getLabel(context),
                                      theme.colorScheme.primary,
                                    ),
                                  )
                                else ...[
                                  ...addedPerms.map(
                                    (p) => _buildPermTag(
                                      '${p.getLabel(context)} (+)',
                                      Colors.green,
                                    ),
                                  ),
                                  ...removedPerms.map(
                                    (p) => _buildPermTag(
                                      '${p.getLabel(context)} (-)',
                                      Colors.red,
                                    ),
                                  ),
                                  ...newPerms
                                      .intersection(oldPerms)
                                      .map(
                                        (p) => _buildPermTag(
                                          p.getLabel(context),
                                          theme.colorScheme.outline,
                                        ),
                                      ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(isEn ? 'Cancel' : '取消'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, {
                        'confirmed': true,
                        'isUntrusted': isUntrusted,
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        isUpdate
                            ? (isEn ? 'Update Now' : '立即更新')
                            : (isEn ? 'Install Now' : '立即安装'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            child: Row(
              children: [
                Text(oldVal, style: theme.textTheme.bodySmall),
                const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
                Text(
                  newVal,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isHighlight ? FontWeight.bold : null,
                    color: isHighlight ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermTag(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 导出扩展
  Future<void> exportExtension(String extensionId) async {
    final ext = _installedExtensions[extensionId];
    if (ext == null) return;

    final metadataJson = jsonEncode(ext.metadata.toJson());
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${ext.metadata.id}.json');
    await file.writeAsString(metadataJson);

    await Share.shareXFiles([
      XFile(file.path),
    ], subject: '导出扩展: ${ext.metadata.name}');
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
    }
  }

  /// 供 UI 调用：刷新扩展列表（根据运行状态加载/卸载实例）
  void refresh() {
    final auth = _ref.read(extensionAuthStateProvider.notifier);
    bool changed = false;

    for (var entry in _installedExtensions.entries) {
      final id = entry.key;
      final isRunning = auth.isRunning(id);
      final isLoaded = _activeExtensions.containsKey(id);

      if (isRunning && !isLoaded) {
        // 需要启动
        _loadExtension(ProxyExtension(entry.value.metadata, manager: this));
        changed = true;
      } else if (!isRunning && isLoaded) {
        // 需要停止
        _unloadExtension(id);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
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
    try {
      final boxName = 'ext_$extensionId';
      // Hive 的文件通常存储在 getApplicationDocumentsDirectory 下
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$boxName.hive');
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      debugPrint('Error getting DB size: $e');
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
    final box = await Hive.openBox(_extStoreBox);
    await box.delete(extensionId);

    notifyListeners();
  }
}
