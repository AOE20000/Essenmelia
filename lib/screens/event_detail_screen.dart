import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/ui_state_provider.dart';
import '../widgets/universal_image.dart';
import 'edit_event_sheet.dart';
import 'steps_editor_screen.dart';
import '../extensions/services/ui_extension_service.dart';
import '../extensions/manager/extension_manager.dart';
import '../extensions/runtime/proxy_extension.dart';
import '../extensions/runtime/view/dynamic_engine.dart';
import '../extensions/security/extension_auth_notifier.dart';

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

  List<Widget> _buildRemindersList(
    BuildContext context,
    ThemeData theme,
    Event event,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final List<EventReminder> reminders = [];

    if ((event.reminders ?? []).isNotEmpty) {
      reminders.addAll(event.reminders!);
    } else if (event.reminderTime != null) {
      reminders.add(
        EventReminder()
          ..time = event.reminderTime!
          ..recurrence = event.reminderRecurrence ?? 'none'
          ..repeatValue = event.reminderRepeatValue
          ..repeatUnit = event.reminderRepeatUnit,
      );
    }

    return reminders.map((reminder) {
      String recurrenceStr = '';
      if (reminder.recurrence != 'none') {
        switch (reminder.recurrence) {
          case 'daily':
            recurrenceStr = l10n.daily;
            break;
          case 'weekly':
            recurrenceStr = l10n.weekly;
            break;
          case 'monthly':
            recurrenceStr = l10n.monthly;
            break;
          case 'yearly':
            recurrenceStr = l10n.yearly;
            break;
          case 'custom':
            if (reminder.repeatValue != null && reminder.repeatUnit != null) {
              String unitLabel = '';
              switch (reminder.repeatUnit) {
                case 'minute':
                  unitLabel = l10n.minutes;
                  break;
                case 'hour':
                  unitLabel = l10n.hours;
                  break;
                case 'day':
                  unitLabel = l10n.days;
                  break;
                case 'week':
                  unitLabel = l10n.weeks;
                  break;
                case 'month':
                  unitLabel = l10n.months;
                  break;
                case 'year':
                  unitLabel = l10n.years;
                  break;
              }
              recurrenceStr =
                  '${l10n.repeatEvery} ${reminder.repeatValue} $unitLabel';
            } else {
              recurrenceStr = l10n.custom;
            }
            break;
        }
      }

      String description = DateFormat.MMMd(
        locale,
      ).add_Hm().format(reminder.time);
      if (recurrenceStr.isNotEmpty) {
        description += ' ($recurrenceStr)';
      }

      if (reminder.totalCycles != null && reminder.totalCycles! > 0) {
        description +=
            ' · ${reminder.currentCycle ?? 0}/${reminder.totalCycles}';
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainer,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  reminder.recurrence == 'none'
                      ? Icons.notifications_active_rounded
                      : Icons.update_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
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

    final allExtensionContents = ref.watch(eventDetailContentProvider);
    final eventSpecificContents = allExtensionContents[widget.eventId] ?? [];
    final globalContents = allExtensionContents['*'] ?? [];
    final authNotifier = ref.watch(extensionAuthStateProvider.notifier);

    // Merge specific and global contents, ensuring no duplicates from same extension
    // And filter out extensions that are NOT running
    final Map<String, Map<String, dynamic>> mergedMap = {};

    for (var content in globalContents) {
      final extId = content['extensionId'] as String;
      if (authNotifier.isRunning(extId)) {
        mergedMap[extId] = content;
      }
    }

    for (var content in eventSpecificContents) {
      final extId = content['extensionId'] as String;
      if (authNotifier.isRunning(extId)) {
        mergedMap[extId] = content;
      }
    }

    final extensionContents = mergedMap.values.toList();

    // 仅当有实际可用的扩展内容时才显示指示器
    final hasActiveExtensions = extensionContents.isNotEmpty;

    final mainPage = _buildMainPage(
      context,
      event,
      theme,
      l10n,
      extensionContents: extensionContents,
      onImageTap: hasActiveExtensions ? () => _jumpToPage(1) : null,
    );

    final pages = [
      mainPage,
      ...extensionContents.map((data) => _buildExtensionPage(data, event.id)),
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
    if (_currentPage > 0) {
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
                if (extensionContents.isNotEmpty && event.imageUrl == null)
                  IconButton(
                    icon: const Icon(Icons.auto_awesome_outlined),
                    onPressed: () => _jumpToPage(1),
                    tooltip: extensionContents.first['title'] as String?,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
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
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: _onPageChanged,
              children: pages,
            ),
          ),
          if (_currentPage > 0) bottomBar!,
        ],
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: _onPageChanged,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _currentPage > 0 ? bottomBar : null,
    );
  }

  Widget _buildExtensionPage(Map<String, dynamic> data, String eventId) {
    final extensionId = data['extensionId'] as String;
    final content = data['content'] as Map<String, dynamic>;

    return Consumer(
      builder: (context, ref, child) {
        final manager = ref.watch(extensionManagerProvider);
        final extension = manager.getExtension(extensionId);

        if (extension is ProxyExtension && extension.engine != null) {
          // Inject eventId into state silently before rendering
          if (extension.engine!.state['eventId'] != eventId) {
            extension.engine!.updateStateSilent('eventId', eventId);
            // Notify JS of context change
            extension.engine!.callFunction('onContextChanged', {
              'eventId': eventId,
            });
          }
          return DynamicEngine(
            engine: extension.engine!,
            viewOverride: content,
            isEmbedded: true,
          );
        }

        return Center(child: Text('Extension $extensionId not ready'));
      },
    );
  }

  Widget _buildMainPage(
    BuildContext context,
    Event event,
    ThemeData theme,
    AppLocalizations l10n, {
    required List<Map<String, dynamic>> extensionContents,
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
                // 仅当 extensionContents 非空且回调有效时显示指示器图标
                if (extensionContents.isNotEmpty &&
                    event.imageUrl == null &&
                    onImageTap != null)
                  IconButton(
                    icon: const Icon(Icons.auto_awesome_outlined),
                    onPressed: onImageTap,
                    tooltip: extensionContents.first['title'] as String?,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
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
                        _buildStatusBadge(theme, l10n, event),
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
                    if ((event.reminders ?? []).isNotEmpty ||
                        event.reminderTime != null) ...[
                      const SizedBox(height: 16),
                      ..._buildRemindersList(context, theme, event),
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
                  _QuickOverview(event: event, minGroupSize: null),
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
                // _StepsList(event: event), // Removed: moving to SliverList for performance
              ]),
            ),
          ),

          // Steps List (Virtualized)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: _buildVirtualizedStepsList(context, event, theme, l10n),
          ),

          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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

  Widget _buildVirtualizedStepsList(
    BuildContext context,
    Event event,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    if (event.steps.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
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
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
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
              onLongPress: () =>
                  _showEditStepDialog(context, ref, event, index),
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
      }, childCount: event.steps.length),
    );
  }

  Widget _buildStatusBadge(
    ThemeData theme,
    AppLocalizations l10n,
    Event event,
  ) {
    final bool isCompleted = event.isCompleted;
    final bool isNotStarted =
        event.steps.isNotEmpty && event.steps.every((s) => !s.completed);

    String label = l10n.statusInProgress;
    Color bgColor = theme.colorScheme.surfaceContainerHighest;
    Color textColor = theme.colorScheme.onSurfaceVariant;

    if (isCompleted) {
      label = l10n.statusCompleted;
      bgColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
    } else if (isNotStarted) {
      label = l10n.statusNotStarted;
      // 使用更淡的颜色表示未开始
      bgColor = theme.colorScheme.surfaceContainerLow;
      textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isNotStarted
            ? Border.all(color: theme.colorScheme.outlineVariant, width: 0.5)
            : null,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
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
      // 1. Remove from selection if exists
      if (ref.read(selectionProvider).contains(event.id)) {
        ref.read(selectionProvider.notifier).toggle(event.id);
      }

      // 2. Clear focus/selection in Large Screen
      ref.read(selectedEventIdProvider.notifier).state = null;

      // 3. Perform actual deletion
      await ref.read(eventsProvider.notifier).deleteEvent(event.id);

      // 4. Navigate back on Mobile
      if (!widget.isSidePanel && context.mounted) {
        context.pop();
      }
    }
  }

  Future<void> _showEditStepDialog(
    BuildContext context,
    WidgetRef ref,
    Event event,
    int index,
  ) async {
    final step = event.steps[index];
    final controller = TextEditingController(text: step.description);
    // Position cursor at end
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(l10n.edit),
              ],
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.stepDescription,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHigh,
                prefixIcon: const Icon(Icons.checklist_rounded, size: 20),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          controller.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              maxLines: 5,
              minLines: 1,
              onChanged: (_) => setState(() {}),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  final steps = List<EventStep>.from(event.steps);
                  steps.removeAt(index);
                  ref
                      .read(eventsProvider.notifier)
                      .updateSteps(event.id, steps);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(l10n.delete),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final newDescription = controller.text.trim();
                  if (newDescription.isNotEmpty) {
                    final steps = List<EventStep>.from(event.steps);
                    steps[index] = steps[index].copyWith(
                      description: newDescription,
                    );
                    ref
                        .read(eventsProvider.notifier)
                        .updateSteps(event.id, steps);
                  }
                  Navigator.pop(context);
                },
                child: Text(l10n.confirm),
              ),
            ],
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

/// 树状图模式：每组步数阈值，低于此值则展开为序号/首字网格
const int _kTreeMinGroupSize = 50;

/// 树状图模式：每层默认分组数量（可视为“最小组”的另一种表达）
const int _kTreeDefaultGroupCount = 10;

class _QuickOverview extends ConsumerStatefulWidget {
  final Event event;

  /// 最小组大小（步数），低于此值的组直接展开为矩形网格；null 表示使用默认 _kTreeMinGroupSize。
  /// 可从设置或事件编辑中传入以实现“自定义最小组”。
  final int? minGroupSize;
  const _QuickOverview({required this.event, this.minGroupSize});

  @override
  ConsumerState<_QuickOverview> createState() => _QuickOverviewState();
}

class _QuickOverviewState extends ConsumerState<_QuickOverview> {
  int? _startDragIndex;
  int? _currentDragIndex;
  bool _dragTargetState = true;
  final List<GlobalKey> _itemKeys = [];
  final List<Rect> _itemBounds = [];

  // 为条型模式添加本地状态以保证拖动流畅
  RangeValues? _sliderValues;

  /// 树状图：当前查看的层级栈，每项为 [start, end) 步下标（仅在 initState/didUpdateWidget 中更新，避免 build 内写状态导致卡死）
  List<({int start, int end})> _viewStack = [];

  int get _effectiveMinGroupSize => widget.minGroupSize ?? _kTreeMinGroupSize;

  @override
  void initState() {
    super.initState();
    final n = widget.event.steps.length;
    if (n > 0) _viewStack = _computeInitialStack(n);
  }

  @override
  void didUpdateWidget(covariant _QuickOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = widget.event.steps.length;
    if (n != oldWidget.event.steps.length ||
        widget.event.id != oldWidget.event.id) {
      if (n > 0) {
        _viewStack = _computeInitialStack(n);
      } else {
        _viewStack = [];
      }
    }
  }

  /// 将 [start, end) 划分为若干组，用于树状图一层
  List<({int start, int end})> _groupsForRange(int start, int end) {
    final total = end - start;
    if (total <= 0) return [];
    final minSize = _effectiveMinGroupSize;
    final groupCount = total <= minSize
        ? 1
        : min(_kTreeDefaultGroupCount, max(1, total ~/ minSize));
    final step = (total / groupCount).ceil();
    final List<({int start, int end})> result = [];
    for (int i = 0; i < groupCount; i++) {
      final s = start + i * step;
      final e = i == groupCount - 1 ? end : start + (i + 1) * step;
      result.add((start: s, end: e));
    }
    return result;
  }

  /// 计算初始视图栈：默认展开到包含“当前进度”的叶子组
  List<({int start, int end})> _computeInitialStack(int stepCount) {
    if (stepCount <= 0) return [];
    final steps = widget.event.steps;
    final progressIndex = steps
        .take(stepCount)
        .where((s) => s.completed)
        .length;
    final minSize = _effectiveMinGroupSize;
    List<({int start, int end})> stack = [(start: 0, end: stepCount)];
    var range = stack.last;
    while (range.end - range.start > minSize) {
      final groups = _groupsForRange(range.start, range.end);
      ({int start, int end})? next;
      for (final g in groups) {
        if (g.start <= progressIndex && progressIndex < g.end) {
          next = g;
          break;
        }
      }
      if (next == null) break;
      stack = [...stack, next];
      range = next;
    }
    return stack;
  }

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

  void _completeStepRange(int start, int end, bool completed) {
    final currentSteps = widget.event.steps;
    if (start < 0 || end > currentSteps.length) return;
    final newSteps = currentSteps.asMap().entries.map((entry) {
      final idx = entry.key;
      final step = entry.value;
      if (idx >= start && idx < end) {
        return EventStep()
          ..description = step.description
          ..timestamp = step.timestamp
          ..completed = completed;
      }
      return step;
    }).toList();
    ref.read(eventsProvider.notifier).updateSteps(widget.event.id, newSteps);
  }

  /// 树状图：构建整张卡片（带返回、组块或序号网格）
  Widget _buildTreeModeCard(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    int stepCount,
  ) {
    final range = _viewStack.isEmpty
        ? (start: 0, end: stepCount)
        : _viewStack.last;
    final rangeSize = range.end - range.start;
    final minSize = _effectiveMinGroupSize;
    final groups = _groupsForRange(range.start, range.end);
    final isLeaf = rangeSize <= minSize || groups.length <= 1;

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
                if (_viewStack.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      style: IconButton.styleFrom(
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        setState(
                          () => _viewStack = _viewStack.sublist(
                            0,
                            _viewStack.length - 1,
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
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
            const SizedBox(height: 12),
            if (isLeaf)
              _buildTreeLeafGrid(context, theme, range.start, range.end)
            else
              _buildTreeGroupGrid(context, theme, l10n, range.start, range.end),
          ],
        ),
      ),
    );
  }

  /// 树状图：当前范围是叶子时，显示序号模式矩形网格（支持滑动更新）
  Widget _buildTreeLeafGrid(
    BuildContext context,
    ThemeData theme,
    int rangeStart,
    int rangeEnd,
  ) {
    final stepCount = rangeEnd - rangeStart;
    _updateItemKeys(stepCount);
    final steps = widget.event.steps;

    return GestureDetector(
      onPanStart: (d) {
        _calculateBounds();
        final localIndex = _findHitIndex(d.globalPosition);
        if (localIndex != null && localIndex < stepCount) {
          final index = rangeStart + localIndex;
          setState(() {
            _startDragIndex = index;
            _currentDragIndex = index;
            _dragTargetState = !steps[index].completed;
          });
        }
      },
      onPanUpdate: (d) {
        if (_startDragIndex == null) return;
        final localIndex = _findHitIndex(d.globalPosition);
        if (localIndex != null && localIndex < stepCount) {
          final index = rangeStart + localIndex;
          if (index != _currentDragIndex) {
            setState(() => _currentDragIndex = index);
          }
        }
      },
      onPanEnd: (d) {
        if (_startDragIndex != null && _currentDragIndex != null) {
          int start = _startDragIndex! < _currentDragIndex!
              ? _startDragIndex!
              : _currentDragIndex!;
          int end = _startDragIndex! > _currentDragIndex!
              ? _startDragIndex!
              : _currentDragIndex!;
          if (start < rangeStart) start = rangeStart;
          if (end >= rangeEnd) end = rangeEnd - 1;
          end += 1;
          final currentSteps = widget.event.steps;
          bool changed = false;
          final newSteps = currentSteps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            if (idx >= start && idx < end) {
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
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(
          spacing: 8,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: List.generate(stepCount, (localIndex) {
            final index = rangeStart + localIndex;
            final isBeingDragged =
                _startDragIndex != null &&
                _startDragIndex != 999 &&
                ((index >= _startDragIndex! &&
                        index <= (_currentDragIndex ?? _startDragIndex!)) ||
                    (index <= _startDragIndex! &&
                        index >= (_currentDragIndex ?? _startDragIndex!)));
            final effectiveCompleted = isBeingDragged
                ? _dragTargetState
                : steps[index].completed;
            final step = steps[index];
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
                key: _itemKeys[localIndex],
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
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
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
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
    );
  }

  /// 树状图：当前范围非叶子时，显示组块（支持组进度、点击展开、一键完成组）
  Widget _buildTreeGroupGrid(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    int rangeStart,
    int rangeEnd,
  ) {
    final groups = _groupsForRange(rangeStart, rangeEnd);
    final steps = widget.event.steps;

    return Wrap(
      spacing: 8,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: List.generate(groups.length, (i) {
        final g = groups[i];
        final total = g.end - g.start;
        final completed = steps
            .sublist(g.start, g.end)
            .where((s) => s.completed)
            .length;
        final showAsComplete = completed == total;

        return Tooltip(
          message: l10n.quickEditCompleteGroup,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() => _viewStack = [..._viewStack, g]);
              },
              onLongPress: () => _completeStepRange(g.start, g.end, true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: showAsComplete
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: showAsComplete
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${g.start + 1}–${g.end}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completed/$total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
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

  void _updateFromSlider(RangeValues values) {
    final progress = values.start.round();
    final total = values.end.round();
    final currentSteps = widget.event.steps;

    final List<EventStep> newSteps = [];
    final suffix = widget.event.stepSuffix ?? "";

    for (int i = 0; i < total; i++) {
      if (i < currentSteps.length) {
        final oldStep = currentSteps[i];
        newSteps.add(
          EventStep()
            ..description = oldStep.description
            ..timestamp = oldStep.timestamp
            ..completed = i < progress,
        );
      } else {
        // 新增步骤
        newSteps.add(
          EventStep()
            ..description = "${i + 1} $suffix"
            ..timestamp = DateTime.now()
            ..completed = i < progress,
        );
      }
    }

    ref.read(eventsProvider.notifier).updateSteps(widget.event.id, newSteps);
  }

  Widget _buildMicroAdjustButton(
    ThemeData theme,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isSlider = widget.event.stepDisplayMode == 'slider';
    final stepCount = widget.event.steps.length;

    if (isSlider) {
      // ... existing slider logic ...
      final currentProgress = widget.event.steps
          .where((s) => s.completed)
          .length
          .toDouble();
      final currentTotal = widget.event.steps.length.toDouble();

      // 初始化本地状态
      _sliderValues ??= RangeValues(currentProgress, currentTotal);

      // 如果外部数据发生变化且不是因为拖动导致的（例如撤销），则同步外部数据
      if (_startDragIndex == null &&
          (_sliderValues!.start != currentProgress ||
              _sliderValues!.end != currentTotal)) {
        _sliderValues = RangeValues(currentProgress, currentTotal);
      }

      // 优化手感：在拖动过程中保持最大值稳定，避免因比例变化导致的灵敏度异常
      // 使用 currentTotal（数据库中的真实值）来计算最大值，而不是使用正在拖动的值
      double effectiveMax;
      if (currentTotal < 100) {
        effectiveMax = 100.0;
      } else {
        // 向上取整到最近的 100，并始终保持至少 50 的增长余量
        effectiveMax = (currentTotal / 100).ceil() * 100.0;
        if (currentTotal > effectiveMax - 20) {
          effectiveMax += 100.0;
        }
      }

      // 极端情况下的安全检查：确保当前滑块不会越界
      if (_sliderValues!.end > effectiveMax) {
        effectiveMax = _sliderValues!.end;
      }

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_stories_rounded,
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
                  Text(
                    "${_sliderValues!.start.round()} / ${_sliderValues!.end.round()}",
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RangeSlider(
                      values: _sliderValues!,
                      min: 0,
                      max: effectiveMax,
                      divisions: effectiveMax.toInt() > 0
                          ? effectiveMax.toInt()
                          : 1,
                      labels: RangeLabels(
                        _sliderValues!.start.round().toString(),
                        _sliderValues!.end.round().toString(),
                      ),
                      onChanged: (values) {
                        setState(() {
                          _sliderValues = values;
                          _startDragIndex = 999; // 标记正在拖动以阻止外部同步
                        });
                      },
                      onChangeEnd: (values) {
                        setState(() => _startDragIndex = null);
                        _updateFromSlider(values);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      _buildMicroAdjustButton(theme, Icons.add_rounded, () {
                        final newStart = (_sliderValues!.start + 1).clamp(
                          0.0,
                          _sliderValues!.end,
                        );
                        final newValues = RangeValues(
                          newStart,
                          _sliderValues!.end,
                        );
                        setState(() => _sliderValues = newValues);
                        _updateFromSlider(newValues);
                      }),
                      const SizedBox(height: 8),
                      _buildMicroAdjustButton(theme, Icons.remove_rounded, () {
                        final newStart = (_sliderValues!.start - 1).clamp(
                          0.0,
                          _sliderValues!.end,
                        );
                        final newValues = RangeValues(
                          newStart,
                          _sliderValues!.end,
                        );
                        setState(() => _sliderValues = newValues);
                        _updateFromSlider(newValues);
                      }),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // 非条形时统一为树状图（叶子层为序号/首字）；不在 build 内写 _viewStack
    return _buildTreeModeCard(context, theme, l10n, stepCount);
  }
}
