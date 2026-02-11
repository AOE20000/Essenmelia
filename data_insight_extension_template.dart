import 'package:flutter/material.dart';
import 'package:essenmelia_flutter/extensions/base_extension.dart';
import 'package:essenmelia_flutter/models/event.dart';

/// 数据洞察扩展模板 (Data Insight Extension Template)
///
/// 这是一个标准的 Essenmelia 扩展模板，展示了如何：
/// 1. 声明权限 (Metadata)
/// 2. 处理动态授权 (onPermissionGranted)
/// 3. 使用 API 获取主程序数据 (getEvents)
/// 4. 持久化扩展配置 (saveSetting/getSetting)
/// 5. 适配 UI 刷新 (onEventAdded)
class DataInsightExtension extends BaseExtension {
  _DataInsightPageState? _state;

  /// 构造函数接收元数据，以便与不同的 JSON 清单解耦
  DataInsightExtension(super.metadata);

  /// 当用户授权状态发生变化后（如点击允许），系统会回调此方法。
  @override
  void onPermissionGranted(ExtensionPermission permission) {
    if (permission == ExtensionPermission.readEvents) {
      _state?._refreshData();
    }
  }

  /// 当主程序中有新事件产生时，此方法会被实时触发。
  @override
  void onEventAdded(Event event) {
    _state?._refreshData();
  }

  @override
  Widget build(BuildContext context, ExtensionApi api) {
    return _DataInsightPage(
      api: api,
      // 通过回调持有 State 引用，以便在 BaseExtension 中触发 UI 刷新
      onStateInit: (state) => _state = state,
      onStateDispose: () => _state = null,
    );
  }
}

/// 扩展的主界面
class _DataInsightPage extends StatefulWidget {
  final ExtensionApi api;
  final Function(_DataInsightPageState) onStateInit;
  final VoidCallback onStateDispose;

  const _DataInsightPage({
    required this.api,
    required this.onStateInit,
    required this.onStateDispose,
  });

  @override
  State<_DataInsightPage> createState() => _DataInsightPageState();
}

class _DataInsightPageState extends State<_DataInsightPage> {
  List<Event> _events = [];
  bool _isLoading = true;
  String _lastUpdateTime = '从未更新';

  @override
  void initState() {
    super.initState();
    widget.onStateInit(this);
    _refreshData();
  }

  @override
  void dispose() {
    widget.onStateDispose();
    super.dispose();
  }

  /// 核心数据加载逻辑
  Future<void> _refreshData() async {
    // 建议在加载前重置状态，提供良好的交互反馈
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 调用 API 获取数据。如果权限尚未获取，系统将按需引导用户授权。
      // 提示：授权过程是异步的，初次获取可能受限。
      final events = await widget.api.getEvents();

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
          _lastUpdateTime = DateTime.now().toString().substring(11, 19);
        });
      }
    } catch (e) {
      widget.api.showSnackBar('加载失败: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据洞察'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: '手动刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(theme),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_graph,
              size: 64,
              color: theme.colorScheme.outline.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text('暂无数据或访问受限'),
            TextButton(onPressed: _refreshData, child: const Text('重试加载')),
          ],
        ),
      );
    }

    // 利用 Event 模型的 Getter 进行统计
    final completedCount = _events.where((e) => e.isCompleted).length;
    final avgCompletion = _events.isEmpty
        ? 0.0
        : (_events.map((e) => e.completionRate).reduce((a, b) => a + b) /
              _events.length);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          '总任务数',
          '${_events.length}',
          Icons.list_alt,
          Colors.blue,
        ),
        _buildStatCard(
          '已完成',
          '$completedCount',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          '平均进度',
          '${(avgCompletion * 100).toStringAsFixed(1)}%',
          Icons.speed,
          Colors.orange,
        ),
        const SizedBox(height: 16),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '上次更新: $_lastUpdateTime',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(label, style: theme.textTheme.titleSmall),
        trailing: Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
