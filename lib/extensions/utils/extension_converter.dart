import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import '../core/extension_metadata.dart';

/// Extension conversion utility
/// Handles conversion between ExtensionMetadata and package formats (ZIP)
class ExtensionConverter {
  /// Extract extension content from ZIP bytes (returns JSON string)
  /// Supports two modes:
  /// 1. Root contains manifest.json/yaml
  /// 2. README.md contains <!-- ESSENMELIA_EXTEND { ... } --> HTML comment
  static String? extractContentFromZip(Uint8List zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // 1. Prioritize manifest.yaml or manifest.json
      ArchiveFile? manifestFile;
      bool isYaml = false;

      try {
        manifestFile = archive.firstWhere(
          (f) =>
              f.name.endsWith('manifest.yaml') ||
              f.name.endsWith('manifest.yml'),
        );
        isYaml = true;
      } catch (_) {
        try {
          manifestFile = archive.firstWhere(
            (f) => f.name.endsWith('manifest.json'),
          );
        } catch (_) {}
      }

      Map<String, dynamic> manifest;

      // 2. If no manifest, try to find embedded metadata in README.md
      if (manifestFile == null) {
        try {
          final readmeFile = archive.firstWhere(
            (f) => f.name.endsWith('README.md'),
          );
          final readmeContent = utf8.decode(readmeFile.content as List<int>);

          // Use regex to extract <!-- ESSENMELIA_EXTEND { ... } -->
          final regExp = RegExp(
            r'<!--\s*ESSENMELIA_EXTEND[^\s]*\s*([\s\S]*?)\s*-->',
          );
          final match = regExp.firstMatch(readmeContent);
          if (match != null) {
            final contentStr = match.group(1)?.trim();
            if (contentStr != null) {
              // Auto-detect JSON or YAML
              if (contentStr.startsWith('{')) {
                manifest = jsonDecode(contentStr);
              } else {
                final metadata = ExtensionMetadata.fromYaml(contentStr);
                manifest = metadata.toJson();
              }
              return _resolveSeparateFiles(manifest, archive);
            }
          }
        } catch (_) {}
        return null;
      }

      final contentStr = utf8.decode(manifestFile.content as List<int>);
      if (isYaml) {
        manifest = ExtensionMetadata.fromYaml(contentStr).toJson();
      } else {
        manifest = jsonDecode(contentStr);
      }

      return _resolveSeparateFiles(manifest, archive);
    } catch (e) {
      debugPrint('Failed to extract extension from ZIP: $e');
      return null;
    }
  }

  /// Helper method: resolve separate view, logic, and script files
  static String _resolveSeparateFiles(
    Map<String, dynamic> manifest,
    Archive archive,
  ) {
    // Get directory of manifest
    String? baseDir;
    try {
      final manifestFile = archive.firstWhere(
        (f) =>
            f.name.endsWith('manifest.yaml') ||
            f.name.endsWith('manifest.json'),
      );
      final parts = manifestFile.name.split('/');
      if (parts.length > 1) {
        baseDir = '${parts.sublist(0, parts.length - 1).join('/')}/';
      }
    } catch (_) {}

    String getFullPath(String path) {
      if (baseDir == null || path.contains('/')) return path;
      return '$baseDir$path';
    }

    // 1. Resolve View (supports .json, .yaml, .yml)
    final viewVal = manifest['view'];
    if (viewVal is String) {
      final viewPath = getFullPath(viewVal);
      try {
        final viewFile = archive.firstWhere(
          (f) => f.name == viewPath || f.name.endsWith(viewPath),
        );
        final content = utf8.decode(viewFile.content as List<int>);
        if (viewPath.endsWith('.yaml') || viewPath.endsWith('.yml')) {
          manifest['view'] = ExtensionMetadata.yamlToMap(content);
        } else {
          manifest['view'] = jsonDecode(content);
        }
      } catch (_) {}
    } else if (viewVal == null) {
      // Auto-discover view.yaml or view.json
      final candidates = ['view.yaml', 'view.yml', 'view.json'];
      for (final name in candidates) {
        try {
          final fullPath = getFullPath(name);
          final viewFile = archive.firstWhere(
            (f) => f.name == fullPath || f.name.endsWith(fullPath),
          );
          final content = utf8.decode(viewFile.content as List<int>);
          if (name.endsWith('.yaml') || name.endsWith('.yml')) {
            manifest['view'] = ExtensionMetadata.yamlToMap(content);
          } else {
            manifest['view'] = jsonDecode(content);
          }
          break;
        } catch (_) {}
      }
    }

    // 2. Resolve Logic (supports .json, .yaml, .yml)
    final logicVal = manifest['logic'];
    if (logicVal is String) {
      final logicPath = getFullPath(logicVal);
      try {
        final logicFile = archive.firstWhere(
          (f) => f.name == logicPath || f.name.endsWith(logicPath),
        );
        final content = utf8.decode(logicFile.content as List<int>);
        if (logicPath.endsWith('.yaml') || logicPath.endsWith('.yml')) {
          manifest['logic'] = ExtensionMetadata.yamlToMap(content);
        } else {
          manifest['logic'] = jsonDecode(content);
        }
      } catch (_) {}
    } else if (logicVal == null) {
      // Auto-discover logic.yaml or logic.json
      final candidates = ['logic.yaml', 'logic.yml', 'logic.json'];
      for (final name in candidates) {
        try {
          final fullPath = getFullPath(name);
          final logicFile = archive.firstWhere(
            (f) => f.name == fullPath || f.name.endsWith(fullPath),
          );
          final content = utf8.decode(logicFile.content as List<int>);
          if (name.endsWith('.yaml') || name.endsWith('.yml')) {
            manifest['logic'] = ExtensionMetadata.yamlToMap(content);
          } else {
            manifest['logic'] = jsonDecode(content);
          }
          break;
        } catch (_) {}
      }
    }

    // 3. Resolve Script (supports .js)
    final scriptVal = manifest['script'];
    if (scriptVal == null) {
      // If no script specified, try finding main.js or index.js
      final candidates = ['main.js', 'index.js', 'script.js'];
      for (final name in candidates) {
        try {
          final fullPath = getFullPath(name);
          final scriptFile = archive.firstWhere(
            (f) => f.name == fullPath || f.name.endsWith(fullPath),
          );
          manifest['script'] = utf8.decode(scriptFile.content as List<int>);
          break;
        } catch (_) {}
      }
    } else if (scriptVal is String && scriptVal.endsWith('.js')) {
      final scriptPath = getFullPath(scriptVal);
      try {
        final scriptFile = archive.firstWhere(
          (f) => f.name == scriptPath || f.name.endsWith(scriptPath),
        );
        manifest['script'] = utf8.decode(scriptFile.content as List<int>);
      } catch (_) {}
    }

    return jsonEncode(manifest);
  }

  /// Create ZIP package bytes (for export)
  static Uint8List createZipPackage(ExtensionMetadata metadata) {
    final archive = Archive();

    // 1. Generate manifest (manifest.yaml)
    final manifest = metadata.toJson();

    // If view/logic are complex Maps, separate them into YAML files
    if (manifest['view'] is Map) {
      final viewYaml = _mapToYaml(manifest['view'] as Map<String, dynamic>);
      final viewBytes = utf8.encode(viewYaml);
      archive.addFile(ArchiveFile('view.yaml', viewBytes.length, viewBytes));
      manifest['view'] = 'view.yaml';
    }

    if (manifest['logic'] is Map) {
      final logicYaml = _mapToYaml(manifest['logic'] as Map<String, dynamic>);
      final logicBytes = utf8.encode(logicYaml);
      archive.addFile(ArchiveFile('logic.yaml', logicBytes.length, logicBytes));
      manifest['logic'] = 'logic.yaml';
    }

    // Handle script
    if (manifest['script'] is String &&
        (manifest['script'] as String).isNotEmpty) {
      final scriptContent = manifest['script'] as String;
      final scriptBytes = utf8.encode(scriptContent);
      archive.addFile(ArchiveFile('main.js', scriptBytes.length, scriptBytes));
      manifest['script'] = 'main.js';
    }

    // Remove nulls and internal fields
    manifest.removeWhere((key, value) => value == null);

    final manifestYaml = _mapToYaml(manifest);
    final manifestBytes = utf8.encode(manifestYaml);
    archive.addFile(
      ArchiveFile('manifest.yaml', manifestBytes.length, manifestBytes),
    );

    final zipEncoder = ZipEncoder();
    return Uint8List.fromList(zipEncoder.encode(archive));
  }

  /// Simple Map to YAML helper method
  static String _mapToYaml(Map<String, dynamic> map, [int indent = 0]) {
    final sb = StringBuffer();
    final spaces = '  ' * indent;

    map.forEach((key, value) {
      if (value == null) return;

      sb.write(spaces);
      sb.write('$key: ');

      if (value is Map<String, dynamic>) {
        sb.writeln();
        sb.write(_mapToYaml(value, indent + 1));
      } else if (value is List) {
        if (value.isEmpty) {
          sb.writeln('[]');
        } else {
          sb.writeln();
          for (var item in value) {
            sb.write(spaces);
            sb.write('  - ');
            if (item is Map<String, dynamic>) {
              final inner = _mapToYaml(item, indent + 2).trimLeft();
              sb.write(inner);
            } else {
              sb.writeln(_escapeYamlValue(item));
            }
          }
        }
      } else {
        sb.writeln(_escapeYamlValue(value));
      }
    });

    return sb.toString();
  }

  static String _escapeYamlValue(dynamic value) {
    if (value is String) {
      if (value.contains('\n')) {
        final lines = value.split('\n').map((l) => '    $l').join('\n');
        return '|-\n$lines';
      }
      if (value.contains(':') ||
          value.contains('#') ||
          value.contains('[') ||
          value.contains(']')) {
        return '"${value.replaceAll('"', '\\"')}"';
      }
      return value;
    }
    return value.toString();
  }
}
