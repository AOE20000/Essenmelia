import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'db_provider.dart';

class LocaleNotifier extends StateNotifier<Locale?> {
  final Ref ref;
  Box? _box;

  LocaleNotifier(this.ref) : super(null) {
    reinit();
  }

  Future<void> reinit() async {
    await ref.read(dbProvider.future);
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox('settings');
    }
    _box = Hive.box('settings');

    final savedCode = _box!.get('languageCode');
    if (savedCode != null) {
      state = Locale(savedCode);
    } else {
      state = null; // Follow system
    }
  }

  Future<void> setLocale(Locale? locale) async {
    if (_box == null) await reinit();
    
    if (locale == null) {
      await _box!.delete('languageCode');
      state = null;
    } else {
      await _box!.put('languageCode', locale.languageCode);
      state = locale;
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier(ref);
});
