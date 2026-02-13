import 'package:flutter/material.dart';
import 'package:essenmelia_flutter/extensions/base_extension.dart';
import 'package:intl/intl.dart';

/// 外部调用记录项
class CallLogEntry {
  final String method;
  final Map<String, dynamic> params;
  final DateTime timestamp;
  final bool success;
  final String? error;

  CallLogEntry({
    required this.method,
    required this.params,
    required this.timestamp,
    this.success = true,
    this.error,
  });
}

/// 外部调用入口扩展模板 (External Call Extension Template)
/// 
/// 职责：展示如何作为外部调用的统一入口，并实现审计日志与 MD3 详情面板。
class ExternalCallTemplate extends BaseExtension {
  ExternalCallTemplate(super.metadata);

  late ExtensionApi _api;
  final List<CallLogEntry> _logs = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  @override
  Future<void> onInit(ExtensionApi api) async {
    _api = api;
    debugPrint('Extension initialized');
  }

  void _addLog(CallLogEntry entry) {
    _logs.insert(0, entry);
    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 500),
    );
    for (final listener in _listeners) {
      listener();
    }
  }

  /// 核心方法：模拟处理外部请求
  Future<dynamic> handleExternalRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    dynamic result;
    bool success = true;
    String? error;

    try {
      // 在这里根据 method 转发给 ExtensionApi
      switch (method) {
        case 'getEvents':
          result = await _api.getEvents();
          break;
        case 'showSnackBar':
          _api.showSnackBar(params['message'] ?? 'Hello');
          result = true;
          break;
        default:
          success = false;
          error = 'Method not found';
      }
    } catch (e) {
      success = false;
      error = e.toString();
    } finally {
      _addLog(
        CallLogEntry(
          method: method,
          params: params,
          timestamp: DateTime.now(),
          success: success,
          error: error,
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context, ExtensionApi api) {
    return _ExternalCallPage(extension: this);
  }

  /// 构建日志条目 UI
  Widget _buildLogItem(
    BuildContext context,
    CallLogEntry log,
    Animation<double> animation,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);

    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            color: colorScheme.surfaceContainerLow,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showLogDetails(context, log),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: log.success
                            ? colorScheme.primaryContainer
                            : colorScheme.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        log.success ? Icons.api : Icons.error_outline,
                        size: 20,
                        color: log.success
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.method,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.params.isEmpty ? '无参数' : log.params.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 显示详情面板 (Material 3 BottomSheet)
  void _showLogDetails(BuildContext context, CallLogEntry log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fullTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(log.timestamp);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    log.success ? Icons.check_circle_outline : Icons.error_outline,
                    color: log.success ? colorScheme.primary : colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '调用详情',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow(context, '方法', log.method),
                    _buildDetailRow(context, '时间', fullTimeStr),
                    _buildDetailRow(context, '状态', log.success ? '成功' : '失败'),
                    if (log.error != null)
                      _buildDetailRow(context, '错误信息', log.error!, isError: true),
                    const SizedBox(height: 16),
                    Text(
                      '参数详情',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        log.params.toString(),
                        style: const TextStyle(fontFamily: 'monospace'),
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

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isError ? theme.colorScheme.error : null,
              fontWeight: isError ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalCallPage extends StatefulWidget {
  final ExternalCallTemplate extension;
  const _ExternalCallPage({required this.extension});

  @override
  State<_ExternalCallPage> createState() => _ExternalCallPageState();
}

class _ExternalCallPageState extends State<_ExternalCallPage> {
  @override
  void initState() {
    super.initState();
    widget.extension.addListener(_handleUpdate);
  }

  @override
  void dispose() {
    widget.extension.removeListener(_handleUpdate);
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final logs = widget.extension._logs;
    final listKey = widget.extension._listKey;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('调用记录'),
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  setState(() {
                    while (logs.isNotEmpty) {
                      logs.removeAt(0);
                      listKey.currentState?.removeItem(
                        0,
                        (context, animation) => const SizedBox(),
                      );
                    }
                  });
                },
              ),
            ],
          ),
          if (logs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 64,
                      color: colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '暂无外部调用记录',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverAnimatedList(
                key: listKey,
                initialItemCount: logs.length,
                itemBuilder: (context, index, animation) {
                  final log = logs[index];
                  return widget.extension._buildLogItem(context, log, animation);
                },
              ),
            ),
        ],
      ),
    );
  }
}
