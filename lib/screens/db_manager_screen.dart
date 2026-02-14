import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
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
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseManagerScreen extends ConsumerStatefulWidget {
  final bool isSidePanel;
  const DatabaseManagerScreen({super.key, this.isSidePanel = false});

  @override
  ConsumerState<DatabaseManagerScreen> createState() =>
      _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends ConsumerState<DatabaseManagerScreen> {
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
    super.dispose();
  }

  Future<void> _exportData() async {
    try {
      await ref.read(dbProvider.future);
      final prefix = ref.read(activePrefixProvider);

      final eventBox = Hive.box<Event>('${prefix}_events');
      final templateBox = Hive.box<StepTemplate>('${prefix}_templates');
      final setTemplateBox = Hive.box<StepSetTemplate>(
        '${prefix}_set_templates',
      );
      final tagBox = Hive.box<String>('${prefix}_tags');

      final data = {
        'tags': tagBox.values.toList(),
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

      // Create ZIP archive
      final archive = Archive();

      // Add JSON data
      final jsonBytes = utf8.encode(jsonString);
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

      // Add images
      for (final event in eventBox.values) {
        if (event.imageUrl != null &&
            event.imageUrl!.isNotEmpty &&
            !event.imageUrl!.startsWith('http') &&
            !event.imageUrl!.startsWith('data:')) {
          final file = File(event.imageUrl!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final fileName = p.basename(event.imageUrl!);
            archive.addFile(
              ArchiveFile('images/$fileName', bytes.length, bytes),
            );
          }
        }
      }

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      await FileService.exportZip(
        Uint8List.fromList(zipBytes),
        'essenmelia_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.exportSuccess)),
        );
      }
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
        allowedExtensions: ['json', 'zip'],
      );

      if (result != null) {
        final pickedFile = result.files.single;
        final isZip = pickedFile.extension?.toLowerCase() == 'zip';
        String jsonString = '';
        Map<String, Uint8List> imageMap = {};

        if (isZip) {
          final zipBytes = await FileService.readZip(pickedFile);
          if (zipBytes == null) return;

          final archive = ZipDecoder().decodeBytes(zipBytes);
          for (final file in archive) {
            if (file.isFile) {
              if (file.name == 'data.json') {
                jsonString = utf8.decode(file.content as List<int>);
              } else if (file.name.startsWith('images/')) {
                final imageName = p.basename(file.name);
                imageMap[imageName] = file.content;
              }
            }
          }
        } else {
          jsonString = await FileService.readData(pickedFile);
        }

        if (jsonString.isEmpty) return;

        final data = jsonDecode(jsonString);

        if (data is Map<String, dynamic>) {
          await ref.read(dbProvider.future);
          final prefix = ref.read(activePrefixProvider);

          final eventBox = Hive.box<Event>('${prefix}_events');
          final templateBox = Hive.box<StepTemplate>('${prefix}_templates');
          final setTemplateBox = Hive.box<StepSetTemplate>(
            '${prefix}_set_templates',
          );
          final tagBox = Hive.box<String>('${prefix}_tags');

          // Prepare image directory
          final appDir = await getApplicationDocumentsDirectory();
          final imagesDir = Directory(p.join(appDir.path, 'event_images'));
          if (!await imagesDir.exists()) {
            await imagesDir.create(recursive: true);
          }

          // Import Tags
          if (data['tags'] is List) {
            final tags = (data['tags'] as List).cast<String>();
            for (final tag in tags) {
              if (!tagBox.values.contains(tag)) {
                await tagBox.add(tag);
              }
            }
          }

          // Import Events
          if (data['events'] is List) {
            for (var e in data['events']) {
              String? finalImageUrl = e['imageUrl'];

              // If it's a ZIP import and has an image, restore it
              if (isZip && finalImageUrl != null && finalImageUrl.isNotEmpty) {
                final imageName = p.basename(finalImageUrl);
                if (imageMap.containsKey(imageName)) {
                  final newPath = p.join(imagesDir.path, imageName);
                  final imageFile = File(newPath);
                  await imageFile.writeAsBytes(imageMap[imageName]!);
                  finalImageUrl = newPath; // Update to local path
                }
              }

              final event = Event()
                ..id = e['id'] ?? const Uuid().v4()
                ..title = e['title']
                ..description = e['description']
                ..createdAt =
                    DateTime.tryParse(e['createdAt'] ?? '') ?? DateTime.now()
                ..imageUrl = finalImageUrl
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
            _loadAllStats();
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
    final l10n = AppLocalizations.of(context)!;
    final confirmController = TextEditingController();
    bool canDelete = false;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
          title: Text(l10n.formatApp),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.formatAppWarning),
              const SizedBox(height: 24),
              Text(
                l10n.formatAppConfirm,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.formatAppPlaceholder,
                  border: const OutlineInputBorder(),
                  errorText: confirmController.text.isNotEmpty &&
                          confirmController.text != 'DELETE'
                      ? 'Invalid input'
                      : null,
                ),
                onChanged: (val) {
                  setState(() => canDelete = val == 'DELETE');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: canDelete ? () => Navigator.pop(context, true) : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(l10n.formatApp),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      // Show loading overlay
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        await ref.read(dbControllerProvider.notifier).resetAll();
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.deleteAllDataSuccess)),
          );
          _loadAllStats();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Reset failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final name = controller.text.trim();
          final isValid = name.isNotEmpty && RegExp(r'^[a-zA-Z0-9-_]+$').hasMatch(name);

          return AlertDialog(
            icon: const Icon(Icons.add_to_photos_rounded),
            title: Text(l10n.createNewDatabase),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.enterDatabaseName,
                    hintText: l10n.dbNameHint,
                    prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
                    border: const OutlineInputBorder(),
                    errorText: name.isNotEmpty && !isValid ? l10n.invalidDbName : null,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (val) {
                    if (isValid) {
                      ref.read(dbControllerProvider.notifier).createDb(name);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: isValid
                    ? () {
                        ref.read(dbControllerProvider.notifier).createDb(name);
                        Navigator.pop(context);
                      }
                    : null,
                child: Text(l10n.create),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbStateAsync = ref.watch(dbControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: dbStateAsync.when(
        data: (state) {
          return ListView(
            key: const ValueKey('db_list_data'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              _buildSectionHeader(theme, l10n.availableDatabases),
              ...state.availableDbs.map((dbName) {
                final isActive = dbName == state.activeDbPrefix;
                return _buildDatabaseCard(context, dbName, isActive, state);
              }),
              const SizedBox(height: 8),
              _buildSectionHeader(theme, l10n.dataMaintenance),
              _buildMaintenanceCard(context, theme, l10n),
            ],
          );
        },
        loading: () => const Center(
          key: ValueKey('db_list_loading'),
          child: CircularProgressIndicator(),
        ),
        error: (err, _) => Center(
          key: ValueKey('db_list_error'),
          child: Text('Error: $err'),
        ),
      ),
    );

    if (widget.isSidePanel) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () =>
                      ref.read(leftPanelContentProvider.notifier).state =
                          LeftPanelContent.none,
                ),
                const SizedBox(width: 8),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: FloatingActionButton.extended(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: Text(l10n.createNewDatabase),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.databaseManager),
        centerTitle: true,
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: Text(l10n.createNewDatabase),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDatabaseCard(
    BuildContext context,
    String dbName,
    bool isActive,
    DbState state,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      color: isActive
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!isActive) {
            ref.read(dbControllerProvider.notifier).switchDb(dbName);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: isActive
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dbName == kDefaultDbName ? l10n.defaultDbName : dbName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (_dbStats.containsKey(dbName))
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
                ),
              ),
              if (dbName != kDefaultDbName)
                IconButton.filledTonal(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _handleDeleteDb(context, dbName),
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Database Actions
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          color: theme.colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildMaintenanceTile(
                context,
                icon: Icons.file_download_outlined,
                title: l10n.exportData,
                onTap: _exportData,
              ),
              Divider(
                height: 1,
                indent: 56,
                endIndent: 16,
                color: theme.colorScheme.outlineVariant,
              ),
              _buildMaintenanceTile(
                context,
                icon: Icons.file_upload_outlined,
                title: l10n.importData,
                onTap: _importData,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(theme, l10n.dangerZone),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.colorScheme.errorContainer),
          ),
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
          clipBehavior: Clip.antiAlias,
          child: _buildMaintenanceTile(
            context,
            icon: Icons.delete_forever_rounded,
            title: l10n.deleteAllDataTitle,
            onTap: _deleteAllData,
            isDestructive: true,
          ),
        ),
      ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        icon,
        color: isDestructive
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: isDestructive
              ? theme.colorScheme.error
              : theme.colorScheme.onSurface,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }
}
