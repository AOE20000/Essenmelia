import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/filtered_events_provider.dart';
import '../providers/tags_provider.dart';
import '../l10n/app_localizations.dart';
import '../screens/manage_tags_screen.dart';

class FilterBottomSheet extends ConsumerWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tagsAsync = ref.watch(tagsProvider);

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  l10n.filter,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref
                        .read(searchProvider.notifier)
                        .setStatusFilter(EventStatusFilter.all);
                    ref
                        .read(searchProvider.notifier)
                        .setSortOrder(SortOrder.createdAtDesc);
                    ref.read(searchProvider.notifier).clearTags();
                    if (searchState.onlyShowReminders) {
                      ref
                          .read(searchProvider.notifier)
                          .toggleOnlyShowReminders();
                    }
                  },
                  child: Text(l10n.clearAllTags),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Section
                  _buildSectionHeader(context, l10n.status),
                  const SizedBox(height: 12),
                  SegmentedButton<EventStatusFilter>(
                    segments: [
                      ButtonSegment(
                        value: EventStatusFilter.all,
                        label: Text(l10n.statusAll),
                      ),
                      ButtonSegment(
                        value: EventStatusFilter.notStarted,
                        label: Text(l10n.statusNotStarted),
                      ),
                      ButtonSegment(
                        value: EventStatusFilter.inProgress,
                        label: Text(l10n.statusInProgress),
                      ),
                      ButtonSegment(
                        value: EventStatusFilter.completed,
                        label: Text(l10n.statusCompleted),
                      ),
                    ],
                    selected: {searchState.statusFilter},
                    onSelectionChanged: (newSelection) {
                      ref
                          .read(searchProvider.notifier)
                          .setStatusFilter(newSelection.first);
                    },
                    showSelectedIcon: false,
                  ),
                  const SizedBox(height: 24),

                  // Reminder Filter Section
                  Material(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    child: SwitchListTile(
                      title: const Text('仅显示带提醒的事件'),
                      subtitle: const Text('过滤掉没有设置定时提醒的任务'),
                      secondary: Icon(
                        searchState.onlyShowReminders
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        color: searchState.onlyShowReminders
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      value: searchState.onlyShowReminders,
                      onChanged: (_) => ref
                          .read(searchProvider.notifier)
                          .toggleOnlyShowReminders(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Sort Section
                  _buildSortSection(context, ref, searchState, l10n),
                  const SizedBox(height: 24),

                  // Tags Section
                  Row(
                    children: [
                      _buildSectionHeader(context, l10n.tags),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageTagsScreen(),
                            ),
                          );
                        },
                        tooltip: l10n.manageTags,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  tagsAsync.when(
                    data: (tags) {
                      final sortedTags = List<String>.from(tags)..sort();

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: sortedTags.map((tag) {
                          final isSelected = searchState.selectedTags.contains(
                            tag,
                          );
                          return FilterChip(
                            label: Text(tag),
                            selected: isSelected,
                            onSelected: (val) => ref
                                .read(searchProvider.notifier)
                                .toggleTag(tag),
                          );
                        }).toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Action Button
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.confirm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSection(
    BuildContext context,
    WidgetRef ref,
    SearchState searchState,
    AppLocalizations l10n,
  ) {
    final currentOrder = searchState.sortOrder;
    final isAsc = _isAscending(currentOrder);
    final category = _getCategory(currentOrder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionHeader(context, l10n.sort),
            const Spacer(),
            IconButton(
              icon: Icon(
                isAsc ? Icons.arrow_upward : Icons.arrow_downward,
                size: 20,
              ),
              onPressed: () {
                final newOrder = _toggleDirection(currentOrder);
                ref.read(searchProvider.notifier).setSortOrder(newOrder);
              },
              tooltip: isAsc ? l10n.sortOldest : l10n.sortNewest,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SortCategoryChip(
              label: l10n.sortNewest,
              selected: category == _SortCategory.time,
              onSelected: (val) {
                if (val) {
                  ref
                      .read(searchProvider.notifier)
                      .setSortOrder(
                        isAsc
                            ? SortOrder.createdAtAsc
                            : SortOrder.createdAtDesc,
                      );
                }
              },
            ),
            _SortCategoryChip(
              label: l10n.sortTitleAZ.split(' ')[0], // "标题"
              selected: category == _SortCategory.title,
              onSelected: (val) {
                if (val) {
                  ref
                      .read(searchProvider.notifier)
                      .setSortOrder(
                        isAsc ? SortOrder.titleAsc : SortOrder.titleDesc,
                      );
                }
              },
            ),
            _SortCategoryChip(
              label: l10n.sortProgressHigh.split(' ')[0], // "进度"
              selected: category == _SortCategory.progress,
              onSelected: (val) {
                if (val) {
                  ref
                      .read(searchProvider.notifier)
                      .setSortOrder(
                        isAsc ? SortOrder.progressAsc : SortOrder.progressDesc,
                      );
                }
              },
            ),
            _SortCategoryChip(
              label: l10n.sortLastUpdated.split(' ')[0], // "更新"
              selected: category == _SortCategory.lastUpdated,
              onSelected: (val) {
                if (val) {
                  ref
                      .read(searchProvider.notifier)
                      .setSortOrder(
                        isAsc
                            ? SortOrder.lastUpdatedAsc
                            : SortOrder.lastUpdatedDesc,
                      );
                }
              },
            ),
            _SortCategoryChip(
              label: l10n.sortStepCountHigh.split(' ')[0], // "步骤数"
              selected: category == _SortCategory.stepCount,
              onSelected: (val) {
                if (val) {
                  ref
                      .read(searchProvider.notifier)
                      .setSortOrder(
                        isAsc
                            ? SortOrder.stepCountAsc
                            : SortOrder.stepCountDesc,
                      );
                }
              },
            ),
            _SortCategoryChip(
              label: l10n.sortTagCountHigh.split(' ')[0], // "标签数"
              selected: category == _SortCategory.tagCount,
              onSelected: (val) {
                if (val) {
                  ref
                      .read(searchProvider.notifier)
                      .setSortOrder(
                        isAsc ? SortOrder.tagCountAsc : SortOrder.tagCountDesc,
                      );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  bool _isAscending(SortOrder order) {
    return order == SortOrder.createdAtAsc ||
        order == SortOrder.titleAsc ||
        order == SortOrder.progressAsc ||
        order == SortOrder.stepCountAsc ||
        order == SortOrder.tagCountAsc ||
        order == SortOrder.lastUpdatedAsc;
  }

  _SortCategory _getCategory(SortOrder order) {
    switch (order) {
      case SortOrder.createdAtAsc:
      case SortOrder.createdAtDesc:
        return _SortCategory.time;
      case SortOrder.titleAsc:
      case SortOrder.titleDesc:
        return _SortCategory.title;
      case SortOrder.progressAsc:
      case SortOrder.progressDesc:
        return _SortCategory.progress;
      case SortOrder.stepCountAsc:
      case SortOrder.stepCountDesc:
        return _SortCategory.stepCount;
      case SortOrder.tagCountAsc:
      case SortOrder.tagCountDesc:
        return _SortCategory.tagCount;
      case SortOrder.lastUpdatedAsc:
      case SortOrder.lastUpdatedDesc:
        return _SortCategory.lastUpdated;
    }
  }

  SortOrder _toggleDirection(SortOrder order) {
    switch (order) {
      case SortOrder.createdAtAsc:
        return SortOrder.createdAtDesc;
      case SortOrder.createdAtDesc:
        return SortOrder.createdAtAsc;
      case SortOrder.titleAsc:
        return SortOrder.titleDesc;
      case SortOrder.titleDesc:
        return SortOrder.titleAsc;
      case SortOrder.progressAsc:
        return SortOrder.progressDesc;
      case SortOrder.progressDesc:
        return SortOrder.progressAsc;
      case SortOrder.stepCountAsc:
        return SortOrder.stepCountDesc;
      case SortOrder.stepCountDesc:
        return SortOrder.stepCountAsc;
      case SortOrder.tagCountAsc:
        return SortOrder.tagCountDesc;
      case SortOrder.tagCountDesc:
        return SortOrder.tagCountAsc;
      case SortOrder.lastUpdatedAsc:
        return SortOrder.lastUpdatedDesc;
      case SortOrder.lastUpdatedDesc:
        return SortOrder.lastUpdatedAsc;
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

enum _SortCategory { time, title, progress, stepCount, tagCount, lastUpdated }

class _SortCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _SortCategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}
