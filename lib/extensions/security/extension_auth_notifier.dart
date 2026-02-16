import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../core/extension_permission.dart';

/// Extension permission state management
final extensionAuthStateProvider =
    StateNotifierProvider<ExtensionAuthNotifier, Map<String, List<String>>>((
      ref,
    ) {
      return ExtensionAuthNotifier(ref);
    });

class ExtensionAuthNotifier extends StateNotifier<Map<String, List<String>>> {
  final Ref _ref;
  late final Future<void> ready;

  ExtensionAuthNotifier(this._ref) : super({}) {
    ready = _load();
  }

  static const _boxName = 'extension_auth_v2';
  static const _untrustedPrefix = 'untrusted_';
  static const _runningPrefix = 'running_';
  static const _nextRunPrefix = 'next_run_';
  static const _sandboxPrefix = 'sandbox_';
  static const _manifestHashPrefix = 'hash_';

  /// Paused extensions (in-memory only)
  final Set<String> _pausedExtensions = {};

  Future<void> _load() async {
    final box = await Hive.openBox(_boxName);
    final Map<String, List<String>> loaded = {};
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null) {
        loaded[key.toString()] = List<String>.from(
          value is List ? value : [value.toString()],
        );
      }
    }
    state = loaded;
  }

  /// Get sandbox ID, defaults to extension ID (individual isolation)
  String getSandboxId(String extensionId) {
    final key = '$_sandboxPrefix$extensionId';
    final val = state[key]?.firstOrNull;
    return val ?? extensionId;
  }

  /// Set sandbox ID
  Future<void> setSandboxId(String extensionId, String sandboxId) async {
    await ready;
    final box = await Hive.openBox(_boxName);
    final key = '$_sandboxPrefix$extensionId';
    // If empty or same as extensionId, revert to default
    if (sandboxId.isEmpty || sandboxId == extensionId) {
      await box.delete(key);
      state = Map.from(state)..remove(key);
    } else {
      await box.put(key, [sandboxId]);
      state = {
        ...state,
        key: [sandboxId],
      };
    }
  }

  void setPaused(String extensionId, bool paused) {
    if (paused) {
      _pausedExtensions.add(extensionId);
    } else {
      _pausedExtensions.remove(extensionId);
    }
    // Trigger UI update
    state = {...state};
  }

  /// Reset all permissions and state
  Future<void> resetAll() async {
    final box = await Hive.openBox(_boxName);
    await box.clear();
    _pausedExtensions.clear();
    state = {};
  }

  bool isPaused(String extensionId) => _pausedExtensions.contains(extensionId);

  Future<void> togglePermission(
    String extensionId,
    ExtensionPermission permission,
  ) async {
    await ready;
    final box = await Hive.openBox(_boxName);
    final currentPerms = List<String>.from(state[extensionId] ?? []);
    final permName = permission.name;

    if (currentPerms.contains(permName)) {
      currentPerms.remove(permName);
    } else {
      currentPerms.add(permName);
    }

    await box.put(extensionId, currentPerms);
    state = {...state, extensionId: currentPerms};
  }

  /// Grant permission post-hoc
  Future<void> grantPermission(
    String extensionId,
    ExtensionPermission permission,
  ) async {
    await ready;
    if (!hasPermission(extensionId, permission)) {
      await togglePermission(extensionId, permission);
    }
  }

  Future<void> setUntrusted(String extensionId, bool untrusted) async {
    await ready;
    final box = await Hive.openBox(_boxName);
    final key = '$_untrustedPrefix$extensionId';
    await box.put(key, [untrusted.toString()]);
    state = {
      ...state,
      key: [untrusted.toString()],
    };
  }

  Future<void> setRunning(String extensionId, bool running) async {
    await ready;
    final box = await Hive.openBox(_boxName);
    final key = '$_runningPrefix$extensionId';
    await box.put(key, [running.toString()]);
    state = {
      ...state,
      key: [running.toString()],
    };
    
    // Note: Session permission clearing should be handled by the caller or a separate provider listener
    // to avoid circular dependency if we import sessionPermissionsProvider here.
    if (!running) {
       final nextRunKey = '$_nextRunPrefix$extensionId';
       await box.delete(nextRunKey);
    }
  }

  bool isUntrusted(String extensionId) {
    final key = '$_untrustedPrefix$extensionId';
    final val = state[key]?.firstOrNull;
    return val == 'true';
  }

  bool isRunning(String extensionId) {
    final key = '$_runningPrefix$extensionId';
    final val = state[key]?.firstOrNull;
    // Default to true (enabled)
    return val != 'false';
  }

  bool hasPermission(String extensionId, ExtensionPermission permission) {
    return state[extensionId]?.contains(permission.name) ?? false;
  }

  Future<void> setNextRunPermission(String extensionId, String category) async {
    await ready;
    final box = await Hive.openBox(_boxName);
    final key = '$_nextRunPrefix$extensionId';
    final current = List<String>.from(state[key] ?? []);
    if (!current.contains(category)) {
      current.add(category);
      await box.put(key, current);
      state = {...state, key: current};
    }
  }

  List<String> getNextRunPermissions(String extensionId) {
    final key = '$_nextRunPrefix$extensionId';
    return state[key] ?? [];
  }

  Future<void> clearNextRunPermissions(String extensionId) async {
    await ready;
    final box = await Hive.openBox(_boxName);
    final key = '$_nextRunPrefix$extensionId';
    await box.delete(key);
    state = {...state}..remove(key);
  }

  Future<void> setManifestHash(String extensionId, String hash) async {
    await ready;
    final box = await Hive.openBox(_boxName);
    final key = '$_manifestHashPrefix$extensionId';
    await box.put(key, [hash]);
    state = {
      ...state,
      key: [hash],
    };
  }

  String? getManifestHash(String extensionId) {
    final key = '$_manifestHashPrefix$extensionId';
    return state[key]?.firstOrNull;
  }

  Future<bool> consumeNextRunPermission(
    String extensionId,
    String category,
  ) async {
    await ready;
    final key = '$_nextRunPrefix$extensionId';
    final current = List<String>.from(state[key] ?? []);
    if (current.contains(category)) {
      current.remove(category);
      final box = await Hive.openBox(_boxName);
      if (current.isEmpty) {
        await box.delete(key);
        state = {...state}..remove(key);
      } else {
        await box.put(key, current);
        state = {...state, key: current};
      }
      return true;
    }
    return false;
  }
}
