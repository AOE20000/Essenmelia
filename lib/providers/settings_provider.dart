import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'db_provider.dart';

class DisplaySettings {
  final int itemsPerRow;
  final bool collapseImages;

  const DisplaySettings({
    this.itemsPerRow = 2,
    this.collapseImages = false,
  });

  DisplaySettings copyWith({
    int? itemsPerRow,
    bool? collapseImages,
  }) {
    return DisplaySettings(
      itemsPerRow: itemsPerRow ?? this.itemsPerRow,
      collapseImages: collapseImages ?? this.collapseImages,
    );
  }
}

class DisplaySettingsNotifier extends StateNotifier<DisplaySettings> {
  final Ref ref;
  Box? _box;

  DisplaySettingsNotifier(this.ref) : super(const DisplaySettings()) {
    _init();
  }

  Future<void> _init() async {
    await ref.read(dbProvider.future);
    _box = Hive.box('settings');
    
    final itemsPerRow = _box!.get('itemsPerRow', defaultValue: 2);
    final collapseImages = _box!.get('collapseImages', defaultValue: false);
    
    state = DisplaySettings(
      itemsPerRow: itemsPerRow,
      collapseImages: collapseImages,
    );
  }

  Future<void> setItemsPerRow(int count) async {
    if (_box == null) await _init();
    await _box!.put('itemsPerRow', count);
    state = state.copyWith(itemsPerRow: count);
  }

  Future<void> toggleCollapseImages() async {
    if (_box == null) await _init();
    final newValue = !state.collapseImages;
    await _box!.put('collapseImages', newValue);
    state = state.copyWith(collapseImages: newValue);
  }
}

final displaySettingsProvider = StateNotifierProvider<DisplaySettingsNotifier, DisplaySettings>((ref) {
  return DisplaySettingsNotifier(ref);
});
