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

                  // Sort Section
                  _buildSectionHeader(context, l10n.sort),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _SortChip(
                        label: l10n.sortNewest,
                        order: SortOrder.createdAtDesc,
                        selected:
                            searchState.sortOrder == SortOrder.createdAtDesc,
                      ),
                      _SortChip(
                        label: l10n.sortOldest,
                        order: SortOrder.createdAtAsc,
                        selected:
                            searchState.sortOrder == SortOrder.createdAtAsc,
                      ),
                      _SortChip(
                        label: l10n.sortTitleAZ,
                        order: SortOrder.titleAsc,
                        selected: searchState.sortOrder == SortOrder.titleAsc,
                      ),
                      _SortChip(
                        label: l10n.sortProgressHigh,
                        order: SortOrder.progressDesc,
                        selected:
                            searchState.sortOrder == SortOrder.progressDesc,
                      ),
                    ],
                  ),
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
                    data: (tags) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags.map((tag) {
                        final isSelected = searchState.selectedTags.contains(
                          tag,
                        );
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (val) =>
                              ref.read(searchProvider.notifier).toggleTag(tag),
                        );
                      }).toList(),
                    ),
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

class _SortChip extends ConsumerWidget {
  final String label;
  final SortOrder order;
  final bool selected;

  const _SortChip({
    required this.label,
    required this.order,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          ref.read(searchProvider.notifier).setSortOrder(order);
        }
      },
    );
  }
}
