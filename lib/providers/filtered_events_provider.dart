import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/event.dart';
import 'events_provider.dart';
import 'db_provider.dart';

enum SortOrder {
  createdAtDesc,
  createdAtAsc,
  titleAsc,
  titleDesc,
  progressDesc,
  progressAsc,
  stepCountDesc,
  stepCountAsc,
  tagCountDesc,
  tagCountAsc,
  lastUpdatedDesc,
  lastUpdatedAsc,
}

enum EventStatusFilter { all, notStarted, inProgress, completed }

class SearchState {
  final String query;
  final List<String> selectedTags;
  final SortOrder sortOrder;
  final EventStatusFilter statusFilter;
  final bool onlyShowReminders;

  const SearchState({
    this.query = '',
    this.selectedTags = const [],
    this.sortOrder = SortOrder.createdAtDesc,
    this.statusFilter = EventStatusFilter.all,
    this.onlyShowReminders = false,
  });

  SearchState copyWith({
    String? query,
    List<String>? selectedTags,
    SortOrder? sortOrder,
    EventStatusFilter? statusFilter,
    bool? onlyShowReminders,
  }) {
    return SearchState(
      query: query ?? this.query,
      selectedTags: selectedTags ?? this.selectedTags,
      sortOrder: sortOrder ?? this.sortOrder,
      statusFilter: statusFilter ?? this.statusFilter,
      onlyShowReminders: onlyShowReminders ?? this.onlyShowReminders,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  Box? _box;

  SearchNotifier(this.ref) : super(const SearchState()) {
    _init();
  }

  Future<void> _init() async {
    await ref.read(dbProvider.future);
    _box = Hive.box('settings');
    final savedSortOrder = _box!.get('sortOrder');
    if (savedSortOrder != null) {
      try {
        state = state.copyWith(
          sortOrder: SortOrder.values.firstWhere(
            (e) => e.toString() == savedSortOrder,
            orElse: () => SortOrder.createdAtDesc,
          ),
        );
      } catch (_) {}
    }
  }

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

  void clearTags() {
    state = state.copyWith(selectedTags: []);
  }

  Future<void> setSortOrder(SortOrder order) async {
    state = state.copyWith(sortOrder: order);
    if (_box != null) {
      await _box!.put('sortOrder', order.toString());
    }
  }

  void setStatusFilter(EventStatusFilter filter) {
    state = state.copyWith(statusFilter: filter);
  }

  void toggleOnlyShowReminders() {
    state = state.copyWith(onlyShowReminders: !state.onlyShowReminders);
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  return SearchNotifier(ref);
});

final filteredEventsProvider = Provider<List<Event>>((ref) {
  final eventsAsync = ref.watch(eventsProvider);
  final searchState = ref.watch(searchProvider);

  if (!eventsAsync.hasValue) return [];

  final events = eventsAsync.value!;

  // 1. Filter
  var filtered = events.where((e) {
    // Status Filter
    if (searchState.statusFilter != EventStatusFilter.all) {
      final progress = _calculateProgress(e);
      switch (searchState.statusFilter) {
        case EventStatusFilter.notStarted:
          if (progress > 0) return false;
          break;
        case EventStatusFilter.inProgress:
          if (progress <= 0 || progress >= 1.0) return false;
          break;
        case EventStatusFilter.completed:
          if (progress < 1.0) return false;
          break;
        case EventStatusFilter.all:
          break;
      }
    }

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

    // Reminder Filter
    if (searchState.onlyShowReminders) {
      if (e.reminderTime == null) return false;
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
      case SortOrder.stepCountDesc:
        return b.steps.length.compareTo(a.steps.length);
      case SortOrder.stepCountAsc:
        return a.steps.length.compareTo(b.steps.length);
      case SortOrder.tagCountDesc:
        return (b.tags?.length ?? 0).compareTo(a.tags?.length ?? 0);
      case SortOrder.tagCountAsc:
        return (a.tags?.length ?? 0).compareTo(b.tags?.length ?? 0);
      case SortOrder.lastUpdatedDesc:
        final lastA = _getLastUpdated(a);
        final lastB = _getLastUpdated(b);
        return lastB.compareTo(lastA);
      case SortOrder.lastUpdatedAsc:
        final lastA = _getLastUpdated(a);
        final lastB = _getLastUpdated(b);
        return lastA.compareTo(lastB);
    }
  });

  return filtered;
});

DateTime _getLastUpdated(Event e) {
  if (e.steps.isEmpty) return e.createdAt;
  // 获取步骤中最晚的时间戳
  return e.steps.map((s) => s.timestamp).reduce((v, e) => v.isAfter(e) ? v : e);
}

double _calculateProgress(Event e) {
  if (e.steps.isEmpty) return 0;
  final completed = e.steps.where((s) => s.completed).length;
  return completed / e.steps.length;
}
