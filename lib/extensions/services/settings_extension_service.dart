import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../runtime/api/extension_api_registry.dart';
import '../core/extension_permission.dart';

/// 扩展私有设置相关的 API 实现
class SettingsExtensionApiHandler {
  /// 虚拟沙箱设置存储
  static final Map<String, Map<String, dynamic>> _virtualSettings = {};

  SettingsExtensionApiHandler(Ref ref);

  void register(ExtensionApiRegistry registry) {
    registry.register(
      'getSetting',
      _getSetting,
      permission: ExtensionPermission.systemInfo,
      operation: 'Read Extension Private Settings',
      operationEn: 'Read Extension Private Settings',
      category: 'System Info',
      categoryEn: 'System Info',
    );
    registry.register(
      'saveSetting',
      _saveSetting,
      permission: ExtensionPermission.systemInfo,
      operation: 'Save Extension Private Settings',
      operationEn: 'Save Extension Private Settings',
      category: 'System Info',
      categoryEn: 'System Info',
    );
  }

  Future<dynamic> _getSetting(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final key = params['key'] as String;
    final sandboxId = params['sandboxId'] as String;
    final extensionId = params['extensionId'] as String;

    // 先查虚拟沙箱设置
    final sandbox = _virtualSettings[sandboxId];
    if (sandbox != null && sandbox.containsKey(key)) {
      return sandbox[key];
    }

    // 再查真实 Hive 存储
    final box = await Hive.openBox('ext_$extensionId');
    return box.get(key);
  }

  Future<dynamic> _saveSetting(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final key = params['key'] as String;
    final value = params['value'];
    final sandboxId = params['sandboxId'] as String;
    final extensionId = params['extensionId'] as String;

    // 如果是不信任模式，我们优先存入沙箱
    if (isUntrusted) {
      final sandbox = _virtualSettings[sandboxId] ?? {};
      sandbox[key] = value;
      _virtualSettings[sandboxId] = sandbox;
      return;
    }

    // 正常模式下存入 Hive
    final box = await Hive.openBox('ext_$extensionId');
    await box.put(key, value);
  }
}

/// 提供自动注册的 Provider
final settingsExtensionServiceProvider = Provider((ref) {
  final registry = ref.watch(extensionApiRegistryProvider);
  final handler = SettingsExtensionApiHandler(ref);
  handler.register(registry);
  return handler;
});
