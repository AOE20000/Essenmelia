import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'extension_permission.dart';

/// Extension metadata
class ExtensionMetadata {
  final String id;
  final String name;
  final String description;
  final String author;
  final String version;
  final String? repoFullName;
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
    this.repoFullName,
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
      'repo_full_name': repoFullName,
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
      repoFullName: json['repo_full_name'],
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

                try {
                  return ExtensionPermission.values.firstWhere(
                    (p) => p.name == e,
                  );
                } catch (_) {
                  debugPrint('Unknown permission in JSON: $e');
                  return null;
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

  /// Recursively convert YAML nodes
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

  /// Create metadata from YAML string
  factory ExtensionMetadata.fromYaml(String yamlStr) {
    final map = yamlToMap(yamlStr);
    return ExtensionMetadata.fromJson(map);
  }
}
