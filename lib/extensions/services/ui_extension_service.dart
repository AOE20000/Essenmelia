import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';
import '../../l10n/l10n_provider.dart';
import '../extension_api_registry.dart';
import '../extension_manager.dart';
import '../core/extension_permission.dart';

/// UI 相关的扩展 API 实现 (SnackBar, Dialog, Navigation, Theme, Locale)
class UIExtensionApiHandler {
  final Ref _ref;

  UIExtensionApiHandler(this._ref);

  void register(ExtensionApiRegistry registry) {
    registry.register(
      'showSnackBar',
      _showSnackBar,
      permission: ExtensionPermission.uiInteraction,
      operation: '显示底部提示条',
      operationEn: 'Show Bottom SnackBar',
      category: '界面交互',
      categoryEn: 'UI Interaction',
    );
    registry.register(
      'showNotification',
      _showNotification,
      permission: ExtensionPermission.notifications,
      operation: '发送系统通知',
      operationEn: 'Send System Notification',
      category: '系统通知',
      categoryEn: 'System Notification',
    );
    registry.register(
      'showConfirmDialog',
      _showConfirmDialog,
      permission: ExtensionPermission.uiInteraction,
      operation: '弹出确认对话框',
      operationEn: 'Show Confirmation Dialog',
      category: '界面交互',
      categoryEn: 'UI Interaction',
    );
    registry.register(
      'navigateTo',
      _navigateTo,
      permission: ExtensionPermission.navigation,
      operation: '将页面跳转至指定路由',
      operationEn: 'Navigate to Specific Route',
      category: '界面导航',
      categoryEn: 'Navigation',
    );
    registry.register(
      'getThemeMode',
      _getThemeMode,
      permission: ExtensionPermission.systemInfo,
      operation: '获取当前主题模式',
      operationEn: 'Get Current Theme Mode',
      category: '系统信息',
      categoryEn: 'System Info',
    );
    registry.register(
      'getLocale',
      _getLocale,
      permission: ExtensionPermission.systemInfo,
      operation: '获取当前语言设置',
      operationEn: 'Get Current Locale',
      category: '系统信息',
      categoryEn: 'System Info',
    );
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

  Future<dynamic> _showNotification(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final title = params['title'] as String;
    final body = params['body'] as String;
    final id = params['id'] as int? ?? title.hashCode;
    final payload = params['payload'] as String?;

    if (isUntrusted) {
      // In untrusted mode, we downgrade notifications to SnackBar, or show a real notification with a [Mock] prefix
      // Here we choose SnackBar to protect users from spam notifications
      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('[Mock Notification] $title: $body')),
        );
      }
      return;
    }

    final l10n = _ref.read(l10nProvider);
    await NotificationService().showNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelName: l10n.systemNotification,
      channelDescription: l10n.systemNotificationChannelDesc,
    );
  }

  Future<dynamic> _showConfirmDialog(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final title = params['title'] as String;
    final message = params['message'] as String;
    final l10n = _ref.read(l10nProvider);
    final confirmLabel = params['confirmLabel'] ?? l10n.confirm;
    final cancelLabel = params['cancelLabel'] ?? l10n.cancel;

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
