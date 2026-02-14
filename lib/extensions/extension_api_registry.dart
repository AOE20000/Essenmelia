import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_extension.dart'; // 导入 ExtensionPermission

/// 扩展 API 处理程序定义
/// [params] 是调用参数
/// [isUntrusted] 表示当前是否处于“受限访问”或权限被拦截状态，处理程序应据此决定返回真实数据还是欺骗数据
typedef ExtensionApiHandler =
    FutureOr<dynamic> Function(
      Map<String, dynamic> params, {
      required bool isUntrusted,
    });

/// API 元数据，用于权限校验和隐私弹窗
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

  String? getOperation(bool isEn) => isEn ? (operationEn ?? operation) : operation;
  String? getCategory(bool isEn) => isEn ? (categoryEn ?? category) : category;
}

/// 扩展 API 注册表
/// 用于解耦扩展框架与具体功能实现
class ExtensionApiRegistry {
  final Map<String, ExtensionApiHandler> _handlers = {};
  final Map<String, ExtensionApiMetadata> _metadata = {};

  /// 注册一个 API 处理程序及其元数据
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

  /// 获取一个 API 处理程序
  ExtensionApiHandler? getHandler(String methodName) {
    return _handlers[methodName];
  }

  /// 获取 API 的元数据
  ExtensionApiMetadata? getMetadata(String methodName) {
    return _metadata[methodName];
  }

  /// 移除一个 API 处理程序
  void unregister(String methodName) {
    _handlers.remove(methodName);
    _metadata.remove(methodName);
  }

  /// 获取所有已注册的权限及其关联的操作说明
  Map<ExtensionPermission, List<ExtensionApiMetadata>> getRequiredPermissions() {
    final Map<ExtensionPermission, List<ExtensionApiMetadata>> result = {};
    for (var meta in _metadata.values) {
      if (meta.permission != null) {
        result.putIfAbsent(meta.permission!, () => []).add(meta);
      }
    }
    return result;
  }
}

/// 注册表 Provider
final extensionApiRegistryProvider = Provider((ref) => ExtensionApiRegistry());
