import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../providers/ui_state_provider.dart';
import '../widgets/universal_image.dart';
import 'edit_event_sheet.dart';
import 'steps_editor_screen.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;
  final bool isSidePanel;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.isSidePanel = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Handle small to large screen transition
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1024;

    if (!isSidePanel && isLargeScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(selectedEventIdProvider.notifier).state = eventId;
          context.pop();
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final eventsAsync = ref.watch(eventsProvider);
    final event = eventsAsync.asData?.value.cast<Event?>().firstWhere(
      (e) => e?.id.toString() == eventId,
      orElse: () => null,
    );

    if (event == null) {
      if (isSidePanel) {
        return Center(child: Text(AppLocalizations.of(context)!.eventNotFound));
      }
      return Scaffold(
        body: Center(child: Text(AppLocalizations.of(context)!.eventNotFound)),
      );
    }

    final body = SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          if (!isSidePanel)
            SliverAppBar(
              pinned: true,
              title: Text(event.title),
              actions: [
                _HeaderActionButton(
                  icon: Icons.edit_outlined,
                  onPressed: () => _showEditSheet(context, event, ref),
                ),
                _HeaderActionButton(
                  icon: Icons.checklist_rtl_outlined,
                  onPressed: () =>
                      _navigateToStepsEditor(context, event.id, ref),
                ),
                _HeaderActionButton(
                  icon: Icons.delete_outline,
                  color: Colors.redAccent,
                  onPressed: () => _confirmDelete(context, ref, event),
                ),
                const SizedBox(width: 8),
              ],
            ),
          if (event.imageUrl != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: UniversalImage(
                  imageUrl: event.imageUrl!,
                  height: 200,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Info Card
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context)!.createdOn(
                                  DateFormat.yMMMd(
                                    Localizations.localeOf(context).toString(),
                                  ).format(event.createdAt),
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (event.tags != null && event.tags!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: event.tags!
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  tag,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (event.description != null &&
                        event.description!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        event.description!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                if (event.steps.isNotEmpty) ...[
                  _QuickOverview(event: event),
                  const SizedBox(height: 24),
                ],

                Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.steps,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${event.steps.where((s) => s.completed).length}/${event.steps.length}",
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StepsList(event: event),
                const SizedBox(height: 16),
                _AddStepButton(eventId: event.id),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );

    if (isSidePanel) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _HeaderActionButton(
                  icon: Icons.edit_outlined,
                  onPressed: () => _showEditSheet(context, event, ref),
                ),
                _HeaderActionButton(
                  icon: Icons.checklist_rtl_outlined,
                  onPressed: () =>
                      _navigateToStepsEditor(context, event.id, ref),
                ),
                _HeaderActionButton(
                  icon: Icons.delete_outline,
                  color: Colors.redAccent,
                  onPressed: () => _confirmDelete(context, ref, event),
                ),
                const SizedBox(width: 8),
                const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                const SizedBox(width: 8),
                _HeaderActionButton(
                  icon: Icons.close,
                  onPressed: () =>
                      ref.read(selectedEventIdProvider.notifier).state = null,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(body: body);
  }

  void _showEditSheet(BuildContext context, Event event, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      ref.read(leftPanelContentProvider.notifier).state =
          LeftPanelContent.editEvent;
      ref.read(leftPanelEventIdProvider.notifier).state = event.id;
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EditEventSheet(event: event)),
      );
    }
  }

  void _navigateToStepsEditor(
    BuildContext context,
    String eventId,
    WidgetRef ref,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      ref.read(leftPanelContentProvider.notifier).state =
          LeftPanelContent.stepsEditor;
      ref.read(leftPanelEventIdProvider.notifier).state = eventId;
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StepsEditorScreen(eventId: eventId),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Event event,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.delete),
        content: Text(AppLocalizations.of(context)!.deleteSelectedMessage(1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(eventsProvider.notifier).deleteEvent(event.id);
      ref.read(selectedEventIdProvider.notifier).state = null;
      if (!isSidePanel && context.mounted) {
        context.pop();
      }
    }
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _HeaderActionButton({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.all(8),
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
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(AppLocalizations.of(context)!.noStepsYet),
        ),
      );
    }

    return Column(
      children: List.generate(event.steps.length, (index) {
        final step = event.steps[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: step.completed
                ? Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () =>
                  ref.read(eventsProvider.notifier).toggleStep(event.id, index),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: step.completed
                        ? Colors.transparent
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: step.completed
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: step.completed
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: step.completed
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          decoration: step.completed
                              ? TextDecoration.lineThrough
                              : null,
                          color: step.completed
                              ? Theme.of(context).colorScheme.outline
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.newStepPlaceholder,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _submit,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: Theme.of(context).colorScheme.outline,
              onPressed: () => setState(() => _isAdding = false),
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => setState(() => _isAdding = true),
      icon: const Icon(Icons.add),
      label: Text(AppLocalizations.of(context)!.addStep),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}

class _QuickOverview extends ConsumerStatefulWidget {
  final Event event;
  const _QuickOverview({required this.event});

  @override
  ConsumerState<_QuickOverview> createState() => _QuickOverviewState();
}

class _QuickOverviewState extends ConsumerState<_QuickOverview> {
  int? _startDragIndex;
  int? _currentDragIndex;
  bool _dragTargetState = true;
  final List<GlobalKey> _itemKeys = [];
  final List<Rect> _itemBounds = [];

  void _updateItemKeys(int count) {
    if (_itemKeys.length != count) {
      _itemKeys.clear();
      _itemKeys.addAll(List.generate(count, (_) => GlobalKey()));
    }
  }

  void _calculateBounds() {
    _itemBounds.clear();
    for (final key in _itemKeys) {
      final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final translation = renderBox.getTransformTo(null).getTranslation();
        final offset = Offset(translation.x, translation.y);
        _itemBounds.add(offset & renderBox.size);
      } else {
        _itemBounds.add(Rect.zero);
      }
    }
  }

  int? _findHitIndex(Offset globalPosition) {
    for (int i = 0; i < _itemBounds.length; i++) {
      if (_itemBounds[i].contains(globalPosition)) {
        return i;
      }
    }
    return null;
  }

  void _handleTap(int index) {
    ref.read(eventsProvider.notifier).toggleStep(widget.event.id, index);
  }

  void _handleDragStart(DragStartDetails details) {
    _calculateBounds();
    final index = _findHitIndex(details.globalPosition);
    if (index != null) {
      setState(() {
        _startDragIndex = index;
        _currentDragIndex = index;
        _dragTargetState = !widget.event.steps[index].completed;
      });
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_startDragIndex == null) return;

    final index = _findHitIndex(details.globalPosition);
    if (index != null && index != _currentDragIndex) {
      setState(() {
        _currentDragIndex = index;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_startDragIndex != null && _currentDragIndex != null) {
      final start = _startDragIndex! < _currentDragIndex!
          ? _startDragIndex!
          : _currentDragIndex!;
      final end = _startDragIndex! > _currentDragIndex!
          ? _startDragIndex!
          : _currentDragIndex!;

      final currentSteps = widget.event.steps;
      bool changed = false;
      final newSteps = currentSteps.asMap().entries.map((entry) {
        final idx = entry.key;
        final step = entry.value;
        if (idx >= start && idx <= end) {
          if (step.completed != _dragTargetState) {
            changed = true;
            return EventStep()
              ..description = step.description
              ..timestamp = step.timestamp
              ..completed = _dragTargetState;
          }
        }
        return step;
      }).toList();

      if (changed) {
        ref
            .read(eventsProvider.notifier)
            .updateSteps(widget.event.id, newSteps);
      }
    }
    setState(() {
      _startDragIndex = null;
      _currentDragIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _updateItemKeys(widget.event.steps.length);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                "快速编辑 (长按滑动)",
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onPanStart: _handleDragStart,
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            child: Container(
              width: double.infinity,
              color: Colors.transparent, // Important for hit testing
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(widget.event.steps.length, (index) {
                  final step = widget.event.steps[index];

                  // Calculate range
                  bool isBeingDragged = false;
                  if (_startDragIndex != null && _currentDragIndex != null) {
                    final start = _startDragIndex! < _currentDragIndex!
                        ? _startDragIndex!
                        : _currentDragIndex!;
                    final end = _startDragIndex! > _currentDragIndex!
                        ? _startDragIndex!
                        : _currentDragIndex!;
                    isBeingDragged = index >= start && index <= end;
                  }

                  final effectiveCompleted = isBeingDragged
                      ? _dragTargetState
                      : step.completed;

                  return GestureDetector(
                    key: _itemKeys[index],
                    onTap: () => _handleTap(index),
                    child: AnimatedScale(
                      scale: isBeingDragged ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: effectiveCompleted
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: effectiveCompleted
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: isBeingDragged ? 2 : 1,
                          ),
                          boxShadow: isBeingDragged
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: effectiveCompleted
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : Text(
                                  "${index + 1}",
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outline,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
