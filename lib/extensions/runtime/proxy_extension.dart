import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/base_extension.dart';
import '../core/extension_api.dart';
import '../manager/extension_manager.dart';
import 'js/extension_js_engine.dart';
import 'view/dynamic_engine.dart';
import '../security/extension_auth_notifier.dart';

/// Dynamic extension placeholder/proxy
class ProxyExtension extends BaseExtension {
  ExtensionJsEngine? _engine;
  String? _initError;

  ProxyExtension(super.metadata);

  @override
  Future<void> onInit(ExtensionApi api) async {
    debugPrint('ProxyExtension.onInit called for ${metadata.id}');
    _engine = ExtensionJsEngine(metadata: metadata, api: api);
    try {
      await _engine!.init();
      debugPrint('ProxyExtension.onInit completed for ${metadata.id}');
    } catch (e, stack) {
      debugPrint('ProxyExtension.onInit failed for ${metadata.id}: $e\n$stack');
      _initError = e.toString();
      rethrow;
    }
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

  /// Allow external JS function calls
  Future<dynamic> callJsFunction(String name, [dynamic params]) async {
    return await _engine?.callFunction(name, params);
  }

  @override
  Widget build(BuildContext context, ExtensionApi api) {
    debugPrint(
      'Building extension UI for: ${metadata.id}, view is null: ${metadata.view == null}',
    );

    // If dynamic view is defined, use DynamicEngine
    if (metadata.view != null &&
        (metadata.view is String || metadata.view!.isNotEmpty)) {
      return Consumer(
        builder: (context, ref, child) {
          // Watch manager to rebuild when extension is loaded
          ref.watch(extensionManagerProvider);
          // Watch auth state
          ref.watch(extensionAuthStateProvider);

          // Force check if extension is active in manager
          final manager = ref.read(extensionManagerProvider);
          final activeExt = manager.getExtension(metadata.id);
          final isActive = activeExt != null;

          // If active and engine is ready, show UI
          if (isActive && _engine != null) {
            return DynamicEngine(engine: _engine!);
          }

          // If we have an active extension instance but _engine is null, it means
          // this ProxyExtension instance is stale or not the one being managed.
          // However, since ProxyExtension *is* the instance in _activeExtensions for dynamic extensions,
          // we need to ensure _engine is initialized.

          if (_initError != null) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '扩展加载失败',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(_initError!, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            );
          }

          final notifier = ref.read(extensionAuthStateProvider.notifier);
          final isRunning = notifier.isRunning(metadata.id);

          if (!isRunning) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pause_circle_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      '扩展未运行',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '请在扩展详情页启用此扩展',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          // If running but no engine, it might be initializing.
          // Check if manager has it active.
          if (!isActive) {
            // Trigger load if not active
            Future.microtask(() => manager.getExtension(metadata.id));
          }

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    // Otherwise show developer sandbox
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
                      '扩展信息',
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

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
