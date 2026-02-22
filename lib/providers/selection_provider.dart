import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'events_provider.dart';

class SelectionNotifier extends StateNotifier<Set<String>> {
  SelectionNotifier() : super({});

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state}..add(id);
    }
  }

  void clear() {
    state = {};
  }
  
  void selectAll(List<String> ids) {
    state = Set.from(ids);
  }

  void invert(List<String> allIds) {
    final allSet = Set<String>.from(allIds);
    state = allSet.difference(state);
  }

  bool get isSelectionMode => state.isNotEmpty;
}

final selectionProvider = StateNotifierProvider<SelectionNotifier, Set<String>>((ref) {
  return SelectionNotifier();
});

// Helper for batch actions
final batchActionsProvider = Provider((ref) {
  return BatchActionsController(ref);
});

class BatchActionsController {
  final Ref ref;
  BatchActionsController(this.ref);

  Future<void> deleteSelected() async {
    final selectedIds = ref.read(selectionProvider);
    final notifier = ref.read(eventsProvider.notifier);
    
    for (final id in selectedIds) {
      await notifier.deleteEvent(id);
    }
    
    ref.read(selectionProvider.notifier).clear();
  }

  Future<void> updateSuffix(String suffix) async {
    final selectedIds = ref.read(selectionProvider);
    final notifier = ref.read(eventsProvider.notifier);
    
    for (final id in selectedIds) {
      await notifier.updateSuffix(id, suffix);
    }
    
    ref.read(selectionProvider.notifier).clear();
  }

  Future<void> adjustProgress(int delta) async {
    final selectedIds = ref.read(selectionProvider);
    final notifier = ref.read(eventsProvider.notifier);
    
    for (final id in selectedIds) {
      await notifier.adjustProgress(id, delta);
    }
    
    // Keep selection active for repeated actions
    // ref.read(selectionProvider.notifier).clear();
  }
}
