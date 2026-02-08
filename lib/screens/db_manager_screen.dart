import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/db_provider.dart';
import '../widgets/glass_container.dart';

class DatabaseManagerScreen extends ConsumerStatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  ConsumerState<DatabaseManagerScreen> createState() => _DatabaseManagerScreenState();
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
        title: const Text('Create New Database'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Database Name',
            hintText: 'e.g., project-x, archive-2023',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                // Basic validation: alphanumeric and hyphens only
                if (!RegExp(r'^[a-zA-Z0-9-_]+$').hasMatch(name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid name. Use letters, numbers, -, _')),
                  );
                  return;
                }
                
                ref.read(dbControllerProvider.notifier).createDb(name);
                _nameController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
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
        title: const Text('Database Manager'),
        backgroundColor: Colors.transparent,
      ),
      body: dbStateAsync.when(
        data: (state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Available Databases',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...state.availableDbs.map((dbName) {
                final isActive = dbName == state.activeDbPrefix;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassContainer(
                    child: ListTile(
                      title: Text(
                        dbName == kDefaultDbName ? 'Main Archive (Default)' : dbName,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      subtitle: Text(isActive ? 'Currently Active' : 'Inactive'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isActive)
                            TextButton(
                              onPressed: () {
                                ref.read(dbControllerProvider.notifier).switchDb(dbName);
                                // We might need to reload or pop to ensure everything refreshes correctly
                                // But Riverpod should handle reactive updates to providers
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Switched to $dbName')),
                                );
                              },
                              child: const Text('Switch'),
                            ),
                          if (dbName != kDefaultDbName)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Delete "$dbName"?'),
                                    content: const Text('This action cannot be undone. All data in this database will be lost.'),
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
                                  ref.read(dbControllerProvider.notifier).deleteDb(dbName);
                                }
                              },
                            ),
                        ],
                      ),
                      leading: isActive 
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : const Icon(Icons.circle_outlined),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create New Database'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
