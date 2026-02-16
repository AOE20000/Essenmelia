import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tags_provider.dart';
import '../extension_api_registry.dart';
import '../core/extension_permission.dart';

/// 标签相关的扩展 API 实现
class TagsExtensionApiHandler {
  final Ref _ref;

  // 虚拟沙箱数据
  static final Map<String, List<String>> _virtualTags = {};

  TagsExtensionApiHandler(this._ref);

  void register(ExtensionApiRegistry registry) {
    registry.register(
      'getTags',
      _getTags,
      permission: ExtensionPermission.readTags,
      operation: '读取标签列表',
      operationEn: 'Read Tag List',
      category: '数据读取',
      categoryEn: 'Data Reading',
    );
    registry.register(
      'addTag',
      _addTag,
      permission: ExtensionPermission.manageTags,
      operation: '添加新标签',
      operationEn: 'Add New Tag',
      category: '数据写入',
      categoryEn: 'Data Writing',
    );
    registry.register(
      'deleteTag',
      _deleteTag,
      permission: ExtensionPermission.manageTags,
      operation: '删除现有标签',
      operationEn: 'Delete Existing Tag',
      category: '数据写入',
      categoryEn: 'Data Writing',
    );
  }

  String _getSandboxId(Map<String, dynamic> params) {
    return params['sandboxId'] ?? 'default';
  }

  Future<dynamic> _getTags(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final tagsAsync = _ref.read(tagsProvider);
    final realTags = tagsAsync.when(
      data: (tags) => tags,
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );

    final sandboxId = _getSandboxId(params);
    final sandboxTags = _virtualTags[sandboxId] ?? [];

    if (isUntrusted) {
      // In untrusted mode, return some fake common tags mixed with sandbox tags
      return [...sandboxTags, 'Work', 'Life', 'Memo', 'Urgent'];
    }

    return [...realTags, ...sandboxTags];
  }

  Future<dynamic> _addTag(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final tag = params['tag'] as String;

    if (isUntrusted) {
      final sandboxId = _getSandboxId(params);
      final list = _virtualTags[sandboxId] ?? [];
      if (!list.contains(tag)) {
        _virtualTags[sandboxId] = [...list, tag];
      }
      return;
    }

    await _ref.read(tagsProvider.notifier).addTag(tag);
  }

  Future<dynamic> _deleteTag(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final tag = params['tag'] as String;

    if (isUntrusted) {
      final sandboxId = _getSandboxId(params);
      _virtualTags[sandboxId]?.remove(tag);
      return;
    }

    await _ref.read(tagsProvider.notifier).deleteTag(tag);
  }
}

/// 提供自动注册的 Provider
final tagsExtensionServiceProvider = Provider((ref) {
  final registry = ref.watch(extensionApiRegistryProvider);
  final handler = TagsExtensionApiHandler(ref);
  handler.register(registry);
  return handler;
});
