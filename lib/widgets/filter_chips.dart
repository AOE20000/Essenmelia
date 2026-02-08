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

        return SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: tags.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final tag = tags[index];
              final isSelected = selectedFilters.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                onSelected: (val) => onSelected(tag, val),
                backgroundColor: Colors.white10,
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.white24,
                  ),
                ),
                showCheckmark: false,
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
