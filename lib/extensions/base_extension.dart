import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import '../models/event.dart';

/// 扩展权限定义
enum ExtensionPermission {
  readEvents(
    '读取事件',
    'Read Events',
    '允许扩展查看您的所有事件和任务。',
    'Allows the extension to view all your events and tasks.',
    Icons.event_note_rounded,
  ),
  addEvents(
    '创建事件',
    'Add Events',
    '允许扩展创建新的任务。',
    'Allows the extension to create new tasks.',
    Icons.add_task_rounded,
  ),
  updateEvents(
    '编辑事件',
    'Update Events',
    '允许扩展修改现有的任务。',
    'Allows the extension to modify existing tasks.',
    Icons.edit_calendar_rounded,
  ),
  deleteEvents(
    '删除事件',
    'Delete Events',
    '允许扩展删除您的任务。',
    'Allows the extension to delete your tasks.',
    Icons.delete_sweep_rounded,
  ),
  readTags(
    '读取标签',
    'Read Tags',
    '允许扩展查看您的标签列表。',
    'Allows the extension to view your tag list.',
    Icons.tag_rounded,
  ),
  manageTags(
    '管理标签',
    'Manage Tags',
    '允许扩展添加或删除全局标签。',
    'Allows the extension to add or remove global tags.',
    Icons.label_important_rounded,
  ),
  manageDb(
    '数据库管理',
    'Manage Database',
    '允许扩展进行数据库导出、备份或切换。',
    'Allows the extension to perform database export, backup, or switching.',
    Icons.storage_rounded,
  ),
  fileSystem(
    '文件访问',
    'File System',
    '允许扩展保存文件到您的设备或读取文件。',
    'Allows the extension to save files to your device or read files.',
    Icons.folder_open_rounded,
  ),
  notifications(
    '通知权限',
    'Notifications',
    '允许扩展向您发送桌面或系统通知。',
    'Allows the extension to send you desktop or system notifications.',
    Icons.notifications_active_rounded,
  ),
  readCalendar(
    '读取日历',
    'Read Calendar',
    '允许扩展读取您的系统日历日程。',
    'Allows the extension to read your system calendar events.',
    Icons.calendar_month_rounded,
  ),
  writeCalendar(
    '写入日历',
    'Write Calendar',
    '允许扩展向您的系统日历添加或修改日程。',
    'Allows the extension to add or modify events in your system calendar.',
    Icons.edit_calendar_rounded,
  ),
  network(
    '网络访问',
    'Network Access',
    '允许扩展访问网络。',
    'Allows the extension to access the network.',
    Icons.language_rounded,
  ),
  systemInfo(
    '系统信息',
    'System Info',
    '允许扩展访问主题、语言、发送提示条等系统状态。',
    'Allows the extension to access system status like themes, language, and snackbars.',
    Icons.info_outline_rounded,
  ),
  navigation(
    '界面导航',
    'Navigation',
    '允许扩展在应用内进行页面跳转或搜索过滤。',
    'Allows the extension to navigate between pages or filter search results.',
    Icons.explore_rounded,
  ),
  uiInteraction(
    '界面交互',
    'UI Interaction',
    '允许扩展显示提示条、对话框或加载遮罩。',
    'Allows the extension to show snackbars, dialogs, or loading overlays.',
    Icons.touch_app_rounded,
  );

  final String label;
  final String labelEn;
  final String description;
  final String descriptionEn;
  final IconData icon;

  const ExtensionPermission(
    this.label,
    this.labelEn,
    this.description,
    this.descriptionEn, [
    this.icon = Icons.security_rounded,
  ]);

  String getLabel(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'en' ? labelEn : label;
  }

  String getDescription(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'en' ? descriptionEn : description;
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
  final String? script;

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
    this.script,
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
      'script': script,
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
      view: json['view'] is Map ? _convertYamlNode(json['view']) : null,
      logic: json['logic'] is Map ? _convertYamlNode(json['logic']) : null,
      script: json['script'] as String?,
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

  /// 将 YAML 内容转换为 `Map<String, dynamic>`
  static Map<String, dynamic> yamlToMap(String yamlStr) {
    try {
      final doc = loadYaml(yamlStr);
      if (doc == null) return {};
      if (doc is! Map) {
        return {};
      }
      return _convertYamlNode(doc) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error parsing YAML: $e');
      return {};
    }
  }

  /// 递归转换 YAML 节点
  static dynamic _convertYamlNode(dynamic node) {
    if (node is YamlMap) {
      final map = <String, dynamic>{};
      node.forEach((key, value) {
        map[key.toString()] = _convertYamlNode(value);
      });
      return map;
    } else if (node is YamlList) {
      return node.map((item) => _convertYamlNode(item)).toList();
    } else {
      return node;
    }
  }

  /// 从 YAML 字符串创建元数据
  factory ExtensionMetadata.fromYaml(String yamlStr) {
    final map = yamlToMap(yamlStr);
    return ExtensionMetadata.fromJson(map);
  }

  static String _mapPermissionName(String name) {
    // Basic snake_case to camelCase conversion
    // e.g., read_events -> readEvents
    final parts = name.split('_');
    String camelCase = name;
    if (parts.length > 1) {
      camelCase =
          parts[0] +
          parts
              .skip(1)
              .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
              .join();
    }

    // Special manual mappings
    final manualMap = {
      'showNotification': 'notifications',
      'show_notification': 'notifications',
      'write_events': 'addEvents',
      'writeEvents': 'addEvents',
      'editEvents': 'updateEvents',
      'edit_events': 'updateEvents',
      'removeEvents': 'deleteEvents',
      'remove_events': 'deleteEvents',
      'database': 'manageDb',
      'storage': 'fileSystem',
      'calendar': 'readCalendar',
      'calendar_read': 'readCalendar',
      'calendar_write': 'writeCalendar',
      'internet': 'network',
      'theme': 'systemInfo',
      'ui': 'systemInfo',
      'info': 'systemInfo',
      'jump': 'navigation',
      'search': 'navigation',
    };

    return manualMap[camelCase] ?? manualMap[name] ?? camelCase;
  }
}

/// 扩展受控 API 接口
abstract class ExtensionApi {
  /// 获取所有事件（受权限控制）
  Future<List<Event>> getEvents();

  /// 获取所有标签
  Future<List<String>> getTags();

  /// 添加新标签
  Future<void> addTag(String tag);

  /// 导航到主程序的特定路由
  void navigateTo(String route);

  /// 显示通知/提示
  void showSnackBar(String message);

  /// 显示系统通知
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
    String? payload,
  });

  /// 显示确认对话框
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
  });

  /// 导出数据到文件
  Future<bool> exportFile(String content, String fileName);

  /// 选择文件并读取内容
  Future<String?> pickFile({List<String>? allowedExtensions});

  /// 网络 GET 请求
  Future<String?> httpGet(String url, {Map<String, String>? headers});

  /// 网络 POST 请求
  Future<String?> httpPost(
    String url, {
    Map<String, String>? headers,
    Object? body,
  });

  /// 网络 PUT 请求
  Future<String?> httpPut(
    String url, {
    Map<String, String>? headers,
    Object? body,
  });

  /// 网络 DELETE 请求
  Future<String?> httpDelete(String url, {Map<String, String>? headers});

  /// 在系统浏览器中打开 URL
  Future<void> openUrl(String url);

  /// 设置主页搜索过滤
  void setSearchQuery(String query);

  /// 创建新事件
  Future<void> addEvent({
    required String title,
    String? description,
    List<String>? tags,
    String? imageUrl,
    String? stepDisplayMode,
    String? stepSuffix,
    DateTime? reminderTime,
    String? reminderRecurrence,
    String? reminderScheme,
  });

  /// 删除事件
  Future<void> deleteEvent(String id);

  /// 更新现有事件
  Future<void> updateEvent({
    required String id,
    String? title,
    String? description,
    List<String>? tags,
    String? imageUrl,
    String? stepDisplayMode,
    String? stepSuffix,
    DateTime? reminderTime,
    String? reminderRecurrence,
    String? reminderScheme,
  });

  /// 为事件添加步骤
  Future<void> addStep(String eventId, String description);

  /// 获取当前扩展的数据库占用大小 (字节)
  Future<int> getDbSize();

  /// 获取当前主题模式 (light/dark)
  String getThemeMode();

  /// 获取当前语言 (zh/en)
  String getLocale();

  /// 获取/保存扩展专用设置
  Future<T?> getSetting<T>(String key);
  Future<void> saveSetting<T>(String key, T value);

  /// 通用 API 调用方法（供逻辑引擎路由）
  Future<dynamic> call(String method, Map<String, dynamic> params);

  /// 发布跨扩展事件
  void publishEvent(String name, Map<String, dynamic> data);
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

  /// 接收跨扩展事件的回调
  void onExtensionEvent(String name, Map<String, dynamic> data) {}

  /// 扩展的主界面构建方法
  Widget build(BuildContext context, ExtensionApi api);
}
