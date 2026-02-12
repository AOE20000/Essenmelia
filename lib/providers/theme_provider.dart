import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'db_provider.dart';

enum ThemeModeOption { system, light, dark }

class ThemeNotifier extends StateNotifier<ThemeModeOption> {
  final Ref ref;
  Box? _box;

  // Default to system
  ThemeNotifier(this.ref) : super(ThemeModeOption.system) {
    _init();
  }

  Future<void> _init() async {
    await ref.read(dbProvider.future);
    _box = Hive.box('settings');

    if (_box!.containsKey('themeMode')) {
      final index = _box!.get('themeMode') as int;
      state = ThemeModeOption.values[index];
    } else if (_box!.containsKey('isDarkMode')) {
      // 兼容旧版本数据
      final isDark = _box!.get('isDarkMode') as bool;
      state = isDark ? ThemeModeOption.dark : ThemeModeOption.light;
      await _box!.put('themeMode', state.index);
      await _box!.delete('isDarkMode');
    }
  }

  Future<void> setThemeMode(ThemeModeOption mode) async {
    if (_box == null) await _init();
    state = mode;
    await _box!.put('themeMode', mode.index);
  }

  // 辅助方法，用于旧代码兼容或特定场景判断
  bool isDarkMode(BuildContext context) {
    if (state == ThemeModeOption.system) {
      return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return state == ThemeModeOption.dark;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeModeOption>((
  ref,
) {
  return ThemeNotifier(ref);
});
