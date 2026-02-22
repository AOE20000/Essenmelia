import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/app_localizations.dart';
import '../js/extension_js_engine.dart';

/// Extension Console - for debugging JS logs and viewing state tree
class ExtensionConsole extends StatelessWidget {
  final ExtensionJsEngine engine;

  const ExtensionConsole({super.key, required this.engine});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(
            l10n.extensionConsole,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: theme.colorScheme.surface,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: [
                  Tab(
                    child: Row(
                      children: [
                        const Icon(Icons.terminal_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.logs),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      children: [
                        const Icon(Icons.account_tree_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(l10n.stateTree),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => engine.init(),
              tooltip: l10n.restartEngine,
            ),
            const SizedBox(width: 8),
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.terminal_rounded, 
                  size: 48, 
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noLogs,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[logs.length - 1 - index]; // Newest first
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onLongPress: () async {
                    await Clipboard.setData(ClipboardData(text: log));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.copiedToClipboard)),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      log,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStateView(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    // Simple view of state map
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.data_object_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              l10n.currentStateVariables,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...engine.state.entries.map((e) {
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  _showEditStateDialog(context, l10n, engine, e.key, e.value),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        e.value.toString(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
