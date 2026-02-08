import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'db_provider.dart';
import 'events_provider.dart';

class TagsNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final Ref ref;
  Box<String>? _box;

  TagsNotifier(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      await ref.read(dbProvider.future);
      final activePrefix = ref.read(activePrefixProvider);
      _box = Hive.box<String>('${activePrefix}_tags');
      
      // Initial load
      state = AsyncValue.data(_box!.values.toList());
      
      // Watch for changes
      _box!.listenable().addListener(() {
        if (mounted) {
          state = AsyncValue.data(_box!.values.toList());
        }
      });
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTag(String tag) async {
    if (_box == null) await _init();
    
    // Check if tag already exists (case insensitive check could be better, but sticking to exact match for now)
    if (!_box!.values.contains(tag)) {
      await _box!.add(tag);
    }
  }

  Future<void> deleteTag(String tag) async {
    if (_box == null) await _init();
    
    // 1. Delete from global list
    // Find key for the value
    final Map<dynamic, String> map = _box!.toMap().cast<dynamic, String>();
    final key = map.keys.firstWhere((k) => map[k] == tag, orElse: () => null);
    
    if (key != null) {
      await _box!.delete(key);
    }

    // 2. Cascade delete from all events
    // We read the current list of events
    final eventsAsync = ref.read(eventsProvider);
    
    if (eventsAsync.hasValue) {
      final events = eventsAsync.value!;
      final eventsNotifier = ref.read(eventsProvider.notifier);
      
      for (final event in events) {
        if (event.tags != null && event.tags!.contains(tag)) {
          final newTags = List<String>.from(event.tags!)..remove(tag);
          await eventsNotifier.updateTags(event.id, newTags);
        }
      }
    }
  }
  
  Future<void> renameTag(String oldTag, String newTag) async {
    if (_box == null) await _init();
    
    // 1. Update global list
    final Map<dynamic, String> map = _box!.toMap().cast<dynamic, String>();
    final key = map.keys.firstWhere((k) => map[k] == oldTag, orElse: () => null);
    
    if (key != null) {
      await _box!.put(key, newTag);
    }

    // 2. Cascade update to all events
    final eventsAsync = ref.read(eventsProvider);
    
    if (eventsAsync.hasValue) {
      final events = eventsAsync.value!;
      final eventsNotifier = ref.read(eventsProvider.notifier);
      
      for (final event in events) {
        if (event.tags != null && event.tags!.contains(oldTag)) {
          final newTags = List<String>.from(event.tags!);
          final index = newTags.indexOf(oldTag);
          if (index != -1) {
            newTags[index] = newTag;
            await eventsNotifier.updateTags(event.id, newTags);
          }
        }
      }
    }
  }
}

final tagsProvider = StateNotifierProvider<TagsNotifier, AsyncValue<List<String>>>((ref) {
  return TagsNotifier(ref);
});
