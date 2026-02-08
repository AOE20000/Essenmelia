import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event.dart';
import 'events_provider.dart';

enum SortOrder {
  createdAtDesc,
  createdAtAsc,
  titleAsc,
  titleDesc,
  progressDesc,
  progressAsc,
}

class SearchState {
  final String query;
  final List<String> selectedTags;
  final SortOrder sortOrder;

  const SearchState({
    this.query = '',
    this.selectedTags = const [],
    this.sortOrder = SortOrder.createdAtDesc,
  });

  SearchState copyWith({
    String? query,
    List<String>? selectedTags,
    SortOrder? sortOrder,
  }) {
    return SearchState(
      query: query ?? this.query,
      selectedTags: selectedTags ?? this.selectedTags,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier() : super(const SearchState());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void toggleTag(String tag) {
    final tags = List<String>.from(state.selectedTags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(selectedTags: tags);
  }

  void setSortOrder(SortOrder order) {
    state = state.copyWith(sortOrder: order);
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  return SearchNotifier();
});

final filteredEventsProvider = Provider<List<Event>>((ref) {
  final eventsAsync = ref.watch(eventsProvider);
  final searchState = ref.watch(searchProvider);

  if (!eventsAsync.hasValue) return [];

  final events = eventsAsync.value!;

  // 1. Filter
  var filtered = events.where((e) {
    // Tag Filter
    if (searchState.selectedTags.isNotEmpty) {
      if (e.tags == null) return false;
      if (!searchState.selectedTags.every((tag) => e.tags!.contains(tag))) {
        return false;
      }
    }

    // Query Filter
    if (searchState.query.isNotEmpty) {
      final q = searchState.query.toLowerCase();
      final titleMatch = e.title.toLowerCase().contains(q);
      final descMatch = e.description?.toLowerCase().contains(q) ?? false;
      if (!titleMatch && !descMatch) return false;
    }

    return true;
  }).toList();

  // 2. Sort
  filtered.sort((a, b) {
    switch (searchState.sortOrder) {
      case SortOrder.createdAtDesc:
        return b.createdAt.compareTo(a.createdAt);
      case SortOrder.createdAtAsc:
        return a.createdAt.compareTo(b.createdAt);
      case SortOrder.titleAsc:
        return a.title.compareTo(b.title);
      case SortOrder.titleDesc:
        return b.title.compareTo(a.title);
      case SortOrder.progressDesc:
        return _calculateProgress(b).compareTo(_calculateProgress(a));
      case SortOrder.progressAsc:
        return _calculateProgress(a).compareTo(_calculateProgress(b));
    }
  });

  return filtered;
});

double _calculateProgress(Event e) {
  if (e.steps.isEmpty) return 0;
  final completed = e.steps.where((s) => s.completed).length;
  return completed / e.steps.length;
}
