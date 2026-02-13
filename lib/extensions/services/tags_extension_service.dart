import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tags_provider.dart';
import '../extension_api_registry.dart';

/// 标签相关的扩展 API 实现
class TagsExtensionApiHandler {
  final Ref _ref;
  
  // 虚拟沙箱数据
  static final Map<String, List<String>> _virtualTags = {};

  TagsExtensionApiHandler(this._ref);

  void register(ExtensionApiRegistry registry) {
    registry.register('getTags', _getTags);
    registry.register('addTag', _addTag);
    registry.register('deleteTag', _deleteTag);
  }

  String _getSandboxId(Map<String, dynamic> params) {
    return params['sandboxId'] ?? 'default';
  }

  Future<dynamic> _getTags(Map<String, dynamic> params, {required bool isUntrusted}) async {
    final tagsAsync = _ref.read(tagsProvider);
    final realTags = tagsAsync.when(
      data: (tags) => tags,
      loading: () => <String>[],
      error: (_, _) => <String>[],
    );
    
    final sandboxId = _getSandboxId(params);
    final sandboxTags = _virtualTags[sandboxId] ?? [];

    if (isUntrusted) {
      // 受限模式下，返回一些虚假的常用标签混合沙箱标签
      return [...sandboxTags, '工作', '生活', '备忘', '紧急'];
    }

    return [...realTags, ...sandboxTags];
  }

  Future<dynamic> _addTag(Map<String, dynamic> params, {required bool isUntrusted}) async {
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

  Future<dynamic> _deleteTag(Map<String, dynamic> params, {required bool isUntrusted}) async {
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
