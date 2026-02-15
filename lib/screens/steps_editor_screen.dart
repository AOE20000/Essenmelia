import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../providers/ui_state_provider.dart';
import '../widgets/keyboard_animation_handler.dart';

class StepsEditorScreen extends ConsumerStatefulWidget {
  final String eventId;
  final bool isSidePanel;

  const StepsEditorScreen({
    super.key,
    required this.eventId,
    this.isSidePanel = false,
  });

  @override
  ConsumerState<StepsEditorScreen> createState() => _StepsEditorScreenState();
}

class _StepsEditorScreenState extends ConsumerState<StepsEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _stepController = TextEditingController();
  final TextEditingController _templateController = TextEditingController();
  final FocusNode _stepFocusNode = FocusNode();
  final FocusNode _templateFocusNode = FocusNode();

  // 多选状态
  final Set<int> _selectedStepIndices = {};
  final Set<String> _selectedArchiveIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedStepIndices.clear();
          _selectedArchiveIds.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stepController.dispose();
    _templateController.dispose();
    _stepFocusNode.dispose();
    _templateFocusNode.dispose();
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

    final isSelectionMode =
        _selectedStepIndices.isNotEmpty || _selectedArchiveIds.isNotEmpty;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      resizeToAvoidBottomInset: false,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: true,
              centerTitle: false,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: theme.colorScheme.surfaceTint,
              leadingWidth: widget.isSidePanel ? 56 : null,
              leading: widget.isSidePanel
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () =>
                          ref.read(leftPanelContentProvider.notifier).state =
                              LeftPanelContent.none,
                    )
                  : null,
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isSelectionMode
                    ? Text(
                        l10n.selectedItemsCount(
                          _tabController.index == 0
                              ? _selectedStepIndices.length
                              : _selectedArchiveIds.length,
                        ),
                        key: const ValueKey('selection_title'),
                      )
                    : Text(l10n.editSteps, key: const ValueKey('normal_title')),
              ),
              actions: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelectionMode
                      ? Row(
                          key: const ValueKey('selection_actions'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_tabController.index == 0) ...[
                              IconButton(
                                tooltip: l10n.batchArchive,
                                icon: const Icon(Icons.archive_outlined),
                                onPressed: () => _handleBatchArchive(event),
                              ),
                              IconButton(
                                tooltip: l10n.saveAsSet,
                                icon: const Icon(Icons.layers_outlined),
                                onPressed: () =>
                                    _handleBatchSaveAsSetFromSteps(event),
                              ),
                            ],
                            if (_tabController.index == 1) ...[
                              IconButton(
                                tooltip: l10n.batchAdd,
                                icon: const Icon(Icons.add_task_rounded),
                                onPressed: () => _handleBatchAddToSteps(),
                              ),
                              IconButton(
                                tooltip: l10n.saveAsSet,
                                icon: const Icon(Icons.layers_outlined),
                                onPressed: () => _handleBatchSaveAsSet(),
                              ),
                            ],
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                setState(() {
                                  _selectedStepIndices.clear();
                                  _selectedArchiveIds.clear();
                                });
                              },
                            ),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('no_actions')),
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: theme.textTheme.titleSmall,
                tabs: [
                  Tab(text: l10n.steps),
                  Tab(text: l10n.archive),
                  Tab(text: l10n.sets),
                ],
              ),
            ),
          ];
        },
        body: KeyboardAnimationBuilder(
          keyboardTotalHeight: ref.watch(keyboardTotalHeightProvider),
          interpolateLastPart: true,
          focusNode: _tabController.index == 0
              ? _stepFocusNode
              : _templateFocusNode,
          onChange: (height) {
            ref.read(keyboardTotalHeightProvider.notifier).updateHeight(height);
          },
          builder: (context, keyboardHeight) {
            return RepaintBoundary(
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboardHeight),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCurrentStepsTab(event),
                    _buildArchiveTab(),
                    _buildSetsTab(event),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleBatchArchive(Event event) {
    // Process according to the original order of steps in the list
    final sortedSelectedIndices = _selectedStepIndices.toList()..sort();
    final selectedDescriptions = sortedSelectedIndices
        .map((i) => event.steps[i].description)
        .toList();

    for (final desc in selectedDescriptions) {
      ref.read(templatesControllerProvider).addTemplate(desc);
    }

    final newSteps = List<EventStep>.from(event.steps);
    // Delete from back to front to avoid index shifting
    final reversedIndices = sortedSelectedIndices.reversed.toList();
    for (final i in reversedIndices) {
      newSteps.removeAt(i);
    }

    ref.read(eventsProvider.notifier).updateSteps(event.id, newSteps);
    setState(() => _selectedStepIndices.clear());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.movedToArchive(selectedDescriptions.length),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleBatchAddToSteps() {
    final templates = ref.read(templatesProvider).asData?.value ?? [];
    // Filter according to the original order in the archive list
    final selectedTemplates = templates
        .where((t) => _selectedArchiveIds.contains(t.id))
        .toList();

    for (final t in selectedTemplates) {
      ref.read(eventsProvider.notifier).addStep(widget.eventId, t.description);
    }

    setState(() => _selectedArchiveIds.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.addedStepsCount(selectedTemplates.length),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleBatchSaveAsSetFromSteps(Event event) {
    if (_selectedStepIndices.isEmpty) return;

    final sortedSelectedIndices = _selectedStepIndices.toList()..sort();
    final selectedDescriptions = sortedSelectedIndices
        .map((i) => event.steps[i].description)
        .toList();

    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveAsSet),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.setName,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              ref
                  .read(setTemplatesControllerProvider)
                  .addSetTemplate(val.trim(), selectedDescriptions);
              setState(() => _selectedStepIndices.clear());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.setSaved),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(setTemplatesControllerProvider)
                    .addSetTemplate(
                      controller.text.trim(),
                      selectedDescriptions,
                    );
                setState(() => _selectedStepIndices.clear());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.setSaved),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _handleBatchSaveAsSet() {
    final templates = ref.read(templatesProvider).asData?.value ?? [];
    final selectedTemplates = templates
        .where((t) => _selectedArchiveIds.contains(t.id))
        .toList();

    if (selectedTemplates.isEmpty) return;

    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveAsSet),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.setName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(setTemplatesControllerProvider)
                    .addSetTemplate(
                      controller.text.trim(),
                      selectedTemplates.map((t) => t.description).toList(),
                    );
                setState(() => _selectedArchiveIds.clear());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.setSaved),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showEditStepDialog(Event event, int index, EventStep step) {
    final controller = TextEditingController(text: step.description);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.edit),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.description,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                final newSteps = List<EventStep>.from(event.steps);
                newSteps[index] = step.copyWith(
                  description: controller.text.trim(),
                );
                ref
                    .read(eventsProvider.notifier)
                    .updateSteps(event.id, newSteps);
                Navigator.pop(context);
              }
            },
            child: Text(AppLocalizations.of(context)!.save),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepsTab(Event event) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Expanded(
          child: event.steps.isEmpty
              ? SingleChildScrollView(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 64),
                        Icon(
                          Icons.checklist_rtl_outlined,
                          size: 64,
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noStepsYet,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  buildDefaultDragHandles: false,
                  itemCount: event.steps.length,
                  onReorder: (oldIndex, newIndex) {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final newSteps = List<EventStep>.from(event.steps);
                    final item = newSteps.removeAt(oldIndex);
                    newSteps.insert(newIndex, item);

                    ref
                        .read(eventsProvider.notifier)
                        .updateSteps(event.id, newSteps);
                  },
                  proxyDecorator: (child, index, animation) {
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, child) {
                        final double animValue = Curves.easeInOut.transform(
                          animation.value,
                        );
                        final double elevation = lerpDouble(0, 6, animValue)!;
                        return Material(
                          elevation: elevation,
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(16),
                          child: child,
                        );
                      },
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final step = event.steps[index];
                    final isSelected = _selectedStepIndices.contains(index);

                    return Container(
                      key: ValueKey(
                        'step_${step.timestamp.millisecondsSinceEpoch}_$index',
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            if (_selectedStepIndices.isNotEmpty) {
                              setState(() {
                                if (isSelected) {
                                  _selectedStepIndices.remove(index);
                                } else {
                                  _selectedStepIndices.add(index);
                                }
                              });
                            } else {
                              _showEditStepDialog(event, index, step);
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              _selectedStepIndices.add(index);
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedStepIndices.add(index);
                                      } else {
                                        _selectedStepIndices.remove(index);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    step.description,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: isSelected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.drag_indicator_rounded,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colorScheme.error.withValues(
                                      alpha: 0.7,
                                    ),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    final newSteps = List<EventStep>.from(
                                      event.steps,
                                    );
                                    newSteps.removeAt(index);
                                    ref
                                        .read(eventsProvider.notifier)
                                        .updateSteps(event.id, newSteps);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        _buildInputArea(
          controller: _stepController,
          focusNode: _stepFocusNode,
          hint: l10n.addNewStepPlaceholder,
          onSubmitted: (val) {
            ref.read(eventsProvider.notifier).addStep(event.id, val);
          },
        ),
      ],
    );
  }

  Widget _buildArchiveTab() {
    final templatesAsync = ref.watch(templatesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return templatesAsync.when(
      data: (templates) {
        return Column(
          children: [
            Expanded(
              child: templates.isEmpty
                  ? SingleChildScrollView(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 64),
                            Icon(
                              Icons.archive_outlined,
                              size: 64,
                              color: colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noArchiveSteps,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: templates.length,
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final elevation = lerpDouble(
                              0,
                              6,
                              animation.value,
                            )!;
                            return Material(
                              elevation: elevation,
                              borderRadius: BorderRadius.circular(16),
                              color: colorScheme.surfaceContainerHigh,
                              child: child,
                            );
                          },
                          child: child,
                        );
                      },
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final newTemplates = List<StepTemplate>.from(templates);
                        final item = newTemplates.removeAt(oldIndex);
                        newTemplates.insert(newIndex, item);
                        ref
                            .read(templatesControllerProvider)
                            .updateTemplatesOrder(newTemplates);
                      },
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        final isSelected = _selectedArchiveIds.contains(
                          template.id,
                        );

                        return Container(
                          key: ValueKey(template.id),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Material(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                if (_selectedArchiveIds.isNotEmpty) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedArchiveIds.remove(template.id);
                                    } else {
                                      _selectedArchiveIds.add(template.id);
                                    }
                                  });
                                } else {
                                  // Add to steps on tap
                                  ref
                                      .read(eventsProvider.notifier)
                                      .addStep(
                                        widget.eventId,
                                        template.description,
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.addedToSteps),
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                    ),
                                  );
                                }
                              },
                              onLongPress: () {
                                setState(() {
                                  _selectedArchiveIds.add(template.id);
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedArchiveIds.add(
                                              template.id,
                                            );
                                          } else {
                                            _selectedArchiveIds.remove(
                                              template.id,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Text(
                                        template.description,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: isSelected
                                                  ? colorScheme
                                                        .onPrimaryContainer
                                                  : colorScheme.onSurface,
                                            ),
                                      ),
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Icon(
                                          Icons.drag_indicator_rounded,
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.5),
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.add_rounded,
                                          size: 18,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(eventsProvider.notifier)
                                            .addStep(
                                              widget.eventId,
                                              template.description,
                                            );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(l10n.addedToSteps),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(
                                              milliseconds: 500,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: colorScheme.error.withValues(
                                          alpha: 0.7,
                                        ),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        ref
                                            .read(templatesControllerProvider)
                                            .deleteTemplate(template.id);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _buildInputArea(
              controller: _templateController,
              focusNode: _templateFocusNode,
              hint: l10n.addToArchivePlaceholder,
              onSubmitted: (val) {
                ref.read(templatesControllerProvider).addTemplate(val);
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(AppLocalizations.of(context)!.error(err.toString())),
      ),
    );
  }

  Widget _buildSetsTab(Event event) {
    final setsAsync = ref.watch(stepSetTemplatesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return setsAsync.when(
      data: (sets) {
        if (sets.isEmpty) {
          return SingleChildScrollView(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 64),
                  Icon(
                    Icons.layers_outlined,
                    size: 64,
                    color: colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noStepSets,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (event.steps.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        l10n.saveCurrentAsSetHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                  if (event.steps.isNotEmpty)
                    FilledButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: Text(l10n.saveCurrentStepsAsSet),
                      onPressed: () => _showSaveSetDialog(event),
                    ),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            if (event.steps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.saveCurrentStepsAsSet),
                  onPressed: () {
                    _showSaveSetDialog(event);
                  },
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: sets.length,
                itemBuilder: (context, index) {
                  final set = sets[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      backgroundColor: Colors.transparent,
                      collapsedBackgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                      ),
                      collapsedShape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                      ),
                      title: Text(
                        set.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        l10n.stepsCount(set.steps.length),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                        child: Text(
                          set.name.isNotEmpty ? set.name.characters.first : "?",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Divider(height: 32),
                              ...set.steps.map(
                                (s) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          s.description,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    tooltip: l10n.batchArchive,
                                    icon: const Icon(Icons.archive_outlined),
                                    onPressed: () {
                                      for (var s in set.steps) {
                                        ref
                                            .read(templatesControllerProvider)
                                            .addTemplate(s.description);
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.movedToArchive(
                                              set.steps.length,
                                            ),
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton.filledTonal(
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: colorScheme.error,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(setTemplatesControllerProvider)
                                          .deleteSetTemplate(set.id);
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton.icon(
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(l10n.addAllToSteps),
                                      onPressed: () {
                                        for (var s in set.steps) {
                                          ref
                                              .read(eventsProvider.notifier)
                                              .addStep(
                                                widget.eventId,
                                                s.description,
                                              );
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n.addedStepsCount(
                                                set.steps.length,
                                              ),
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(
                                              milliseconds: 500,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text(l10n.error(err.toString()))),
    );
  }

  Widget _buildInputArea({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required Function(String) onSubmitted,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    onSubmitted(value.trim());
                    controller.clear();
                    focusNode.requestFocus();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: () {
                final value = controller.text;
                if (value.trim().isNotEmpty) {
                  onSubmitted(value.trim());
                  controller.clear();
                  focusNode.requestFocus();
                }
              },
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSaveSetDialog(Event event) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveAsSet),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.setName,
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (val) => Navigator.pop(context, val),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      // 如果有选中的步骤，则只保存选中的
      final List<String> stepDescriptions;
      if (_selectedStepIndices.isNotEmpty) {
        final sortedIndices = _selectedStepIndices.toList()..sort();
        stepDescriptions = sortedIndices
            .map((i) => event.steps[i].description)
            .toList();
      } else {
        // 否则保存全部
        stepDescriptions = event.steps.map((s) => s.description).toList();
      }

      ref
          .read(setTemplatesControllerProvider)
          .addSetTemplate(result.trim(), stepDescriptions);

      if (mounted) {
        setState(() => _selectedStepIndices.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.setSaved),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
