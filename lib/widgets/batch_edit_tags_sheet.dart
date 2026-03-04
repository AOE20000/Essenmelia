import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/events_provider.dart';
import '../providers/tags_provider.dart';

class BatchEditTagsSheet extends ConsumerWidget {
  final Set<String> selectedIds;

  const BatchEditTagsSheet({super.key, required this.selectedIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.batchEditTagsTitle(selectedIds.length),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: tagsAsync.when(
                data: (allTags) {
                  if (allTags.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.label_off_outlined,
                            size: 48,
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noTags,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return eventsAsync.when(
                    data: (allEvents) {
                      final selectedEvents = allEvents
                          .where((e) => selectedIds.contains(e.id))
                          .toList();

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: allTags.map((tag) {
                          final count = selectedEvents
                              .where((e) => e.tags?.contains(tag) ?? false)
                              .length;

                          final bool isAllSelected =
                              count == selectedEvents.length;
                          final bool isNoneSelected = count == 0;
                          final bool isPartialSelected =
                              !isAllSelected && !isNoneSelected;

                          return TagBatchChip(
                            label: tag,
                            isAllSelected: isAllSelected,
                            isPartialSelected: isPartialSelected,
                            onTap: () async {
                              final bool shouldAdd = !isAllSelected;

                              for (final event in selectedEvents) {
                                final currentTags = List<String>.from(
                                  event.tags ?? [],
                                );
                                if (shouldAdd) {
                                  if (!currentTags.contains(tag)) {
                                    currentTags.add(tag);
                                  }
                                } else {
                                  currentTags.remove(tag);
                                }
                                await ref
                                    .read(eventsProvider.notifier)
                                    .updateEventTags(event.id, currentTags);
                              }
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const SizedBox.shrink(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TagBatchChip extends StatelessWidget {
  final String label;
  final bool isAllSelected;
  final bool isPartialSelected;
  final VoidCallback onTap;

  const TagBatchChip({
    super.key,
    required this.label,
    required this.isAllSelected,
    required this.isPartialSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;
    IconData icon;
    double iconSize = 18;

    if (isAllSelected) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
      icon = Icons.check_circle_rounded;
    } else if (isPartialSelected) {
      backgroundColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      icon = Icons.remove_circle_rounded;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHigh;
      textColor = theme.colorScheme.onSurfaceVariant;
      icon = Icons.circle_outlined;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: !isAllSelected && !isPartialSelected
                ? Border.all(color: theme.colorScheme.outlineVariant, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: textColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: textColor,
                    fontWeight: isAllSelected || isPartialSelected
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
