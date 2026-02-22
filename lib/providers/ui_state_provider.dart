import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../extensions/core/base_extension.dart';
import 'db_provider.dart';

enum WelcomeMode { welcome, help }

class UiState {
  final bool showWelcome;
  final WelcomeMode mode;

  UiState({required this.showWelcome, required this.mode});

  UiState copyWith({bool? showWelcome, WelcomeMode? mode}) {
    return UiState(
      showWelcome: showWelcome ?? this.showWelcome,
      mode: mode ?? this.mode,
    );
  }
}

class UiStateNotifier extends StateNotifier<UiState> {
  final Ref ref;
  Box? _box;

  UiStateNotifier(this.ref)
    : super(UiState(showWelcome: false, mode: WelcomeMode.welcome)) {
    reinit();
  }

  Future<void> reinit() async {
    await ref.read(dbProvider.future);
    _box = Hive.box('settings');

    bool show;
    if (_box!.containsKey('hasSeenWelcome')) {
      show = !(_box!.get('hasSeenWelcome') as bool);
    } else {
      show = true;
    }

    // Restore last mode
    WelcomeMode mode = WelcomeMode.welcome;
    if (_box!.containsKey('lastWelcomeMode')) {
      final modeIndex = _box!.get('lastWelcomeMode') as int;
      mode = WelcomeMode.values[modeIndex];
    }

    state = state.copyWith(showWelcome: show, mode: mode);
  }

  Future<void> dismissWelcome() async {
    if (_box == null) await reinit();
    await _box!.put('hasSeenWelcome', true);
    state = state.copyWith(showWelcome: false);
  }

  void showHelp() {
    setMode(WelcomeMode.help);
    state = state.copyWith(showWelcome: true);
  }

  Future<void> setMode(WelcomeMode mode) async {
    if (_box == null) await reinit();
    await _box!.put('lastWelcomeMode', mode.index);
    state = state.copyWith(mode: mode);
  }
}

final uiStateProvider = StateNotifierProvider<UiStateNotifier, UiState>((ref) {
  return UiStateNotifier(ref);
});

// For backward compatibility and easier watching of just the visibility
final showWelcomeProvider = Provider<bool>((ref) {
  return ref.watch(uiStateProvider).showWelcome;
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

class OnboardingNotifier extends StateNotifier<bool> {
  final Ref ref;
  Box? _box;

  OnboardingNotifier(this.ref) : super(false) {
    _init();
  }

  Future<void> _init() async {
    await ref.read(dbProvider.future);
    _box = Hive.box('settings');

    if (_box!.containsKey('hasCompletedOnboarding')) {
      state = !(_box!.get('hasCompletedOnboarding') as bool);
    } else {
      state = true; // Show onboarding if key doesn't exist
    }
  }

  Future<void> completeOnboarding() async {
    if (_box == null) await _init();
    await _box!.put('hasCompletedOnboarding', true);
    state = false;
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool>((
  ref,
) {
  return OnboardingNotifier(ref);
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
  extensionManager,
  extensionDetails,
  extensionLogs,
}

final leftPanelContentProvider = StateProvider<LeftPanelContent>(
  (ref) => LeftPanelContent.none,
);
final leftPanelEventIdProvider = StateProvider<String?>((ref) => null);
final selectedExtensionProvider = StateProvider<BaseExtension?>((ref) => null);
final runningExtensionProvider = StateProvider<BaseExtension?>((ref) => null);

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
