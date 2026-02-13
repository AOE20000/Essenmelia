import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../extension_api_registry.dart';
import '../extension_manager.dart';

/// UI 相关的扩展 API 实现 (SnackBar, Dialog, Navigation, Theme, Locale)
class UIExtensionApiHandler {
  final Ref _ref;

  UIExtensionApiHandler(this._ref);

  void register(ExtensionApiRegistry registry) {
    registry.register('showSnackBar', _showSnackBar);
    registry.register('showConfirmDialog', _showConfirmDialog);
    registry.register('navigateTo', _navigateTo);
    registry.register('getThemeMode', _getThemeMode);
    registry.register('getLocale', _getLocale);
  }

  Future<dynamic> _getThemeMode(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final themeOption = _ref.read(themeProvider);
    final context = navigatorKey.currentContext;

    bool isDark = false;
    if (themeOption == ThemeModeOption.system && context != null) {
      isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    } else {
      isDark = themeOption == ThemeModeOption.dark;
    }

    return isDark ? 'dark' : 'light';
  }

  Future<dynamic> _getLocale(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final locale = _ref.read(localeProvider);
    return locale?.languageCode ?? 'zh';
  }

  Future<dynamic> _showSnackBar(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final message = params['message'] as String;

    // 欺骗增强：如果是受限模式，且消息看起来在试探权限，则拦截
    if (isUntrusted) {
      final lowerMsg = message.toLowerCase();
      if (lowerMsg.contains('permission') || lowerMsg.contains('权限')) {
        return;
      }
    }

    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<dynamic> _showConfirmDialog(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final title = params['title'] as String;
    final message = params['message'] as String;
    final confirmLabel = params['confirmLabel'] ?? '确定';
    final cancelLabel = params['cancelLabel'] ?? '取消';

    if (isUntrusted) {
      // 受限模式下可以返回假的选择，或者直接返回 true 欺骗扩展
      return true;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel as String),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel as String),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<dynamic> _navigateTo(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    // 导航逻辑实现...
    return null;
  }
}

/// 提供自动注册的 Provider
final uiExtensionServiceProvider = Provider((ref) {
  final registry = ref.watch(extensionApiRegistryProvider);
  final handler = UIExtensionApiHandler(ref);
  handler.register(registry);
  return handler;
});
