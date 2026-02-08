import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'db_provider.dart';

class UiStateNotifier extends StateNotifier<bool> {
  final Ref ref;
  Box? _box;

  UiStateNotifier(this.ref) : super(false) { // Start false until loaded to avoid flash
    _init();
  }

  Future<void> _init() async {
    await ref.read(dbProvider.future);
    _box = Hive.box('settings');
    
    if (_box!.containsKey('hasSeenWelcome')) {
      state = !(_box!.get('hasSeenWelcome') as bool);
    } else {
      state = true; // Show welcome if key doesn't exist
    }
  }

  Future<void> dismissWelcome() async {
    if (_box == null) await _init();
    await _box!.put('hasSeenWelcome', true);
    state = false;
  }
}

final showWelcomeProvider = StateNotifierProvider<UiStateNotifier, bool>((ref) {
  return UiStateNotifier(ref);
});
