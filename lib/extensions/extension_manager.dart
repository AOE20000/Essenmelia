import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dynamic_engine.dart';

import 'base_extension.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../providers/tags_provider.dart';
import 'utils/mock_data_generator.dart';
import 'widgets/permission_management_dialog.dart';

/// 扩展授权状态 Provider (Map<extensionId, List<permissionName>>)
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
    // 默认所有已安装扩展都是运行状态，除非明确停止
    state = loaded;
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
      // 通知已加载的实例
      final manager = _ref.read(extensionManagerProvider);
      manager.notifyPermissionGranted(extensionId, permission);
      // 关键：权限授予后立即刷新 Manager，确保实例被正确加载/重载
      manager.refresh();
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
    }

    // 通知 Manager 刷新实例状态
    _ref.read(extensionManagerProvider).refresh();
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

    // 4. 清除扩展私有设置
    await Hive.deleteBoxFromDisk('ext_$extensionId');

    // 5. 清除本次运行的临时授权
    _ref.read(sessionPermissionsProvider.notifier).update((sessionState) {
      final newState = Map<String, Set<String>>.from(sessionState);
      newState.remove(extensionId);
      return newState;
    });

    // 6. 从 Manager 中完全移除
    _ref.read(extensionManagerProvider).removeExtension(extensionId);

    // 7. 更新状态触发 UI 刷新
    state = {...state}
      ..remove(extensionId)
      ..remove('$_untrustedPrefix$extensionId')
      ..remove('$_runningPrefix$extensionId');
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

/// 记录本次会话中已允许的权限 (Map<extensionId, Set<String>>)
/// String 可以是 "all" 或具体的 Category 名
final sessionPermissionsProvider = StateProvider<Map<String, Set<String>>>(
  (ref) => {},
);

/// 对话框显示锁，防止并发 API 调用导致多个弹窗冲突
bool _isDialogShowing = false;

/// 受控 API 的具体实现
class ExtensionApiImpl implements ExtensionApi {
  final Ref _ref;
  final ExtensionMetadata _metadata;
  final ExtensionManager _manager;

  ExtensionApiImpl(this._ref, this._metadata, this._manager);

  bool _checkPermission(ExtensionPermission permission) {
    return _ref
        .read(extensionAuthStateProvider.notifier)
        .hasPermission(_metadata.id, permission);
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

    // 如果未开启不信任模式，直接通过
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
    final context = navigatorKey.currentContext;
    if (context == null) return;

    Future.microtask(() async {
      // 等待上一个对话框关闭
      while (_isDialogShowing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _isDialogShowing = true;
      final decision = await showDialog<PermissionManagementDecision>(
        context: context,
        barrierDismissible: false,
        builder: (context) => PermissionManagementDialog(
          extensionName: _metadata.name,
          operationDescription: operation,
          categoryName: category,
          isPostHoc: true, // 启用事后授权文案
        ),
      );
      _isDialogShowing = false;

      final authNotifier = _ref.read(extensionAuthStateProvider.notifier);

      if (decision != null && decision != PermissionManagementDecision.deny) {
        if (decision == PermissionManagementDecision.allowNextRun) {
          // 下次运行允许（持久化，但仅下次生效）
          await authNotifier.setNextRunPermission(_metadata.id, category);
        } else {
          // 更新会话权限
          _ref.read(sessionPermissionsProvider.notifier).update((state) {
            final newState = Map<String, Set<String>>.from(state);
            final extPerms = Set<String>.from(newState[_metadata.id] ?? {});
            if (decision == PermissionManagementDecision.allowCategoryOnce) {
              extPerms.add(category);
            } else if (decision == PermissionManagementDecision.allowAllOnce) {
              extPerms.add('all');
            }
            // allowOnce 不记录在 session 中
            newState[_metadata.id] = extPerms;
            return newState;
          });

          // 如果是数据读取类操作，通知扩展权限已授予，可以尝试重新获取真数据
          if (category == '数据读取') {
            _manager.notifyPermissionGranted(
              _metadata.id,
              ExtensionPermission.readEvents,
            );
          }
        }
      }

      // 无论是否允许，都恢复扩展运行并清空缓冲区
      _manager.resumeExtension(_metadata.id);
    });
  }

  @override
  Future<List<Event>> getEvents() async {
    // 强制检查运行状态
    if (!_ref
        .read(extensionAuthStateProvider.notifier)
        .isRunning(_metadata.id)) {
      return MockDataGenerator.generateEvents(count: 3);
    }

    if (!await _shieldIntercept('读取您的所有任务列表和步骤', '数据读取')) {
      return MockDataGenerator.generateEvents(count: 5); // 拒绝后返回少量假数据
    }

    final eventsAsync = _ref.read(eventsProvider);
    final realEvents = eventsAsync.when(
      data: (events) => events,
      loading: () => <Event>[],
      error: (_, __) => <Event>[],
    );

    if (!_checkPermission(ExtensionPermission.readEvents)) {
      // 没权限时也增加一点点随机延迟，模拟正常查询耗时
      await Future.delayed(const Duration(milliseconds: 50));
      return MockDataGenerator.generateEvents(
        count: 12,
        realData: realEvents,
        mixReal: true,
      );
    }
    return realEvents;
  }

  @override
  Future<List<String>> getTags() async {
    if (!await _shieldIntercept('查看您创建的所有标签', '数据读取')) {
      return ['示例标签'];
    }

    final tagsAsync = _ref.read(tagsProvider);
    final realTags = tagsAsync.when(
      data: (tags) => tags,
      loading: () => <String>[],
      error: (_, __) => <String>[],
    );

    if (!_checkPermission(ExtensionPermission.readTags)) {
      final mockTags = ['工作', '生活', '学习', '健康', '重要'];
      if (realTags.isNotEmpty) {
        mockTags.add(realTags.first);
      }
      return mockTags..shuffle();
    }
    return realTags;
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
    if (!_ref.read(extensionAuthStateProvider.notifier).isRunning(_metadata.id))
      return;

    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Future<bool> exportFile(String content, String fileName) async {
    if (!await _shieldIntercept('导出文件并调起系统分享: $fileName', '文件操作')) {
      return false;
    }

    if (!_checkPermission(ExtensionPermission.fileSystem)) {
      return false;
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
  Future<T?> getSetting<T>(String key) async {
    // 读取扩展自身设置通常不需要拦截
    final box = await Hive.openBox('ext_${_metadata.id}');
    return box.get(key) as T?;
  }

  @override
  Future<void> saveSetting<T>(String key, T value) async {
    // 保存扩展自身设置通常不需要拦截
    final box = await Hive.openBox('ext_${_metadata.id}');
    await box.put(key, value);
  }
}

/// 动态加载的扩展占位符
class ProxyExtension extends BaseExtension {
  ProxyExtension(super.metadata);

  @override
  Widget build(BuildContext context, ExtensionApi api) {
    // 如果定义了动态界面或逻辑，使用动态引擎
    if (metadata.view != null || metadata.logic != null) {
      return DynamicEngine(metadata: metadata, api: api);
    }

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        Future.delayed(const Duration(milliseconds: 100)),
        ProviderScope.containerOf(
          context,
        ).read(extensionManagerProvider).getExtensionDbSize(metadata.id),
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
                  color: theme.colorScheme.primary.withOpacity(0.5),
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
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
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

  ExtensionManager(this._ref) {
    _init();
  }

  Future<void> _init() async {
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
          _installedExtensions[metadata.id] = ProxyExtension(metadata);
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
  Future<BaseExtension?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'zip'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      return await _processImportedContent(content);
    }
    return null;
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

      final confirmed = await _showInstallationConfirmDialog(
        context,
        metadata,
        content,
        oldExtension?.metadata,
        oldContent,
      );

      if (confirmed != true) return null;

      final box = await Hive.openBox(_extStoreBox);
      await box.put(metadata.id, content);

      // 注册为占位符
      final newExt = ProxyExtension(metadata);
      _installedExtensions[metadata.id] = newExt;

      // 确保新导入的扩展默认是运行状态
      final auth = _ref.read(extensionAuthStateProvider.notifier);
      await auth.setRunning(metadata.id, true);

      // 默认设为信任模式（不开启拦截，用户可手动在详情页开启“权限管理/隐身盾”）
      if (oldExtension == null) {
        await auth.setUntrusted(metadata.id, false);
      }

      // 刷新管理器状态（会触发 _loadExtension）
      refresh();

      // 返回激活后的实例（如果有逻辑提供者，则是真实实例；否则是 Proxy）
      return _activeExtensions[metadata.id] ?? newExt;
    } catch (e) {
      debugPrint('Invalid extension format: $e');
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
                const SizedBox(width: 8),
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
                    borderRadius: BorderRadius.circular(4),
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

  Future<bool?> _showInstallationConfirmDialog(
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

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isUpdate
              ? (isEn ? 'Update Extension' : '更新扩展')
              : (isEn ? 'Install Extension' : '安装扩展'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(newMeta.icon, size: 40),
                title: Text(newMeta.name),
                subtitle: Text(newMeta.id),
                contentPadding: EdgeInsets.zero,
              ),
              const Divider(),
              _buildDiffRow(
                context,
                isEn ? 'Version' : '版本',
                oldMeta?.version ?? (isEn ? 'Not installed' : '未安装'),
                newMeta.version,
                isHighlight: oldMeta?.version != newMeta.version,
              ),
              _buildDiffRow(
                context,
                isEn ? 'Words' : '字数',
                isEn
                    ? '${oldContent?.length ?? 0} words'
                    : '${oldContent?.length ?? 0} 字',
                isEn ? '${newContent.length} words' : '${newContent.length} 字',
                isHighlight: oldContent?.length != newContent.length,
              ),
              if (isUpdate)
                FutureBuilder<int>(
                  future: _ref
                      .read(extensionManagerProvider)
                      .getExtensionDbSize(newMeta.id),
                  builder: (context, snapshot) {
                    final size = snapshot.data ?? 0;
                    return _buildDiffRow(
                      context,
                      isEn ? 'Database' : '数据库',
                      _formatSize(size),
                      _formatSize(size),
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text(
                isEn ? 'Permission Changes' : '权限变更',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (addedPerms.isEmpty && removedPerms.isEmpty && isUpdate)
                Text(
                  isEn ? 'No changes' : '权限无变化',
                  style: const TextStyle(fontSize: 13),
                )
              else if (!isUpdate)
                ...newPerms.map(
                  (p) => _buildPermTag(p.getLabel(context), Colors.green),
                )
              else ...[
                ...addedPerms.map(
                  (p) =>
                      _buildPermTag('${p.getLabel(context)} (+)', Colors.green),
                ),
                ...removedPerms.map(
                  (p) =>
                      _buildPermTag('${p.getLabel(context)} (-)', Colors.red),
                ),
                ...newPerms
                    .intersection(oldPerms)
                    .map(
                      (p) => _buildPermTag(p.getLabel(context), Colors.grey),
                    ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isEn ? 'Cancel' : '取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isUpdate
                  ? (isEn ? 'Update Now' : '立即更新')
                  : (isEn ? 'Install Now' : '立即安装'),
            ),
          ),
        ],
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
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
        _loadExtension(ProxyExtension(entry.value.metadata));
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
    _ref.read(extensionAuthStateProvider.notifier).triggerNotify();
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
    _unloadExtension(extensionId);
    _installedExtensions.remove(extensionId);

    final box = await Hive.openBox(_extStoreBox);
    await box.delete(extensionId);

    notifyListeners();
  }
}
