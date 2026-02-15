import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import '../models/event.dart';
import '../l10n/app_localizations.dart';

/// Extension permission definitions
enum ExtensionPermission {
  readEvents(Icons.event_note_rounded),
  addEvents(Icons.add_task_rounded),
  updateEvents(Icons.edit_calendar_rounded),
  deleteEvents(Icons.delete_sweep_rounded),
  readTags(Icons.tag_rounded),
  manageTags(Icons.label_important_rounded),
  manageDb(Icons.storage_rounded),
  fileSystem(Icons.folder_open_rounded),
  notifications(Icons.notifications_active_rounded),
  readCalendar(Icons.calendar_month_rounded),
  writeCalendar(Icons.edit_calendar_rounded),
  network(Icons.language_rounded),
  systemInfo(Icons.info_outline_rounded),
  navigation(Icons.explore_rounded),
  uiInteraction(Icons.touch_app_rounded);

  final IconData icon;

  const ExtensionPermission(this.icon);

  String getLabel(AppLocalizations l10n) {
    switch (this) {
      case ExtensionPermission.readEvents:
        return l10n.extensionPermissionReadEvents;
      case ExtensionPermission.addEvents:
        return l10n.extensionPermissionAddEvents;
      case ExtensionPermission.updateEvents:
        return l10n.extensionPermissionUpdateEvents;
      case ExtensionPermission.deleteEvents:
        return l10n.extensionPermissionDeleteEvents;
      case ExtensionPermission.readTags:
        return l10n.extensionPermissionReadTags;
      case ExtensionPermission.manageTags:
        return l10n.extensionPermissionManageTags;
      case ExtensionPermission.manageDb:
        return l10n.extensionPermissionManageDb;
      case ExtensionPermission.fileSystem:
        return l10n.extensionPermissionFileSystem;
      case ExtensionPermission.notifications:
        return l10n.extensionPermissionNotifications;
      case ExtensionPermission.readCalendar:
        return l10n.extensionPermissionReadCalendar;
      case ExtensionPermission.writeCalendar:
        return l10n.extensionPermissionWriteCalendar;
      case ExtensionPermission.network:
        return l10n.extensionPermissionNetwork;
      case ExtensionPermission.systemInfo:
        return l10n.extensionPermissionSystemInfo;
      case ExtensionPermission.navigation:
        return l10n.extensionPermissionNavigation;
      case ExtensionPermission.uiInteraction:
        return l10n.extensionPermissionUIInteraction;
    }
  }

  String getDescription(AppLocalizations l10n) {
    switch (this) {
      case ExtensionPermission.readEvents:
        return l10n.extensionPermissionReadEventsDesc;
      case ExtensionPermission.addEvents:
        return l10n.extensionPermissionAddEventsDesc;
      case ExtensionPermission.updateEvents:
        return l10n.extensionPermissionUpdateEventsDesc;
      case ExtensionPermission.deleteEvents:
        return l10n.extensionPermissionDeleteEventsDesc;
      case ExtensionPermission.readTags:
        return l10n.extensionPermissionReadTagsDesc;
      case ExtensionPermission.manageTags:
        return l10n.extensionPermissionManageTagsDesc;
      case ExtensionPermission.manageDb:
        return l10n.extensionPermissionManageDbDesc;
      case ExtensionPermission.fileSystem:
        return l10n.extensionPermissionFileSystemDesc;
      case ExtensionPermission.notifications:
        return l10n.extensionPermissionNotificationsDesc;
      case ExtensionPermission.readCalendar:
        return l10n.extensionPermissionReadCalendarDesc;
      case ExtensionPermission.writeCalendar:
        return l10n.extensionPermissionWriteCalendarDesc;
      case ExtensionPermission.network:
        return l10n.extensionPermissionNetworkDesc;
      case ExtensionPermission.systemInfo:
        return l10n.extensionPermissionSystemInfoDesc;
      case ExtensionPermission.navigation:
        return l10n.extensionPermissionNavigationDesc;
      case ExtensionPermission.uiInteraction:
        return l10n.extensionPermissionUIInteractionDesc;
    }
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
      name: json['name'] ?? 'Untitled Extension',
      description: json['description'] ?? 'No description',
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

  /// Convert YAML content to `Map<String, dynamic>`
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

/// Extension controlled API interface
abstract class ExtensionApi {
  /// Get all events (permission controlled)
  Future<List<Event>> getEvents();

  /// Get all tags
  Future<List<String>> getTags();

  /// Add new tag
  Future<void> addTag(String tag);

  /// Navigate to a specific route in the main app
  void navigateTo(String route);

  /// Show snackbar message
  void showSnackBar(String message);

  /// Show system notification
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
    String? payload,
  });

  /// Show confirmation dialog
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
  });

  /// Export data to file
  Future<bool> exportFile(String content, String fileName);

  /// Select file and read content
  Future<String?> pickFile({List<String>? allowedExtensions});

  /// HTTP GET request
  Future<String?> httpGet(String url, {Map<String, String>? headers});

  /// HTTP POST request
  Future<String?> httpPost(
    String url, {
    Map<String, String>? headers,
    Object? body,
  });

  /// HTTP PUT request
  Future<String?> httpPut(
    String url, {
    Map<String, String>? headers,
    Object? body,
  });

  /// HTTP DELETE request
  Future<String?> httpDelete(String url, {Map<String, String>? headers});

  /// Open URL in system browser
  Future<void> openUrl(String url);

  /// Set homepage search query filter
  void setSearchQuery(String query);

  /// Create new event
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

  /// Delete event
  Future<void> deleteEvent(String id);

  /// Update existing event
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

  /// Add step to event
  Future<void> addStep(String eventId, String description);

  /// Get database size of the current extension (bytes)
  Future<int> getDbSize();

  /// Get current theme mode (light/dark)
  String getThemeMode();

  /// Get current locale (zh/en)
  String getLocale();

  /// Get/Save extension specific settings
  Future<T?> getSetting<T>(String key);
  Future<void> saveSetting<T>(String key, T value);

  /// General API call method (routed by logic engine)
  Future<dynamic> call(String method, Map<String, dynamic> params);

  /// Publish cross-extension event
  void publishEvent(String name, Map<String, dynamic> data);
}

/// Extension base class
abstract class BaseExtension {
  final ExtensionMetadata metadata;

  BaseExtension(this.metadata);

  /// Extension initialization logic
  Future<void> onInit(ExtensionApi api) async {}

  /// Extension disposal logic
  Future<void> onDispose() async {}

  /// Triggered when permission is granted at runtime
  void onPermissionGranted(ExtensionPermission permission) {}

  /// Triggered when a new event is produced (distributed by Manager)
  void onEventAdded(Event event) {}

  /// Callback for receiving cross-extension events
  void onExtensionEvent(String name, Map<String, dynamic> data) {}

  /// Main UI build method for the extension
  Widget build(BuildContext context, ExtensionApi api);
}
