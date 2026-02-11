import 'package:flutter/material.dart';
import '../models/event.dart';

/// 扩展权限定义
enum ExtensionPermission {
  readEvents('读取事件', 'Read Events', '允许扩展查看您的所有事件和任务。'),
  writeEvents('修改事件', 'Write Events', '允许扩展创建、修改或删除您的任务。'),
  readTags('读取标签', 'Read Tags', '允许扩展查看您的标签列表。'),
  manageDb('数据库管理', 'Manage Database', '允许扩展进行数据库导出、备份或切换。'),
  fileSystem('文件访问', 'File System', '允许扩展保存文件到您的设备或读取文件。'),
  notifications('通知权限', 'Notifications', '允许扩展向您发送桌面或系统通知。');

  final String label;
  final String labelEn;
  final String description;
  const ExtensionPermission(this.label, this.labelEn, this.description);

  String getLabel(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'en' ? labelEn : label;
  }
}

/// 扩展元数据
class ExtensionMetadata {
  final String id;
  final String name;
  final String description;
  final String author;
  final String version;
  final IconData icon;
  final List<ExtensionPermission> requiredPermissions;
  final Map<String, dynamic>? view;
  final Map<String, dynamic>? logic;

  const ExtensionMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.author = 'Unknown',
    this.version = '1.0.0',
    this.requiredPermissions = const [],
    this.view,
    this.logic,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'author': author,
      'version': version,
      'icon_code': icon.codePoint,
      'icon_font': icon.fontFamily,
      'permissions': requiredPermissions.map((e) => e.name).toList(),
      'view': view,
      'logic': logic,
    };
  }

  factory ExtensionMetadata.fromJson(Map<String, dynamic> json) {
    return ExtensionMetadata(
      id: json['id'] ?? 'unknown_id',
      name: json['name'] ?? '未命名扩展',
      description: json['description'] ?? '无描述',
      author: json['author'] ?? 'Unknown',
      version: json['version'] ?? '1.0.0',
      icon: IconData(
        json['icon_code'] ?? 0xe3af, // Default to 'extension' icon
        fontFamily: json['icon_font'] ?? 'MaterialIcons',
      ),
      view: json['view'] as Map<String, dynamic>?,
      logic: json['logic'] as Map<String, dynamic>?,
      requiredPermissions:
          (json['permissions'] as List?)
              ?.map((e) {
                if (e is! String) return null;

                // Try direct match
                try {
                  return ExtensionPermission.values.firstWhere(
                    (p) => p.name == e,
                  );
                } catch (_) {
                  // Try mapping common variations (snake_case to camelCase)
                  final mappedName = _mapPermissionName(e);
                  try {
                    return ExtensionPermission.values.firstWhere(
                      (p) => p.name == mappedName,
                    );
                  } catch (_) {
                    debugPrint('Unknown permission in JSON: $e');
                    return null;
                  }
                }
              })
              .whereType<ExtensionPermission>()
              .toList() ??
          [],
    );
  }

  static String _mapPermissionName(String name) {
    // Basic snake_case to camelCase conversion
    // e.g., read_events -> readEvents
    final parts = name.split('_');
    if (parts.length > 1) {
      final camelCase =
          parts[0] +
          parts
              .skip(1)
              .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
              .join();

      // Special manual mappings
      if (camelCase == 'showNotification') return 'notifications';

      return camelCase;
    }

    // Manual fallback for names that don't follow snake_case exactly
    if (name == 'show_notification') return 'notifications';

    return name;
  }
}

/// 扩展受控 API 接口
abstract class ExtensionApi {
  /// 获取所有事件（受权限控制）
  Future<List<Event>> getEvents();

  /// 获取所有标签
  Future<List<String>> getTags();

  /// 导航到主程序的特定路由
  void navigateTo(String route);

  /// 显示通知/提示
  void showSnackBar(String message);

  /// 导出数据到文件
  Future<bool> exportFile(String content, String fileName);

  /// 获取/保存扩展专用设置
  Future<T?> getSetting<T>(String key);
  Future<void> saveSetting<T>(String key, T value);
}

/// 扩展基类
abstract class BaseExtension {
  final ExtensionMetadata metadata;

  BaseExtension(this.metadata);

  /// 扩展初始化逻辑
  Future<void> onInit(ExtensionApi api) async {}

  /// 扩展销毁逻辑
  Future<void> onDispose() async {}

  /// 当权限在运行时被授予时触发（事后授权模式）
  void onPermissionGranted(ExtensionPermission permission) {}

  /// 当新事件产生时触发（由 Manager 控制分发）
  void onEventAdded(Event event) {}

  /// 扩展的主界面构建方法
  Widget build(BuildContext context, ExtensionApi api);
}
