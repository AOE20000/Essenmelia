import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'db_provider.dart';

class UiStateNotifier extends StateNotifier<bool> {
  final Ref ref;
  Box? _box;

  UiStateNotifier(this.ref) : super(false) {
    // Start false until loaded to avoid flash
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

class ExtensionGuideNotifier extends StateNotifier<bool> {
  final Ref ref;
  Box? _box;

  ExtensionGuideNotifier(this.ref) : super(false) {
    _init();
  }

  Future<void> _init() async {
    await ref.read(dbProvider.future);
    _box = Hive.box('settings');

    if (_box!.containsKey('hasSeenExtensionGuide')) {
      state = !(_box!.get('hasSeenExtensionGuide') as bool);
    } else {
      state = true; // Show guide if key doesn't exist
    }
  }

  Future<void> dismissGuide() async {
    if (_box == null) await _init();
    await _box!.put('hasSeenExtensionGuide', true);
    state = false;
  }
}

final showExtensionGuideProvider =
    StateNotifierProvider<ExtensionGuideNotifier, bool>((ref) {
      return ExtensionGuideNotifier(ref);
    });

final selectedEventIdProvider = StateProvider<String?>((ref) => null);

enum HomeTab { events, extensions, settings }

final homeTabProvider = StateProvider<HomeTab>((ref) => HomeTab.events);

enum LeftPanelContent {
  none,
  settings,
  stepsEditor,
  addEvent,
  editEvent,
  dbManager,
  manageTags,
}

final leftPanelContentProvider = StateProvider<LeftPanelContent>(
  (ref) => LeftPanelContent.none,
);
final leftPanelEventIdProvider = StateProvider<String?>((ref) => null);

// Keyboard persistence
final keyboardTotalHeightProvider =
    StateNotifierProvider<KeyboardHeightNotifier, double>((ref) {
      return KeyboardHeightNotifier(ref);
    });

class KeyboardHeightNotifier extends StateNotifier<double> {
  static const String _key = 'keyboardTotalHeight';
  final Ref ref;

  KeyboardHeightNotifier(this.ref) : super(336.0) {
    // Default value for iOS, approx 286.0 for Android
    _init();
  }

  Future<void> _init() async {
    await ref.read(dbProvider.future);
    final box = Hive.box('settings');
    if (box.containsKey(_key)) {
      state = box.get(_key) as double;
    }
  }

  Future<void> updateHeight(double height) async {
    if (height <= 0 || height == state) return;
    state = height;
    final box = Hive.box('settings');
    await box.put(_key, height);
  }
}
