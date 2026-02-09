import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tags_provider.dart';

class FilterChips extends ConsumerWidget {
  final List<String> selectedFilters;
  final Function(String, bool) onSelected;

  const FilterChips({
    super.key,
    required this.selectedFilters,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 44, // Slightly reduced to keep it compact but enough for M3 chips
          alignment: Alignment.centerLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: tags.map((tag) {
                final isSelected = selectedFilters.contains(tag);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      tag,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    selected: isSelected,
                    onSelected: (val) => onSelected(tag, val),
                    showCheckmark: true,
                    // Remove manual paddings to let Material 3 defaults handle centering
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.standard,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }
}
