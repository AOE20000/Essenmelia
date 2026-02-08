import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../widgets/background_orbs.dart';
import '../widgets/glass_container.dart';
import '../widgets/universal_image.dart';
import 'edit_event_sheet.dart';
import 'steps_editor_screen.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsProvider);
    final event = eventsAsync.asData?.value.cast<Event?>().firstWhere(
      (e) => e?.id.toString() == eventId,
      orElse: () => null,
    );

    if (event == null) {
      return const Scaffold(body: Center(child: Text('Event not found')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => EditEventSheet(event: event),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              ref.read(eventsProvider.notifier).deleteEvent(event.id);
              context.pop();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const BackgroundOrbs(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (event.imageUrl != null)
                    UniversalImage(
                      imageUrl: event.imageUrl!,
                      height: 200,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (event.tags != null && event.tags!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: event.tags!
                                  .map(
                                    (tag) => Chip(
                                      label: Text(tag),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withOpacity(0.5),
                                      labelStyle: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        if (event.description != null) Text(event.description!),
                        const SizedBox(height: 8),
                        Text(
                          'Created on ${DateFormat.yMMMd().format(event.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Steps',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note),
                        tooltip: 'Manage Steps',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  StepsEditorScreen(eventId: event.id),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StepsList(event: event),
                  const SizedBox(height: 16),
                  _AddStepButton(eventId: event.id),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepsList extends ConsumerWidget {
  final Event event;

  const _StepsList({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (event.steps.isEmpty) {
      return const GlassContainer(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No steps yet.'),
        ),
      );
    }

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: event.steps.length,
        itemBuilder: (context, index) {
          final step = event.steps[index];
          return CheckboxListTile(
            title: Text(
              step.description,
              style: TextStyle(
                decoration: step.completed ? TextDecoration.lineThrough : null,
                color: step.completed ? Colors.white54 : null,
              ),
            ),
            value: step.completed,
            onChanged: (val) {
              ref.read(eventsProvider.notifier).toggleStep(event.id, index);
            },
            controlAffinity: ListTileControlAffinity.leading,
          );
        },
      ),
    );
  }
}

class _AddStepButton extends ConsumerStatefulWidget {
  final String eventId;

  const _AddStepButton({required this.eventId});

  @override
  ConsumerState<_AddStepButton> createState() => _AddStepButtonState();
}

class _AddStepButtonState extends ConsumerState<_AddStepButton> {
  bool _isAdding = false;
  final _controller = TextEditingController();

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      ref.read(eventsProvider.notifier).addStep(widget.eventId, text);
      _controller.clear();
      setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAdding) {
      return GlassContainer(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'New step...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton(icon: const Icon(Icons.check), onPressed: _submit),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _isAdding = false),
            ),
          ],
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () => setState(() => _isAdding = true),
      icon: const Icon(Icons.add),
      label: const Text('Add Step'),
    );
  }
}
