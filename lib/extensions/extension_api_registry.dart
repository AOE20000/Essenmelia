import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_extension.dart'; // Import ExtensionPermission

import '../l10n/app_localizations.dart';

/// Extension API handler definition
/// [params] are the call parameters
/// [isUntrusted] indicates whether it is currently in "restricted access" or permission intercepted state,
/// the handler should decide whether to return real data or spoofed data based on this
typedef ExtensionApiHandler =
    FutureOr<dynamic> Function(
      Map<String, dynamic> params, {
      required bool isUntrusted,
    });

/// API metadata for permission validation and privacy dialogs
class ExtensionApiMetadata {
  final String methodName;
  final ExtensionPermission? permission;
  final String? operation;
  final String? operationEn;
  final String? category;
  final String? categoryEn;

  const ExtensionApiMetadata({
    required this.methodName,
    this.permission,
    this.operation,
    this.operationEn,
    this.category,
    this.categoryEn,
  });

  String? getOperation(AppLocalizations l10n) {
    return l10n.localeName == 'en' ? (operationEn ?? operation) : operation;
  }

  String? getCategory(AppLocalizations l10n) {
    // Priority: Try to map standard categories from arb
    switch (category) {
      case 'Data Reading':
      case '数据读取':
        return l10n.extensionCategoryDataReading;
      case 'Data Writing':
      case '数据写入':
        return l10n.extensionCategoryDataWriting;
      case 'File System':
      case '文件系统':
        return l10n.extensionCategoryFileSystem;
      case 'Network':
      case '网络访问':
        return l10n.extensionCategoryNetwork;
      case 'System Info':
      case '系统信息':
        return l10n.extensionCategorySystemInfo;
      case 'Navigation':
      case '界面导航':
        return l10n.extensionCategoryNavigation;
      case 'UI Interaction':
      case '界面交互':
        return l10n.extensionCategoryUIInteraction;
      case 'Notifications':
      case '系统通知':
        return l10n.extensionCategoryNotifications;
      case 'General':
      case '通用':
        return l10n.extensionCategoryGeneral;
      default:
        // If not a standard category, fall back to the bilingual strings from registration
        return l10n.localeName == 'en' ? (categoryEn ?? category) : category;
    }
  }
}

/// Extension API Registry
/// Used to decouple the extension framework from specific functional implementations
class ExtensionApiRegistry {
  final Map<String, ExtensionApiHandler> _handlers = {};
  final Map<String, ExtensionApiMetadata> _metadata = {};

  /// Register an API handler and its metadata
  void register(
    String methodName,
    ExtensionApiHandler handler, {
    ExtensionPermission? permission,
    String? operation,
    String? operationEn,
    String? category,
    String? categoryEn,
  }) {
    _handlers[methodName] = handler;
    _metadata[methodName] = ExtensionApiMetadata(
      methodName: methodName,
      permission: permission,
      operation: operation,
      operationEn: operationEn,
      category: category,
      categoryEn: categoryEn,
    );
  }

  /// Get an API handler
  ExtensionApiHandler? getHandler(String methodName) {
    return _handlers[methodName];
  }

  /// Get metadata of an API
  ExtensionApiMetadata? getMetadata(String methodName) {
    return _metadata[methodName];
  }

  /// Unregister an API handler
  void unregister(String methodName) {
    _handlers.remove(methodName);
    _metadata.remove(methodName);
  }

  /// Get all required permissions and their associated operation descriptions
  Map<ExtensionPermission, List<ExtensionApiMetadata>>
  getRequiredPermissions() {
    final Map<ExtensionPermission, List<ExtensionApiMetadata>> result = {};
    for (var meta in _metadata.values) {
      if (meta.permission != null) {
        result.putIfAbsent(meta.permission!, () => []).add(meta);
      }
    }
    return result;
  }
}

/// Registry Provider
final extensionApiRegistryProvider = Provider((ref) => ExtensionApiRegistry());
