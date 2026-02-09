import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../providers/filtered_events_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_state_provider.dart';
import '../widgets/filter_chips.dart';
import '../widgets/universal_image.dart';
import '../widgets/welcome_overlay.dart';
import 'edit_event_sheet.dart';
import 'event_detail_screen.dart';
import 'settings_sheet.dart';
import 'steps_editor_screen.dart';
import 'db_manager_screen.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = ref.watch(filteredEventsProvider);
    final selectedIds = ref.watch(selectionProvider);
    final isSelectionMode = selectedIds.isNotEmpty;
    final displaySettings = ref.watch(displaySettingsProvider);
    final selectedEventId = ref.watch(selectedEventIdProvider);
    final leftPanelContent = ref.watch(leftPanelContentProvider);
    final leftPanelEventId = ref.watch(leftPanelEventIdProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1024;
    final isSmallScreen = screenWidth < 600;

    // Handle cross-screen detail navigation logic
    if (selectedEventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isLargeScreen && context.mounted) {
          // Switch from Large side panel to Small full screen
          final id = selectedEventId;
          ref.read(selectedEventIdProvider.notifier).state = null;
          context.push('/event/$id');
        }
      });
    }

    // Adaptive column count
    final itemsPerRow = displaySettings.itemsPerRow.clamp(
      1,
      isSmallScreen ? 2 : 5,
    );

    return Scaffold(
      floatingActionButton:
          isSelectionMode ||
              (isLargeScreen && leftPanelContent == LeftPanelContent.addEvent)
          ? null
          : FloatingActionButton(
              onPressed: () => _handleOpenAddEvent(context),
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            // Bottom Layer: Main Content and Right Detail Panel
            Row(
              children: [
                // Main Content Area
                Expanded(
                  child: Column(
                    children: [
                      // Fixed Top Bar
                      _buildFixedTopBar(
                        context,
                        isSelectionMode,
                        selectedIds.length,
                        isLargeScreen,
                      ),

                      // Scrolling Content
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            // Welcome (only in normal mode)
                            if (!isSelectionMode)
                              const SliverToBoxAdapter(child: WelcomeCard()),

                            // The Grid
                            if (filteredEvents.isEmpty)
                              const _EmptyStateSliver()
                            else
                              SliverPadding(
                                padding: const EdgeInsets.all(16),
                                sliver: SliverMasonryGrid.count(
                                  crossAxisCount: itemsPerRow,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childCount: filteredEvents.length,
                                  itemBuilder: (context, index) {
                                    final event = filteredEvents[index];
                                    return _EventCard(
                                          key: ValueKey(event.id),
                                          event: event,
                                          collapseImage:
                                              displaySettings.collapseImages,
                                          isFocused:
                                              isLargeScreen &&
                                              selectedEventId == event.id,
                                          isSelected: selectedIds.contains(
                                            event.id,
                                          ),
                                          isSelectionMode: isSelectionMode,
                                        )
                                        .animate()
                                        .fadeIn(delay: (30 * index).ms)
                                        .slideY(begin: 0.1, end: 0);
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Side Panel (Large Screen Details) - Stays in Row
                if (isLargeScreen && selectedEventId != null)
                  _SideDetailPanel(
                    screenWidth: screenWidth,
                    selectedEventId: selectedEventId,
                  ),
              ],
            ),

            // Scrim for Left Panel
            if (isLargeScreen && leftPanelContent != LeftPanelContent.none)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () =>
                      ref.read(leftPanelContentProvider.notifier).state =
                          LeftPanelContent.none,
                  child: Container(
                    color: Colors.black.withOpacity(0.3), // Slightly darker
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms),

            // Top Layer: Left Floating Side Panel (Large Screen)
            if (isLargeScreen && leftPanelContent != LeftPanelContent.none)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _SideLeftPanel(
                  screenWidth: screenWidth,
                  content: leftPanelContent,
                  eventId: leftPanelEventId,
                ),
              ).animate().slideX(
                begin: -1,
                end: 0,
                duration: 300.ms,
                curve: Curves.easeOutCubic,
              ),
          ],
        ),
      ),
    );
  }

  void _handleOpenAddEvent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      ref.read(leftPanelContentProvider.notifier).state =
          LeftPanelContent.addEvent;
      ref.read(leftPanelEventIdProvider.notifier).state = null;
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EditEventSheet()),
      );
    }
  }

  void _handleOpenSettings(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      ref.read(leftPanelContentProvider.notifier).state =
          LeftPanelContent.settings;
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsSheet()),
      );
    }
  }

  Widget _buildFixedTopBar(
    BuildContext context,
    bool isSelectionMode,
    int selectedCount,
    bool isLargeScreen,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upper Part: Search/Settings OR Selection Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: isSelectionMode
                ? _buildSelectionBar(context, selectedCount)
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(
                              context,
                            )!.searchPlaceholder,
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                          onChanged: (val) =>
                              ref.read(searchProvider.notifier).setQuery(val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SortMenu(),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => _handleOpenSettings(context),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 8),

          // Lower Part: Always show Tags
          FilterChips(
            selectedFilters: ref.watch(searchProvider).selectedTags,
            onSelected: (tag, _) =>
                ref.read(searchProvider.notifier).toggleTag(tag),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context, int count) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(selectionProvider.notifier).clear(),
            ),
            const SizedBox(width: 8),
            Text(
              '$count ${AppLocalizations.of(context)!.selected}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmBatchDelete(context, count),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBatchDelete(BuildContext context, int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteSelectedConfirmation),
        content: Text(
          AppLocalizations.of(context)!.deleteSelectedMessage(count),
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
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(batchActionsProvider).deleteSelected();
    }
  }
}

class _SortMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<SortOrder>(
      icon: const Icon(Icons.sort),
      tooltip: AppLocalizations.of(context)!.sort,
      onSelected: (order) =>
          ref.read(searchProvider.notifier).setSortOrder(order),
      itemBuilder: (context) => [
        _sortItem(
          context,
          SortOrder.createdAtDesc,
          AppLocalizations.of(context)!.sortNewest,
        ),
        _sortItem(
          context,
          SortOrder.createdAtAsc,
          AppLocalizations.of(context)!.sortOldest,
        ),
        _sortItem(
          context,
          SortOrder.titleAsc,
          AppLocalizations.of(context)!.sortTitleAZ,
        ),
        _sortItem(
          context,
          SortOrder.titleDesc,
          AppLocalizations.of(context)!.sortTitleZA,
        ),
        _sortItem(
          context,
          SortOrder.progressDesc,
          AppLocalizations.of(context)!.sortProgressHigh,
        ),
        _sortItem(
          context,
          SortOrder.progressAsc,
          AppLocalizations.of(context)!.sortProgressLow,
        ),
      ],
    );
  }

  PopupMenuItem<SortOrder> _sortItem(
    BuildContext context,
    SortOrder value,
    String label,
  ) {
    return PopupMenuItem(value: value, child: Text(label));
  }
}

class _EmptyStateSliver extends StatelessWidget {
  const _EmptyStateSliver();
  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.noEventsFound,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _SideLeftPanel extends ConsumerWidget {
  final double screenWidth;
  final LeftPanelContent content;
  final String? eventId;

  const _SideLeftPanel({
    required this.screenWidth,
    required this.content,
    this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget child;
    switch (content) {
      case LeftPanelContent.settings:
        child = const SettingsSheet(isSidePanel: true);
        break;
      case LeftPanelContent.stepsEditor:
        final id = eventId;
        if (id == null) {
          child = const Center(child: Text("No event selected"));
        } else {
          child = StepsEditorScreen(eventId: id, isSidePanel: true);
        }
        break;
      case LeftPanelContent.addEvent:
        child = const EditEventSheet(isSidePanel: true);
        break;
      case LeftPanelContent.editEvent:
        final id = eventId;
        final event = ref
            .watch(eventsProvider)
            .asData
            ?.value
            .cast<Event?>()
            .firstWhere((e) => e?.id == id, orElse: () => null);
        if (event == null) {
          child = const Center(child: Text("Event not found"));
        } else {
          child = EditEventSheet(event: event, isSidePanel: true);
        }
        break;
      case LeftPanelContent.dbManager:
        child = const DatabaseManagerScreen(isSidePanel: true);
        break;
      case LeftPanelContent.none:
        return const SizedBox.shrink();
    }

    return Container(
      width: screenWidth * 0.35, // Increased slightly for better readability
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(5, 0),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SideDetailPanel extends StatelessWidget {
  final double screenWidth;
  final String selectedEventId;

  const _SideDetailPanel({
    required this.screenWidth,
    required this.selectedEventId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: screenWidth * 0.3,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: EventDetailScreen(eventId: selectedEventId, isSidePanel: true),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final Event event;
  final bool collapseImage;
  final bool isFocused;
  final bool isSelected;
  final bool isSelectionMode;

  const _EventCard({
    super.key,
    required this.event,
    this.collapseImage = false,
    this.isFocused = false,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: isSelected ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (isSelected || isFocused)
              ? theme.colorScheme.primary
              : theme.dividerColor.withOpacity(0.1),
          width: (isSelected || isFocused) ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleTap(context, ref),
        onLongPress: () =>
            ref.read(selectionProvider.notifier).toggle(event.id),
        child: Stack(
          children: [
            // Content
            Opacity(
              opacity: isSelected ? 0.5 : 1.0,
              child: _buildContent(context),
            ),

            // Selection Overlay
            if (isSelected)
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  child: const Center(
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.check, color: Colors.indigo),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    if (isSelectionMode) {
      ref.read(selectionProvider.notifier).toggle(event.id);
    } else if (MediaQuery.of(context).size.width >= 1024) {
      ref.read(selectedEventIdProvider.notifier).state = event.id;
    } else {
      context.push('/event/${event.id}');
    }
  }

  Widget _buildContent(BuildContext context) {
    final completedSteps = event.steps.where((s) => s.completed).length;
    final progress = event.steps.isNotEmpty
        ? completedSteps / event.steps.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.imageUrl != null && !collapseImage)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: UniversalImage(imageUrl: event.imageUrl!, fit: BoxFit.cover),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (event.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  event.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (event.tags?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                _TagsWrap(tags: event.tags!),
              ],
              if (event.steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ProgressBar(
                  progress: progress,
                  completed: completedSteps,
                  total: event.steps.length,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(event.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagsWrap extends StatelessWidget {
  final List<String> tags;
  const _TagsWrap({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tag,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final int completed;
  final int total;

  const _ProgressBar({
    required this.progress,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 4),
        Text(
          '$completed / $total steps',
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
