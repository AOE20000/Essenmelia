import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:animations/animations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
        'events': eventBox.values.map((e) => e.toJson()).toList(),
        'templates': templateBox.values.map((t) => t.toJson()).toList(),
        'set_templates': setTemplateBox.values.map((t) => t.toJson()).toList(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.exportFailedDetailed(e.toString()),
            ),
          ),
        );
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

              final event = Event.fromJson(e as Map<String, dynamic>)
                ..imageUrl = finalImageUrl;
              await eventBox.put(event.id, event);
            }
          }

          // Import Templates
          if (data['templates'] is List) {
            for (var t in data['templates']) {
              final template = StepTemplate.fromJson(t as Map<String, dynamic>);
              await templateBox.put(template.id, template);
            }
          }

          // Import Sets
          if (data['set_templates'] is List) {
            for (var t in data['set_templates']) {
              final template = StepSetTemplate.fromJson(
                t as Map<String, dynamic>,
              );
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
    final theme = Theme.of(context);
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
              Text(l10n.formatAppWarning, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              Text(
                l10n.formatAppConfirm,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.formatAppPlaceholder,
                  filled: true,
                  fillColor: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.1,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.colorScheme.error),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.error,
                      width: 2,
                    ),
                  ),
                  errorText:
                      confirmController.text.isNotEmpty &&
                          confirmController.text != 'DELETE'
                      ? l10n.invalidInput
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
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.deleteAllDataSuccess)));
          _loadAllStats();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.resetFailedDetailed(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.add_to_photos_rounded),
        title: Text(l10n.createNewDatabase),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.dbNameHint,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded),
          ),
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.create),
          ),
        ],
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      await ref.read(dbControllerProvider.notifier).createDb(name.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbStateAsync = ref.watch(dbControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final body = PageTransitionSwitcher(
      duration: const Duration(milliseconds: 400),
      reverse: false,
      transitionBuilder: (child, animation, secondaryAnimation) {
        return FadeThroughTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          fillColor: theme.colorScheme.surface,
          child: child,
        );
      },
      child: dbStateAsync.when(
        data: (state) {
          return CustomScrollView(
            key: const ValueKey('db_content_scroll_view'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (!widget.isSidePanel)
                SliverAppBar.large(
                  title: Text(l10n.databaseManager),
                  centerTitle: true,
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader(theme, l10n.availableDatabases),
                    ...state.availableDbs.map((dbName) {
                      final isActive = dbName == state.activeDbPrefix;
                      return _buildDatabaseCard(
                        context,
                        dbName,
                        isActive,
                        state,
                      );
                    }),
                    const SizedBox(height: 16),
                    _buildSectionHeader(theme, l10n.dataMaintenance),
                    _buildMaintenanceCard(context, theme, l10n),
                  ]),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          key: const ValueKey('db_loading'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.loading),
            ],
          ),
        ),
        error: (err, _) => Center(
          key: const ValueKey('db_error'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.error(err.toString()),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isSidePanel) {
      return Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Text(
                      l10n.databaseManager,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        ref.read(leftPanelContentProvider.notifier).state =
                            LeftPanelContent.none;
                      },
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
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
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
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
    DbState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final stats = _dbStats[dbName] ?? (0, 0);
    final events = stats.$1;
    final templates = stats.$2;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: isActive
          ? colorScheme.primaryContainer.withValues(alpha: 0.7)
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isActive ? colorScheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        onTap: isActive
            ? null
            : () async {
                await ref.read(dbControllerProvider.notifier).switchDb(dbName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text(l10n.switchedToDb(dbName)),
                    ),
                  );
                }
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isActive ? Icons.dns_rounded : Icons.storage_rounded,
                  color: isActive
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dbName == kDefaultDbName ? l10n.defaultDbName : dbName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isActive ? colorScheme.onPrimaryContainer : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.dbStats(events, templates),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.7,
                              )
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.currentlyActive,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (dbName != kDefaultDbName)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: colorScheme.error,
                  ),
                  onPressed: () => _showDeleteConfirm(context, dbName),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String dbName) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.delete_sweep_rounded, color: colorScheme.error),
        title: Text(l10n.deleteDbTitle(dbName)),
        content: Text(l10n.deleteDbWarning, style: theme.textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref.read(dbControllerProvider.notifier).deleteDb(dbName);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(l10n.delete),
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
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildMaintenanceTile(
                context,
                icon: Icons.file_download_outlined,
                title: l10n.exportData,
                onTap: _exportData,
              ),
              Padding(
                padding: const EdgeInsets.only(left: 64, right: 16),
                child: Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
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
        Material(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
            ),
          ),
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
    final colorScheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      splashColor: isDestructive
          ? colorScheme.error.withValues(alpha: 0.1)
          : colorScheme.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDestructive
              ? colorScheme.errorContainer.withValues(alpha: 0.2)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDestructive ? colorScheme.error : colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: isDestructive ? colorScheme.error : colorScheme.onSurface,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.w500,
          fontSize: 15,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    );
  }
}
