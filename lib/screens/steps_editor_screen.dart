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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: widget.isSidePanel
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(leftPanelContentProvider.notifier).state =
                        LeftPanelContent.none,
              )
            : null,
        title: isSelectionMode
            ? Text(
                l10n.selectedItemsCount(
                  _tabController.index == 0
                      ? _selectedStepIndices.length
                      : _selectedArchiveIds.length,
                ),
              )
            : Text(l10n.editSteps),
        actions: [
          if (isSelectionMode) ...[
            if (_tabController.index == 0)
              IconButton(
                tooltip: l10n.batchArchive,
                icon: const Icon(Icons.archive_outlined),
                onPressed: () => _handleBatchArchive(event),
              ),
            if (_tabController.index == 1) ...[
              IconButton(
                tooltip: l10n.batchAdd,
                icon: const Icon(Icons.add_task),
                onPressed: () => _handleBatchAddToSteps(),
              ),
              IconButton(
                tooltip: l10n.saveAsSet,
                icon: const Icon(Icons.layers_outlined),
                onPressed: () => _handleBatchSaveAsSet(),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _selectedStepIndices.clear();
                  _selectedArchiveIds.clear();
                });
              },
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.steps),
            Tab(text: l10n.archive),
            Tab(text: l10n.sets),
          ],
        ),
      ),
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
    );
  }

  void _handleBatchArchive(Event event) {
    final selectedDescriptions = _selectedStepIndices
        .map((i) => event.steps[i].description)
        .toList();

    for (final desc in selectedDescriptions) {
      ref.read(templatesControllerProvider).addTemplate(desc);
    }

    final newSteps = List<EventStep>.from(event.steps);
    final sortedIndices = _selectedStepIndices.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final i in sortedIndices) {
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

    if (event.steps.isEmpty) {
      return SingleChildScrollView(
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
              const SizedBox(height: 32),
              _buildInputArea(
                controller: _stepController,
                focusNode: _stepFocusNode,
                hint: l10n.addNewStepPlaceholder,
                onSubmitted: (val) {
                  ref.read(eventsProvider.notifier).addStep(event.id, val);
                },
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            buildDefaultDragHandles: true,
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
            proxyDecorator: (child, index, animation) {
              return Material(
                elevation: 4,
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
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
                child: Card(
                  elevation: 0,
                  color: isSelected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 8, right: 8),
                    leading: Checkbox(
                      value: isSelected,
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
                    title: Text(
                      step.description,
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: colorScheme.primary.withValues(alpha: 0.7),
                          ),
                          onPressed: () =>
                              _showEditStepDialog(event, index, step),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error.withValues(alpha: 0.7),
                          ),
                          onPressed: () {
                            final newSteps = List<EventStep>.from(event.steps);
                            newSteps.removeAt(index);
                            ref
                                .read(eventsProvider.notifier)
                                .updateSteps(event.id, newSteps);
                          },
                        ),
                        const SizedBox(width: 32), // 为默认拖动按钮预留空间
                      ],
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
        if (templates.isEmpty) {
          return SingleChildScrollView(
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
                  const SizedBox(height: 32),
                  _buildInputArea(
                    controller: _templateController,
                    focusNode: _templateFocusNode,
                    hint: l10n.addToArchivePlaceholder,
                    onSubmitted: (val) {
                      ref.read(templatesControllerProvider).addTemplate(val);
                    },
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final isSelected = _selectedArchiveIds.contains(template.id);

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Card(
                      elevation: 0,
                      color: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                        ),
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedArchiveIds.add(template.id);
                              } else {
                                _selectedArchiveIds.remove(template.id);
                              }
                            });
                          },
                        ),
                        title: Text(
                          template.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add,
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(l10n.addedToSteps),
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(milliseconds: 500),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: colorScheme.error.withValues(alpha: 0.7),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: sets.length,
                itemBuilder: (context, index) {
                  final set = sets[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      backgroundColor: colorScheme.surfaceContainerLow,
                      collapsedBackgroundColor: Colors.transparent,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                      ),
                      collapsedShape: const RoundedRectangleBorder(
                        side: BorderSide.none,
                      ),
                      title: Text(
                        set.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        l10n.stepsCount(set.steps.length),
                        style: theme.textTheme.bodySmall,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.secondaryContainer,
                        child: Text(
                          set.name.isNotEmpty ? set.name.characters.first : "?",
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Divider(),
                              ...set.steps.map(
                                (s) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "• ",
                                        style: TextStyle(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    icon: Icon(
                                      Icons.delete_outline,
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
                                      icon: const Icon(Icons.add),
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
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: colorScheme.outline.withValues(alpha: 0.7),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      onSubmitted(val.trim());
                      controller.clear();
                      focusNode.requestFocus();
                    }
                  },
                ),
              ),
              AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final isEmpty = controller.text.trim().isEmpty;
                  return IconButton.filled(
                    onPressed: isEmpty
                        ? null
                        : () {
                            onSubmitted(controller.text.trim());
                            controller.clear();
                            focusNode.requestFocus();
                          },
                    icon: const Icon(Icons.add, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      disabledBackgroundColor: colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                      disabledForegroundColor: colorScheme.outline,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
