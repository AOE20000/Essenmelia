import 'dart:convert';
import 'package:flutter/material.dart';
import 'logic_engine.dart';

/// 扩展控制台 - 用于调试 JS 日志和查看状态树
class ExtensionConsole extends StatelessWidget {
  final ExtensionJsEngine engine;

  const ExtensionConsole({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('扩展控制台'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.terminal), text: '日志'),
              Tab(icon: Icon(Icons.account_tree), text: '状态树'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => engine.init(),
              tooltip: '重启引擎',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildLogView(),
            _buildStateView(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLogView() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: engine.logsNotifier,
      builder: (context, logs, _) {
        if (logs.isEmpty) {
          return const Center(child: Text('暂无日志'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[logs.length - 1 - index]; // 最新日志在前
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                log,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStateView(BuildContext context) {
    // 这里简单展示整个 state Map
    // 如果需要更高级的树状视图，可以引入 flutter_json_view 等库
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '当前状态变量 (State):',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...engine.state.entries.map((e) {
          return ListTile(
            title: Text(e.key),
            subtitle: Text(e.value.toString()),
            dense: true,
            trailing: const Icon(Icons.edit, size: 16),
            onTap: () => _showEditStateDialog(context, engine, e.key, e.value),
          );
        }),
      ],
    );
  }

  void _showEditStateDialog(BuildContext context, ExtensionJsEngine engine,
      String key, dynamic currentValue) {
    final controller =
        TextEditingController(text: jsonEncode(currentValue));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑状态: $key'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'JSON 格式值',
            hintText: '例如: "text" 或 123 或 {"a": 1}',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final newValue = jsonDecode(controller.text);
                engine.updateState(key, newValue);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('无效的 JSON: $e')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
