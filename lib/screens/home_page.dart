import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../providers/filtered_events_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/filter_chips.dart';
import '../widgets/universal_image.dart';
import '../widgets/welcome_overlay.dart';
import 'edit_event_sheet.dart';
import 'settings_sheet.dart';

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

  void _toggleFilter(String tag, bool selected) {
    ref.read(searchProvider.notifier).toggleTag(tag);
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = ref.watch(filteredEventsProvider);
    final selectedIds = ref.watch(selectionProvider);
    final isSelectionMode = selectedIds.isNotEmpty;
    final displaySettings = ref.watch(displaySettingsProvider);

    return Scaffold(
      floatingActionButton: isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const EditEventSheet(),
                );
              },
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: isSelectionMode
                    ? _buildSelectionBar(context, selectedIds.length)
                    : _buildHeader(context),
              ),
            ),
            if (!isSelectionMode) ...[
              const SliverToBoxAdapter(child: WelcomeCard()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterHeaderDelegate(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: FilterChips(
                      selectedFilters: ref.watch(searchProvider).selectedTags,
                      onSelected: _toggleFilter,
                    ),
                  ),
                ),
              ),
            ],
            if (filteredEvents.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    AppLocalizations.of(context)!.noEventsFound,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: displaySettings.itemsPerRow,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    return _EventCard(
                          event: filteredEvents[index],
                          collapseImage: displaySettings.collapseImages,
                        )
                        .animate()
                        .fadeIn(delay: (50 * index).ms)
                        .slideY(begin: 0.1, end: 0);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context, int count) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
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
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      AppLocalizations.of(context)!.deleteSelectedConfirmation,
                    ),
                    content: Text(
                      AppLocalizations.of(
                        context,
                      )!.deleteSelectedMessage(count),
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context)!.appTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => const SettingsSheet(),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchPlaceholder,
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) {
                  ref.read(searchProvider.notifier).setQuery(val);
                },
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<SortOrder>(
              icon: const Icon(Icons.sort),
              tooltip: AppLocalizations.of(context)!.sort,
              onSelected: (order) {
                ref.read(searchProvider.notifier).setSortOrder(order);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: SortOrder.createdAtDesc,
                  child: Text(AppLocalizations.of(context)!.sortNewest),
                ),
                PopupMenuItem(
                  value: SortOrder.createdAtAsc,
                  child: Text(AppLocalizations.of(context)!.sortOldest),
                ),
                PopupMenuItem(
                  value: SortOrder.titleAsc,
                  child: Text(AppLocalizations.of(context)!.sortTitleAZ),
                ),
                PopupMenuItem(
                  value: SortOrder.titleDesc,
                  child: Text(AppLocalizations.of(context)!.sortTitleZA),
                ),
                PopupMenuItem(
                  value: SortOrder.progressDesc,
                  child: Text(AppLocalizations.of(context)!.sortProgressHigh),
                ),
                PopupMenuItem(
                  value: SortOrder.progressAsc,
                  child: Text(AppLocalizations.of(context)!.sortProgressLow),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _FilterHeaderDelegate({required this.child});

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      // Optional: Add blur here if we want the sticky header to be glass-like
      // For now, transparent to let orbs show through, but might need background for readability
      color: Colors.transparent,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return true;
  }
}

class _EventCard extends ConsumerWidget {
  final Event event;
  final bool collapseImage;

  const _EventCard({required this.event, this.collapseImage = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectionProvider);
    final isSelected = selectedIds.contains(event.id);
    final isSelectionMode = selectedIds.isNotEmpty;

    final completedSteps = event.steps.where((s) => s.completed).length;
    final progress = event.steps.isNotEmpty
        ? completedSteps / event.steps.length
        : 0.0;

    return GestureDetector(
      onTap: () {
        if (isSelectionMode) {
          ref.read(selectionProvider.notifier).toggle(event.id);
        } else {
          context.push('/event/${event.id}');
        }
      },
      onLongPress: () {
        ref.read(selectionProvider.notifier).toggle(event.id);
      },
      child: Stack(
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.imageUrl != null && !collapseImage)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: UniversalImage(
                      imageUrl: event.imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (event.description != null &&
                          event.description!.isNotEmpty)
                        Text(
                          event.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 8),
                      if (event.tags != null && event.tags!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: event.tags!
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      tag,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(fontSize: 10),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      if (event.steps.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completedSteps / ${event.steps.length} steps',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
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
            ),
          ),
          if (isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
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
    );
  }
}
