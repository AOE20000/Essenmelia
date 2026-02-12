import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tags_provider.dart';

class ManageTagsScreen extends ConsumerWidget {
  const ManageTagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.manageTags)),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noTagsYet,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return Dismissible(
                key: Key(tag),
                background: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        AppLocalizations.of(context)!.deleteTagConfirmation,
                      ),
                      content: Text(
                        AppLocalizations.of(context)!.deleteTagWarning(tag),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(AppLocalizations.of(context)!.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            AppLocalizations.of(context)!.delete,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) {
                  ref.read(tagsProvider.notifier).deleteTag(tag);
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.label,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(tag),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () => _showEditDialog(context, ref, tag),
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(AppLocalizations.of(context)!.error(err.toString())),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.newTag),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.tagName,
            hintText: AppLocalizations.of(context)!.tagNameHint,
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              final tag = controller.text.trim();
              if (tag.isNotEmpty) {
                ref.read(tagsProvider.notifier).addTag(tag);
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.add),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, String oldTag) {
    final controller = TextEditingController(text: oldTag);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.renameTag),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.tagName,
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newTag = controller.text.trim();
              if (newTag.isNotEmpty && newTag != oldTag) {
                ref.read(tagsProvider.notifier).renameTag(oldTag, newTag);
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}
