import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../base_extension.dart';

/// 扩展存储服务，负责已安装扩展的持久化管理（CRUD）
class ExtensionStoreService extends StateNotifier<Map<String, String>> {
  static const String _boxName =
      'dynamic_extensions_metadata'; // 保持与 ExtensionManager 一致

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

  /// 获取所有已安装扩展的元数据
  List<ExtensionMetadata> getInstalledMetadata() {
    return state.values
        .map((content) {
          try {
            final data = jsonDecode(content);
            // 确保能解析新版的包格式
            return ExtensionMetadata.fromJson(data);
          } catch (e) {
            debugPrint('Failed to parse extension metadata: $e');
            return null;
          }
        })
        .whereType<ExtensionMetadata>()
        .toList();
  }

  /// 获取指定扩展的内容
  String? getExtensionContent(String id) => state[id];

  /// 保存/更新扩展
  Future<void> saveExtension(String id, String content) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(id, content);
    state = {...state, id: content};
  }

  /// 移除扩展
  Future<void> removeExtension(String id) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(id);
    state = {...state}..remove(id);
  }

  /// 清空所有扩展
  Future<void> clearAll() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.clear();
    state = {};
  }
}

/// 扩展存储服务 Provider
final extensionStoreServiceProvider =
    StateNotifierProvider<ExtensionStoreService, Map<String, String>>((ref) {
      return ExtensionStoreService();
    });
