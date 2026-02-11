import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../base_extension.dart';
import '../../models/event.dart';

class StatsExtension extends BaseExtension {
  _StatsPageState? _state;

  StatsExtension(super.metadata);

  @override
  void onPermissionGranted(ExtensionPermission permission) {
    if (permission == ExtensionPermission.readEvents) {
      _state?._loadData();
    }
  }

  @override
  void onEventAdded(Event event) {
    _state?._loadData();
  }

  @override
  Widget build(BuildContext context, ExtensionApi api) {
    return _StatsPage(
      api: api,
      onStateInit: (state) => _state = state,
      onStateDispose: () => _state = null,
    );
  }
}

class _StatsPage extends StatefulWidget {
  final ExtensionApi api;
  final Function(_StatsPageState) onStateInit;
  final VoidCallback onStateDispose;

  const _StatsPage({
    required this.api,
    required this.onStateInit,
    required this.onStateDispose,
  });

  @override
  State<_StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<_StatsPage> {
  int _totalEvents = 0;
  int _totalSteps = 0;
  int _completedSteps = 0;
  Map<String, int> _tagDistribution = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.onStateInit(this);
    _loadData();
  }

  @override
  void dispose() {
    widget.onStateDispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final events = await widget.api.getEvents();

      int tEvents = events.length;
      int tSteps = 0;
      int cSteps = 0;
      Map<String, int> tagDist = {};

      for (var event in events) {
        tSteps += event.steps.length;
        cSteps += event.steps.where((s) => s.completed).length;

        if (event.tags != null) {
          for (var tag in event.tags!) {
            tagDist[tag] = (tagDist[tag] ?? 0) + 1;
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalEvents = tEvents;
          _totalSteps = tSteps;
          _completedSteps = cSteps;
          _tagDistribution = tagDist;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // 这里可以调用 api.showSnackBar，如果已实现
      }
    }
  }

  Future<void> _exportData() async {
    final buffer = StringBuffer();
    buffer.writeln('指标,数值');
    buffer.writeln('总任务数,$_totalEvents');
    buffer.writeln('总步骤数,$_totalSteps');
    buffer.writeln('已完成步骤数,$_completedSteps');
    buffer.writeln(
      '完成率,${(_totalSteps == 0 ? 0 : _completedSteps / _totalSteps * 100).toInt()}%',
    );
    buffer.writeln('\n标签分布,计数');
    _tagDistribution.forEach((tag, count) {
      buffer.writeln('$tag,$count');
    });

    final success = await widget.api.exportFile(
      buffer.toString(),
      'stats_export.csv',
    );
    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('数据导出成功')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final completionRate = _totalSteps == 0
        ? 0.0
        : _completedSteps / _totalSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据洞察'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportData,
            tooltip: '导出 CSV',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 概览卡片
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: '总任务',
                    value: '$_totalEvents',
                    icon: Icons.event_note,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatCard(
                    title: '完成率',
                    value: '${(completionRate * 100).toInt()}%',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text('标签分布', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),

            // 饼图
            if (_tagDistribution.isEmpty)
              Container(
                height: 200,
                alignment: Alignment.center,
                child: Text(
                  '暂无标签数据',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              SizedBox(
                height: 250,
                child: PieChart(
                  PieChartData(
                    sections: _generatePieSections(theme),
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
              ),

            const SizedBox(height: 16),
            _buildLegend(theme),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _generatePieSections(ThemeData theme) {
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    int index = 0;
    return _tagDistribution.entries.map((entry) {
      final color = colors[index % colors.length];
      index++;
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(ThemeData theme) {
    final List<Color> colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];

    int index = 0;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: _tagDistribution.entries.map((entry) {
        final color = colors[index % colors.length];
        index++;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(entry.key, style: theme.textTheme.bodySmall),
          ],
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
