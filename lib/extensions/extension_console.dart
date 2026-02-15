import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'logic_engine.dart';

/// Extension Console - for debugging JS logs and viewing state tree
class ExtensionConsole extends StatelessWidget {
  final ExtensionJsEngine engine;

  const ExtensionConsole({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.extensionConsole),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.terminal), text: l10n.logs),
              Tab(icon: const Icon(Icons.account_tree), text: l10n.stateTree),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => engine.init(),
              tooltip: l10n.restartEngine,
            ),
          ],
        ),
        body: TabBarView(
          children: [_buildLogView(l10n), _buildStateView(context, l10n)],
        ),
      ),
    );
  }

  Widget _buildLogView(AppLocalizations l10n) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: engine.logsNotifier,
      builder: (context, logs, _) {
        if (logs.isEmpty) {
          return Center(child: Text(l10n.noLogs));
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
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStateView(BuildContext context, AppLocalizations l10n) {
    // 这里简单展示整个 state Map
    // 如果需要更高级的树状视图，可以引入 flutter_json_view 等库
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.currentStateVariables,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...engine.state.entries.map((e) {
          return ListTile(
            title: Text(e.key),
            subtitle: Text(e.value.toString()),
            dense: true,
            trailing: const Icon(Icons.edit, size: 16),
            onTap: () =>
                _showEditStateDialog(context, l10n, engine, e.key, e.value),
          );
        }),
      ],
    );
  }

  void _showEditStateDialog(
    BuildContext context,
    AppLocalizations l10n,
    ExtensionJsEngine engine,
    String key,
    dynamic currentValue,
  ) {
    final controller = TextEditingController(text: jsonEncode(currentValue));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editState(key)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: l10n.jsonFormatValue,
            hintText: l10n.jsonHint,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              try {
                final newValue = jsonDecode(controller.text);
                engine.updateState(key, newValue);
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.invalidJson(e.toString()))),
                );
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
