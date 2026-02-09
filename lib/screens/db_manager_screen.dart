import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/db_provider.dart';
import '../widgets/glass_container.dart';

class DatabaseManagerScreen extends ConsumerStatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  ConsumerState<DatabaseManagerScreen> createState() =>
      _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends ConsumerState<DatabaseManagerScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.databaseManager),
        backgroundColor: Colors.transparent,
      ),
      body: dbStateAsync.when(
        data: (state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppLocalizations.of(context)!.availableDatabases,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...state.availableDbs.map((dbName) {
                final isActive = dbName == state.activeDbPrefix;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassContainer(
                    child: ListTile(
                      title: Text(
                        dbName == kDefaultDbName
                            ? AppLocalizations.of(context)!.defaultDbName
                            : dbName,
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        isActive
                            ? AppLocalizations.of(context)!.currentlyActive
                            : AppLocalizations.of(context)!.inactive,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isActive)
                            TextButton(
                              onPressed: () {
                                ref
                                    .read(dbControllerProvider.notifier)
                                    .switchDb(dbName);
                                // We might need to reload or pop to ensure everything refreshes correctly
                                // But Riverpod should handle reactive updates to providers
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.switchedToDb(dbName),
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                AppLocalizations.of(context)!.switchDb,
                              ),
                            ),
                          if (dbName != kDefaultDbName)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.deleteDbTitle(dbName),
                                    ),
                                    content: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.deleteDbWarning,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          AppLocalizations.of(context)!.cancel,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(
                                          AppLocalizations.of(context)!.delete,
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  ref
                                      .read(dbControllerProvider.notifier)
                                      .deleteDb(dbName);
                                }
                              },
                            ),
                        ],
                      ),
                      leading: isActive
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : const Icon(Icons.circle_outlined),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: Text(AppLocalizations.of(context)!.createNewDatabase),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(AppLocalizations.of(context)!.error(err.toString())),
        ),
      ),
    );
  }
}
