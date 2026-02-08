import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'db_provider.dart';

class ThemeNotifier extends StateNotifier<bool> {
  final Ref ref;
  Box? _box;

  // Default to true (Dark Mode)
  ThemeNotifier(this.ref) : super(true) {
    _init();
  }

  Future<void> _init() async {
    await ref.read(dbProvider.future);
    _box = Hive.box('settings');
    
    if (_box!.containsKey('isDarkMode')) {
      state = _box!.get('isDarkMode') as bool;
    }
  }

  Future<void> toggleTheme() async {
    if (_box == null) await _init();
    final newState = !state;
    await _box!.put('isDarkMode', newState);
    state = newState;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) {
  return ThemeNotifier(ref);
});
