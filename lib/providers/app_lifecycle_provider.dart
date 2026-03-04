import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track the application's lifecycle state.
final appLifecycleProvider = StateNotifierProvider<AppLifecycleNotifier, AppLifecycleState>((ref) {
  return AppLifecycleNotifier();
});

class AppLifecycleNotifier extends StateNotifier<AppLifecycleState> with WidgetsBindingObserver {
  AppLifecycleNotifier() : super(AppLifecycleState.resumed) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get isInBackground => state == AppLifecycleState.paused || state == AppLifecycleState.inactive;
  bool get isResumed => state == AppLifecycleState.resumed;
}

/// Provider to track if the application is idle (long time no operation).
final appIdleProvider = StateProvider<bool>((ref) => false);

class IdleDetector extends ConsumerWidget {
  final Widget child;
  final Duration idleTimeout;

  const IdleDetector({
    super.key,
    required this.child,
    this.idleTimeout = const Duration(minutes: 5),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Timer? idleTimer;

    void resetTimer() {
      if (ref.read(appIdleProvider)) {
        ref.read(appIdleProvider.notifier).state = false;
      }
      idleTimer?.cancel();
      idleTimer = Timer(idleTimeout, () {
        ref.read(appIdleProvider.notifier).state = true;
      });
    }

    return Listener(
      onPointerDown: (_) => resetTimer(),
      onPointerMove: (_) => resetTimer(),
      onPointerHover: (_) => resetTimer(),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
