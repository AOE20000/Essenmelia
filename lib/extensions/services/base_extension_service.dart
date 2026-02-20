import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../runtime/api/extension_api_registry.dart';
import '../core/extension_permission.dart';
import '../runtime/api/api_helpers.dart';

/// Base class for extension API handlers
abstract class BaseExtensionService {
  final Ref ref;

  BaseExtensionService(this.ref);

  /// Must be implemented by subclasses to register their APIs
  void register(ExtensionApiRegistry registry);

  /// Helper to register an API
  void registerApi(
    ExtensionApiRegistry registry,
    String methodName,
    ExtensionApiHandler handler, {
    ExtensionPermission? permission,
    required String operation,
    String? operationEn,
    required String category,
    String? categoryEn,
  }) {
    registry.register(
      methodName,
      handler,
      permission: permission,
      operation: operation,
      operationEn: operationEn,
      category: category,
      categoryEn: categoryEn,
    );
  }

  /// Wraps API execution with parameter validation and helper methods
  Future<dynamic> execute<T>(
    Map<String, dynamic> params,
    Future<T> Function(ApiParams p) action,
  ) async {
    try {
      final p = ApiParams(params);
      return await action(p);
    } catch (e) {
      // Re-throw or wrap?
      // Re-throwing allows ExtensionApiImpl to catch and log
      rethrow;
    }
  }
}
