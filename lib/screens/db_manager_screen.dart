import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../providers/db_provider.dart';
import '../providers/ui_state_provider.dart';
import '../services/file_service.dart';

class DatabaseManagerScreen extends ConsumerStatefulWidget {
  final bool isSidePanel;
  const DatabaseManagerScreen({super.key, this.isSidePanel = false});

  @override
  ConsumerState<DatabaseManagerScreen> createState() =>
      _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends ConsumerState<DatabaseManagerScreen> {
  final _nameController = TextEditingController();
  final Map<String, (int, int)> _dbStats = {};

  @override
  void initState() {
    super.initState();
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    final state = ref.read(dbControllerProvider).value;
    if (state == null) return;

    for (final dbName in state.availableDbs) {
      final stats = await _getDbStats(dbName);
      if (mounted) {
        setState(() {
          _dbStats[dbName] = stats;
        });
      }
    }
  }

  Future<(int, int)> _getDbStats(String prefix) async {
    final eventBox = await Hive.openBox<Event>('${prefix}_events');
    final templateBox = await Hive.openBox<StepTemplate>('${prefix}_templates');
    final stats = (eventBox.length, templateBox.length);
    // Don't close them if they are the active ones, but for stats it's okay to just get length
    return stats;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _exportData() async {
    try {
      await ref.read(dbProvider.future);
      final eventBox = Hive.box<Event>('events');
      final templateBox = Hive.box<StepTemplate>('templates');
      final setTemplateBox = Hive.box<StepSetTemplate>('set_templates');

      final data = {
        'events': eventBox.values
            .map(
              (e) => {
                'id': e.id,
                'title': e.title,
                'description': e.description,
                'createdAt': e.createdAt.toIso8601String(),
                'imageUrl': e.imageUrl,
                'tags': e.tags,
                'steps': e.steps
                    .map(
                      (s) => {
                        'description': s.description,
                        'timestamp': s.timestamp.toIso8601String(),
                        'completed': s.completed,
                      },
                    )
                    .toList(),
              },
            )
            .toList(),
        'templates': templateBox.values
            .map((t) => {'id': t.id, 'description': t.description})
            .toList(),
        'set_templates': setTemplateBox.values
            .map(
              (t) => {
                'id': t.id,
                'name': t.name,
                'steps': t.steps
                    .map((s) => {'description': s.description})
                    .toList(),
              },
            )
            .toList(),
        'version': 1,
      };

      final jsonString = jsonEncode(data);
      await FileService.exportData(jsonString, 'essenmelia_backup.json');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final jsonString = await FileService.readData(result.files.single);
        if (jsonString.isEmpty) return;

        final data = jsonDecode(jsonString);

        if (data is Map<String, dynamic>) {
          await ref.read(dbProvider.future);
          final eventBox = Hive.box<Event>('events');
          final templateBox = Hive.box<StepTemplate>('templates');
          final setTemplateBox = Hive.box<StepSetTemplate>('set_templates');

          // Import Events
          if (data['events'] is List) {
            for (var e in data['events']) {
              final event = Event()
                ..id = e['id'] ?? const Uuid().v4()
                ..title = e['title']
                ..description = e['description']
                ..createdAt =
                    DateTime.tryParse(e['createdAt'] ?? '') ?? DateTime.now()
                ..imageUrl = e['imageUrl']
                ..tags = (e['tags'] as List?)?.cast<String>()
                ..steps =
                    (e['steps'] as List?)
                        ?.map(
                          (s) => EventStep()
                            ..description = s['description']
                            ..timestamp =
                                DateTime.tryParse(s['timestamp'] ?? '') ??
                                DateTime.now()
                            ..completed = s['completed'] ?? false,
                        )
                        .toList() ??
                    [];
              await eventBox.put(event.id, event);
            }
          }

          // Import Templates
          if (data['templates'] is List) {
            for (var t in data['templates']) {
              final template = StepTemplate()
                ..id = t['id'] ?? const Uuid().v4()
                ..description = t['description'];
              await templateBox.put(template.id, template);
            }
          }

          // Import Sets
          if (data['set_templates'] is List) {
            for (var t in data['set_templates']) {
              final template = StepSetTemplate()
                ..id = t['id'] ?? const Uuid().v4()
                ..name = t['name']
                ..steps =
                    (t['steps'] as List?)
                        ?.map(
                          (s) =>
                              StepSetTemplateStep()
                                ..description = s['description'],
                        )
                        .toList() ??
                    [];
              await setTemplateBox.put(template.id, template);
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.importSuccess),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.importFailedDetailed(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAllDataTitle),
        content: Text(AppLocalizations.of(context)!.deleteAllDataMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(dbProvider.future);
      await Hive.box<Event>('events').clear();
      await Hive.box<StepTemplate>('templates').clear();
      await Hive.box<StepSetTemplate>('set_templates').clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.deleteAllDataSuccess),
          ),
        );
      }
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.createNewDatabase),
        content: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.enterDatabaseName,
            hintText: AppLocalizations.of(context)!.dbNameHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                // Basic validation: alphanumeric and hyphens only
                if (!RegExp(r'^[a-zA-Z0-9-_]+$').hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context)!.invalidDbName,
                      ),
                    ),
                  );
                  return;
                }

                ref.read(dbControllerProvider.notifier).createDb(name);
                _nameController.clear();
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.create),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbStateAsync = ref.watch(dbControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final body = dbStateAsync.when(
      data: (state) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            _buildSectionHeader(theme, l10n.availableDatabases),
            const SizedBox(height: 16),
            ...state.availableDbs.map((dbName) {
              final isActive = dbName == state.activeDbPrefix;
              return _buildDatabaseCard(context, dbName, isActive);
            }),
            const SizedBox(height: 12),
            Center(
              child: FilledButton.tonalIcon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: Text(l10n.createNewDatabase),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(theme, l10n.dataMaintenance),
            const SizedBox(height: 16),
            _buildMaintenanceCard(context, theme, l10n),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );

    if (widget.isSidePanel) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () =>
                      ref.read(leftPanelContentProvider.notifier).state =
                          LeftPanelContent.none,
                ),
                Text(
                  l10n.databaseManager,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.databaseManager), centerTitle: true),
      body: body,
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDatabaseCard(
    BuildContext context,
    String dbName,
    bool isActive,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isActive
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          onTap: () {
            if (!isActive) {
              ref.read(dbControllerProvider.notifier).switchDb(dbName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(l10n.switchedToDb(dbName)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          },
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isActive ? Icons.storage_rounded : Icons.storage_outlined,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          title: Text(
            dbName == kDefaultDbName ? l10n.defaultDbName : dbName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isActive ? l10n.currentlyActive : l10n.inactive,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_dbStats.containsKey(dbName)) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildStatChip(
                      theme,
                      Icons.event_note_rounded,
                      '${_dbStats[dbName]!.$1}',
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      theme,
                      Icons.copy_all_rounded,
                      '${_dbStats[dbName]!.$2}',
                    ),
                  ],
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dbName != kDefaultDbName) ...[
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: () => _handleDeleteDb(context, dbName),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeleteDb(BuildContext context, String dbName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.deleteDbTitle(dbName)),
        content: Text(l10n.deleteDbWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(dbControllerProvider.notifier).deleteDb(dbName);
    }
  }

  Widget _buildStatChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _buildMaintenanceTile(
            context,
            icon: Icons.file_download_outlined,
            title: l10n.exportData,
            onTap: _exportData,
          ),
          const Divider(height: 1, indent: 64),
          _buildMaintenanceTile(
            context,
            icon: Icons.file_upload_outlined,
            title: l10n.importData,
            onTap: _importData,
          ),
          const Divider(height: 1, indent: 64),
          _buildMaintenanceTile(
            context,
            icon: Icons.delete_forever_rounded,
            title: l10n.deleteAllDataTitle,
            onTap: _deleteAllData,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: isDestructive
            ? theme.colorScheme.error
            : theme.colorScheme.primary,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isDestructive
              ? theme.colorScheme.error
              : theme.colorScheme.onSurface,
          fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
}
