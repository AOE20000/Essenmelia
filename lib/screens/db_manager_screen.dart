import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/db_provider.dart';
import '../providers/ui_state_provider.dart';

class DatabaseManagerScreen extends ConsumerStatefulWidget {
  final bool isSidePanel;
  const DatabaseManagerScreen({super.key, this.isSidePanel = false});

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

    final body = dbStateAsync.when(
      data: (state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              AppLocalizations.of(context)!.availableDatabases,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...state.availableDbs.map((dbName) {
              final isActive = dbName == state.activeDbPrefix;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: isActive ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isActive
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.5)
                          : Theme.of(context).dividerColor.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                  color: isActive
                      ? Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withOpacity(0.3)
                      : Theme.of(context).colorScheme.surface,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      dbName == kDefaultDbName
                          ? AppLocalizations.of(context)!.defaultDbName
                          : dbName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isActive
                            ? AppLocalizations.of(context)!.currentlyActive
                            : AppLocalizations.of(context)!.inactive,
                        style: TextStyle(
                          color: isActive
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.8)
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isActive)
                          IconButton(
                            icon: const Icon(Icons.swap_horiz),
                            tooltip: AppLocalizations.of(context)!.switchDb,
                            onPressed: () {
                              ref
                                  .read(dbControllerProvider.notifier)
                                  .switchDb(dbName);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  content: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.switchedToDb(dbName),
                                  ),
                                ),
                              );
                            },
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
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
                                          fontWeight: FontWeight.bold,
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
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.storage : Icons.storage_outlined,
                        size: 20,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context)!.createNewDatabase),
              style: FilledButton.styleFrom(
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
    );

    if (widget.isSidePanel) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.databaseManager),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => ref.read(leftPanelContentProvider.notifier).state =
                LeftPanelContent.none,
          ),
        ),
        body: body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.databaseManager),
      ),
      body: body,
    );
  }
}
