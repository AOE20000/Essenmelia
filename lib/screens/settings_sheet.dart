import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/event.dart';
import '../providers/db_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../services/file_service.dart';
import 'db_manager_screen.dart';
import 'manage_tags_screen.dart';

import '../providers/ui_state_provider.dart';

class SettingsSheet extends ConsumerWidget {
  final bool isSidePanel;
  const SettingsSheet({super.key, this.isSidePanel = false});

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.importSuccess),
              ),
            );
            context.pop();
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
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

  Future<void> _deleteAllData(BuildContext context, WidgetRef ref) async {
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

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.deleteAllDataSuccess),
          ),
        );
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final displaySettings = ref.watch(displaySettingsProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final maxDensity = isSmallScreen ? 2 : 5;

    final body = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(AppLocalizations.of(context)!.language),
                trailing: DropdownButton<Locale?>(
                  value: ref.watch(localeProvider),
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(AppLocalizations.of(context)!.systemLanguage),
                    ),
                    const DropdownMenuItem(
                      value: Locale('en'),
                      child: Text('English'),
                    ),
                    const DropdownMenuItem(
                      value: Locale('zh'),
                      child: Text('中文'),
                    ),
                  ],
                  onChanged: (locale) {
                    ref.read(localeProvider.notifier).setLocale(locale);
                  },
                ),
              ),
              ListTile(
                leading: Icon(switch (themeMode) {
                  ThemeModeOption.system => Icons.brightness_auto,
                  ThemeModeOption.light => Icons.light_mode,
                  ThemeModeOption.dark => Icons.dark_mode,
                }),
                title: Text(AppLocalizations.of(context)!.darkMode),
                trailing: DropdownButton<ThemeModeOption>(
                  value: themeMode,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem(
                      value: ThemeModeOption.system,
                      child: Text(AppLocalizations.of(context)!.useSystemTheme),
                    ),
                    DropdownMenuItem(
                      value: ThemeModeOption.light,
                      child: Text(AppLocalizations.of(context)!.light),
                    ),
                    DropdownMenuItem(
                      value: ThemeModeOption.dark,
                      child: Text(AppLocalizations.of(context)!.dark),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(themeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
              ),
              SwitchListTile(
                title: Text(AppLocalizations.of(context)!.collapseImages),
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
                title: Text(AppLocalizations.of(context)!.cardDensity),
                trailing: DropdownButton<int>(
                  value: displaySettings.itemsPerRow.clamp(1, maxDensity),
                  underline: const SizedBox(),
                  items: List.generate(maxDensity, (i) => i + 1)
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
                title: Text(AppLocalizations.of(context)!.databaseManager),
                onTap: () {
                  final screenWidth = MediaQuery.of(context).size.width;
                  if (screenWidth >= 1024) {
                    ref.read(leftPanelContentProvider.notifier).state =
                        LeftPanelContent.dbManager;
                  } else {
                    if (context.canPop()) Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DatabaseManagerScreen(),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.label_outline),
                title: Text(AppLocalizations.of(context)!.manageTags),
                onTap: () {
                  if (context.canPop()) Navigator.pop(context); // Close sheet
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
                title: Text(AppLocalizations.of(context)!.exportData),
                onTap: () => _exportData(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.upload),
                title: Text(AppLocalizations.of(context)!.importData),
                onTap: () => _importData(context, ref),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: Text(
                  AppLocalizations.of(context)!.delete,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () => _deleteAllData(context, ref),
              ),
            ],
          ),
        ),
      ),
    );

    if (isSidePanel || screenWidth < 1024 || !context.canPop()) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.settings),
          centerTitle: isSidePanel ? false : null,
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: context.canPop(),
          leading: isSidePanel
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () =>
                      ref.read(leftPanelContentProvider.notifier).state =
                          LeftPanelContent.none,
                )
              : null,
        ),
        body: body,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: body,
    );
  }
}
