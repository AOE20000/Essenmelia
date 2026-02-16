import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/extension_metadata.dart';

/// Extension Store Service (Persistence Management)
class ExtensionStoreService extends StateNotifier<Map<String, String>> {
  static const String _boxName =
      'dynamic_extensions_metadata'; // Keep consistent with legacy

  ExtensionStoreService() : super({});

  Future<void> init() async {
    final box = await Hive.openBox<String>(_boxName);
    final Map<String, String> installed = {};
    for (var key in box.keys) {
      final content = box.get(key);
      if (content != null) {
        installed[key.toString()] = content;
      }
    }
    state = installed;
  }

  /// Get all installed extensions metadata
  List<ExtensionMetadata> getInstalledMetadata() {
    return state.values
        .map((content) {
          try {
            final data = jsonDecode(content);
            return ExtensionMetadata.fromJson(data);
          } catch (e) {
            debugPrint('Failed to parse extension metadata: $e');
            return null;
          }
        })
        .whereType<ExtensionMetadata>()
        .toList();
  }

  /// Get specific extension content
  String? getExtensionContent(String id) => state[id];

  /// Save/Update extension
  Future<void> saveExtension(String id, String content) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(id, content);
    state = {...state, id: content};
  }

  /// Delete extension
  Future<void> deleteExtension(String id) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(id);
    final newState = Map<String, String>.from(state);
    newState.remove(id);
    state = newState;
  }

  /// Clear all extensions
  Future<void> clearAll() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.clear();
    state = {};
  }
}

/// Extension Store Service Provider
final extensionStoreServiceProvider =
    StateNotifierProvider<ExtensionStoreService, Map<String, String>>((ref) {
      return ExtensionStoreService();
    });
