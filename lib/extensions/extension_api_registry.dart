import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 扩展 API 处理程序定义
/// [params] 是调用参数
/// [isUntrusted] 表示当前是否处于“受限访问”或权限被拦截状态，处理程序应据此决定返回真实数据还是欺骗数据
typedef ExtensionApiHandler = FutureOr<dynamic> Function(
  Map<String, dynamic> params, {
  required bool isUntrusted,
});

/// 扩展 API 注册表
/// 用于解耦扩展框架与具体功能实现
class ExtensionApiRegistry {
  final Map<String, ExtensionApiHandler> _handlers = {};

  /// 注册一个 API 处理程序
  void register(String methodName, ExtensionApiHandler handler) {
    _handlers[methodName] = handler;
  }

  /// 获取一个 API 处理程序
  ExtensionApiHandler? getHandler(String methodName) {
    return _handlers[methodName];
  }

  /// 移除一个 API 处理程序
  void unregister(String methodName) {
    _handlers.remove(methodName);
  }

  /// 是否包含某个方法的处理程序
  bool hasHandler(String methodName) => _handlers.containsKey(methodName);
}

/// 注册表 Provider
final extensionApiRegistryProvider = Provider((ref) => ExtensionApiRegistry());
