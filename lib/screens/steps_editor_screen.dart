import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../widgets/glass_container.dart';

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Edit Steps'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Steps'),
            Tab(text: 'Archive'),
            Tab(text: 'Sets'),
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
                color: Colors.white10,
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
          hint: 'Add new step...',
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
                  color: Colors.white10,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(template.description),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.add,
                            color: Colors.greenAccent,
                          ),
                          onPressed: () {
                            ref
                                .read(eventsProvider.notifier)
                                .addStep(widget.eventId, template.description);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Added to steps'),
                                duration: Duration(milliseconds: 500),
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
            hint: 'Add to archive...',
            onSubmitted: (val) {
              ref.read(templatesControllerProvider).addTemplate(val);
            },
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
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
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save current steps as Template Set'),
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
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                label: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                                onPressed: () {
                                  ref
                                      .read(setTemplatesControllerProvider)
                                      .deleteSetTemplate(set.id);
                                },
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add All to Steps'),
                                onPressed: () {
                                  for (var s in set.steps) {
                                    ref
                                        .read(eventsProvider.notifier)
                                        .addStep(widget.eventId, s.description);
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Added ${set.steps.length} steps',
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
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildInputArea({
    required TextEditingController controller,
    required String hint,
    required Function(String) onSubmitted,
  }) {
    return GlassContainer(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: 50,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
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
        title: const Text('Save Template Set'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Template Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
                  const SnackBar(content: Text('Template Set Saved')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
