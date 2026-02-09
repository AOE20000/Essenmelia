import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';

class StepsEditorScreen extends ConsumerStatefulWidget {
  final String eventId;

  const StepsEditorScreen({super.key, required this.eventId});

  @override
  ConsumerState<StepsEditorScreen> createState() => _StepsEditorScreenState();
}

class _StepsEditorScreenState extends ConsumerState<StepsEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _stepController = TextEditingController();
  final TextEditingController _templateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stepController.dispose();
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final event = eventsAsync.asData?.value.cast<Event?>().firstWhere(
      (e) => e?.id == widget.eventId,
      orElse: () => null,
    );

    if (event == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editSteps),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.steps),
            Tab(text: AppLocalizations.of(context)!.archive),
            Tab(text: AppLocalizations.of(context)!.sets),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrentStepsTab(event),
          _buildArchiveTab(),
          _buildSetsTab(event),
        ],
      ),
    );
  }

  Widget _buildCurrentStepsTab(Event event) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: event.steps.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final newSteps = List<EventStep>.from(event.steps);
              final item = newSteps.removeAt(oldIndex);
              newSteps.insert(newIndex, item);

              ref.read(eventsProvider.notifier).updateSteps(event.id, newSteps);
            },
            itemBuilder: (context, index) {
              final step = event.steps[index];
              return Card(
                key: ValueKey(
                  '${step.description}_$index',
                ), // Better key strategy needed in real app
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(step.description),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      final newSteps = List<EventStep>.from(event.steps);
                      newSteps.removeAt(index);
                      ref
                          .read(eventsProvider.notifier)
                          .updateSteps(event.id, newSteps);
                    },
                  ),
                ),
              );
            },
          ),
        ),
        _buildInputArea(
          controller: _stepController,
          hint: AppLocalizations.of(context)!.addNewStepPlaceholder,
          onSubmitted: (val) {
            ref.read(eventsProvider.notifier).addStep(event.id, val);
          },
        ),
      ],
    );
  }

  Widget _buildArchiveTab() {
    final templatesAsync = ref.watch(templatesProvider);

    return templatesAsync.when(
      data: (templates) => Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(template.description),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.add,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onPressed: () {
                            ref
                                .read(eventsProvider.notifier)
                                .addStep(widget.eventId, template.description);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(context)!.addedToSteps,
                                ),
                                duration: const Duration(milliseconds: 500),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            ref
                                .read(templatesControllerProvider)
                                .deleteTemplate(template.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildInputArea(
            controller: _templateController,
            hint: AppLocalizations.of(context)!.addToArchivePlaceholder,
            onSubmitted: (val) {
              ref.read(templatesControllerProvider).addTemplate(val);
            },
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(AppLocalizations.of(context)!.error(err.toString())),
      ),
    );
  }

  Widget _buildSetsTab(Event event) {
    final setsAsync = ref.watch(stepSetTemplatesProvider);

    return setsAsync.when(
      data: (sets) => Column(
        children: [
          if (event.steps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: Text(
                  AppLocalizations.of(context)!.saveCurrentStepsAsSet,
                ),
                onPressed: () {
                  _showSaveSetDialog(event);
                },
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sets.length,
              itemBuilder: (context, index) {
                final set = sets[index];
                return ExpansionTile(
                  title: Text(set.name),
                  subtitle: Text('${set.steps.length} steps'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...set.steps.map(
                            (s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '• ${s.description}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: Icon(
                                  Icons.delete,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                label: Text(
                                  AppLocalizations.of(context)!.delete,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                onPressed: () {
                                  ref
                                      .read(setTemplatesControllerProvider)
                                      .deleteSetTemplate(set.id);
                                },
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                icon: const Icon(Icons.add),
                                label: Text(
                                  AppLocalizations.of(context)!.addAllToSteps,
                                ),
                                onPressed: () {
                                  for (var s in set.steps) {
                                    ref
                                        .read(eventsProvider.notifier)
                                        .addStep(widget.eventId, s.description);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.addedStepsCount(set.steps.length),
                                      ),
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(AppLocalizations.of(context)!.error(err.toString())),
      ),
    );
  }

  Widget _buildInputArea({
    required TextEditingController controller,
    required String hint,
    required Function(String) onSubmitted,
  }) {
    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  onSubmitted(val.trim());
                  controller.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSubmitted(controller.text.trim());
                controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showSaveSetDialog(Event event) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.saveTemplateSet),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.templateName,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                ref
                    .read(setTemplatesControllerProvider)
                    .addSetTemplate(
                      nameController.text.trim(),
                      event.steps.map((s) => s.description).toList(),
                    );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!.templateSetSaved,
                    ),
                  ),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }
}
