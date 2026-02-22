import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../providers/ui_state_provider.dart';
import '../widgets/universal_image.dart';
import 'edit_event_sheet.dart';
import 'steps_editor_screen.dart';
import '../extensions/services/ui_extension_service.dart';
import '../extensions/manager/extension_manager.dart';
import '../extensions/runtime/proxy_extension.dart';
import '../extensions/runtime/view/dynamic_engine.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  final bool isSidePanel;

  const EventDetailScreen({
    super.key,
    required this.eventId,
    this.isSidePanel = false,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _jumpToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Handle small to large screen transition
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1024;

    if (!widget.isSidePanel && isLargeScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(selectedEventIdProvider.notifier).state = widget.eventId;
          context.pop();
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final eventsAsync = ref.watch(eventsProvider);
    final event = eventsAsync.asData?.value.cast<Event?>().firstWhere(
      (e) => e?.id.toString() == widget.eventId,
      orElse: () => null,
    );

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (event == null) {
      if (widget.isSidePanel) {
        return Center(child: Text(l10n.eventNotFound));
      }
      return Scaffold(
        appBar: AppBar(title: Text(l10n.eventDetails)),
        body: Center(child: Text(l10n.eventNotFound)),
      );
    }

    final extensionContents =
        ref.watch(eventDetailContentProvider)[widget.eventId] ?? [];
    final hasExtensions = extensionContents.isNotEmpty;

    final mainPage = _buildMainPage(
      context,
      event,
      theme,
      l10n,
      onImageTap: hasExtensions ? () => _jumpToPage(1) : null,
    );

    final pages = [
      mainPage,
      ...extensionContents.map((data) => _buildExtensionPage(data)),
    ];

    if (_currentPage >= pages.length) {
      _currentPage = max(0, pages.length - 1);
      if (_pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.jumpToPage(_currentPage);
        });
      }
    }

    Widget? bottomBar;
    if (hasExtensions && _currentPage > 0) {
      bottomBar = Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentPage,
          onDestinationSelected: _jumpToPage,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(Icons.event_note),
              label: l10n.eventDetails,
            ),
            ...extensionContents.map((data) {
              return NavigationDestination(
                icon: const Icon(Icons.extension_outlined),
                selectedIcon: const Icon(Icons.extension),
                label: data['title'] as String? ?? 'Extension',
              );
            }),
          ],
        ),
      );
    }

    if (widget.isSidePanel) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.eventDetails,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditSheet(context, event, ref),
                  tooltip: l10n.edit,
                ),
                IconButton(
                  icon: const Icon(Icons.checklist_rtl_outlined),
                  onPressed: () =>
                      _navigateToStepsEditor(context, event.id, ref),
                  tooltip: l10n.steps,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmDelete(context, ref, event),
                  color: theme.colorScheme.error,
                  tooltip: l10n.delete,
                ),
                const SizedBox(width: 4),
                const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () =>
                      ref.read(selectedEventIdProvider.notifier).state = null,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: pages,
            ),
          ),
          if (hasExtensions && _currentPage > 0) bottomBar!,
        ],
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _currentPage > 0 ? bottomBar : null,
    );
  }

  Widget _buildExtensionPage(Map<String, dynamic> data) {
    final extensionId = data['extensionId'] as String;
    final content = data['content'] as Map<String, dynamic>;

    final manager = ref.watch(extensionManagerProvider);
    final extension = manager.getExtension(extensionId);

    if (extension is ProxyExtension && extension.engine != null) {
      return DynamicEngine(
        engine: extension.engine!,
        viewOverride: content,
        isEmbedded: true,
      );
    }

    return Center(child: Text('Extension $extensionId not ready'));
  }

  Widget _buildMainPage(
    BuildContext context,
    Event event,
    ThemeData theme,
    AppLocalizations l10n, {
    VoidCallback? onImageTap,
  }) {
    return SafeArea(
      top: false,
      child: CustomScrollView(
        slivers: [
          if (!widget.isSidePanel)
            SliverAppBar(
              pinned: true,
              scrolledUnderElevation: 0,
              title: Text(
                l10n.eventDetails,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showEditSheet(context, event, ref),
                  tooltip: l10n.edit,
                ),
                IconButton(
                  icon: const Icon(Icons.checklist_rtl_outlined),
                  onPressed: () =>
                      _navigateToStepsEditor(context, event.id, ref),
                  tooltip: l10n.steps,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmDelete(context, ref, event),
                  color: theme.colorScheme.error,
                  tooltip: l10n.delete,
                ),
                const SizedBox(width: 8),
              ],
            ),
          if (event.imageUrl != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Hero(
                  tag: event.id,
                  child: SizedBox(
                    height: 240,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        UniversalImage(
                          imageUrl: event.imageUrl!,
                          fit: BoxFit.cover,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onImageTap,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        if (onImageTap != null)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                // Title Section
                if (!widget.isSidePanel) ...[
                  Text(
                    event.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Info Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isSidePanel) ...[
                      Text(
                        event.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat.yMMMd(
                                  Localizations.localeOf(context).toString(),
                                ).add_Hm().format(event.createdAt),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Completion Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: event.isCompleted
                                ? theme.colorScheme.primaryContainer
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            event.isCompleted
                                ? l10n.statusCompleted
                                : l10n.statusInProgress,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: event.isCompleted
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (event.tags != null && event.tags!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: event.tags!.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (event.reminderTime != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainer,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_active_rounded,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.reminderAt(
                                  DateFormat.MMMd(
                                    Localizations.localeOf(context).toString(),
                                  ).add_Hm().format(event.reminderTime!),
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (event.description != null &&
                        event.description!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Text(
                          event.description!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 32),

                if (event.steps.isNotEmpty) ...[
                  _QuickOverview(event: event),
                  const SizedBox(height: 32),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.steps,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${event.steps.where((s) => s.completed).length}/${event.steps.length}",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _StepsList(event: event),
                const SizedBox(height: 24),
                _AddStepButton(eventId: event.id),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteSelectedMessage(1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l10n.delete,
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(eventsProvider.notifier).deleteEvent(event.id);
      ref.read(selectedEventIdProvider.notifier).state = null;
      if (!widget.isSidePanel && context.mounted) {
        context.pop();
      }
    }
  }
}

class _StepsList extends ConsumerWidget {
  final Event event;

  const _StepsList({required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (event.steps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noStepsYet,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(event.steps.length, (index) {
        final step = event.steps[index];
        final isCompleted = step.completed;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: 0,
            color: isCompleted
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  )
                : theme.colorScheme.surfaceContainerLow,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isCompleted
                    ? Colors.transparent
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  ref.read(eventsProvider.notifier).toggleStep(event.id, index),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isCompleted
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: theme.colorScheme.onPrimary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        step.description,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: isCompleted
                              ? theme.colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                )
                              : theme.colorScheme.onSurface,
                          decorationColor: theme.colorScheme.outline,
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (_isAdding) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: l10n.newStepPlaceholder,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.check_rounded),
              color: theme.colorScheme.primary,
              onPressed: _submit,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              color: theme.colorScheme.onSurfaceVariant,
              onPressed: () => setState(() => _isAdding = false),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.tonalIcon(
        onPressed: () => setState(() => _isAdding = true),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.addStep),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.quickEdit,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
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
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: List.generate(widget.event.steps.length, (index) {
                    final isBeingDragged =
                        _startDragIndex != null &&
                        ((index >= _startDragIndex! &&
                                index <=
                                    (_currentDragIndex ?? _startDragIndex!)) ||
                            (index <= _startDragIndex! &&
                                index >=
                                    (_currentDragIndex ?? _startDragIndex!)));

                    final effectiveCompleted = isBeingDragged
                        ? _dragTargetState
                        : widget.event.steps[index].completed;

                    final step = widget.event.steps[index];
                    String stepMarker;
                    if (widget.event.stepDisplayMode == 'firstChar' &&
                        step.description.trim().isNotEmpty) {
                      stepMarker = step.description.trim()[0];
                    } else {
                      stepMarker = '${index + 1}';
                    }

                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        key: _itemKeys[index],
                        onTap: () => _handleTap(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: effectiveCompleted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: effectiveCompleted
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: isBeingDragged ? 2.5 : 1,
                            ),
                            boxShadow: isBeingDragged
                                ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: effectiveCompleted
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color: theme.colorScheme.onPrimary,
                                  )
                                : Text(
                                    stepMarker,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
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
      ),
    );
  }
}
