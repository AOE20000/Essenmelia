import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/event.dart';
import '../providers/db_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/file_service.dart';
import '../widgets/glass_container.dart';
import 'db_manager_screen.dart';
import 'manage_tags_screen.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key});

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
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

          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Import successful')));
            context.pop();
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _deleteAllData(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(dbProvider.future);
      await Hive.box<Event>('events').clear();
      await Hive.box<StepTemplate>('templates').clear();
      await Hive.box<StepSetTemplate>('set_templates').clear();

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All data deleted')));
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final displaySettings = ref.watch(displaySettingsProvider);

    return GlassContainer(
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
              value: isDarkMode,
              onChanged: (value) {
                ref.read(themeProvider.notifier).toggleTheme();
              },
            ),
            SwitchListTile(
              title: const Text('Collapse Images'),
              secondary: const Icon(Icons.image_not_supported_outlined),
              value: displaySettings.collapseImages,
              onChanged: (value) {
                ref
                    .read(displaySettingsProvider.notifier)
                    .toggleCollapseImages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view),
              title: const Text('Items Per Row'),
              trailing: DropdownButton<int>(
                value: displaySettings.itemsPerRow,
                underline: const SizedBox(),
                items: [1, 2, 3, 4, 5]
                    .map((i) => DropdownMenuItem(value: i, child: Text('$i')))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(displaySettingsProvider.notifier)
                        .setItemsPerRow(val);
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('Database Manager'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DatabaseManagerScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Manage Tags'),
              onTap: () {
                Navigator.pop(context); // Close sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageTagsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export Data (JSON)'),
              onTap: () => _exportData(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Import Data (JSON)'),
              onTap: () => _importData(context, ref),
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Delete All Data',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: () => _deleteAllData(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
