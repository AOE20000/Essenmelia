import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import '../core/extension_metadata.dart';

/// Extension conversion utility
/// Handles conversion between ExtensionMetadata and package formats (ZIP)
class ExtensionConverter {
  /// Extract extension content from ZIP bytes (returns JSON string)
  /// Only supports README.md with embedded JSON metadata block
  static String? extractContentFromZip(Uint8List zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Prioritize embedded metadata in README.md
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
            // Only support JSON format as per architecture spec
            Map<String, dynamic> parsedManifest;
            try {
              if (contentStr.trim().startsWith('{')) {
                parsedManifest = jsonDecode(contentStr);
              } else {
                // Legacy YAML support removed
                return null;
              }
              return _resolveSeparateFiles(parsedManifest, archive);
            } catch (e) {
              debugPrint('Failed to parse extension metadata: $e');
              return null;
            }
          }
        }
      } catch (_) {}

      // Legacy manifest.yaml/json support removed
      return null;
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
    // Get directory of README
    String? baseDir;
    try {
      final sourceFile = archive.firstWhere(
        (f) =>
            f.name.endsWith('README.md') &&
            utf8.decode(f.content as List<int>).contains('ESSENMELIA_EXTEND'),
        orElse: () => archive.firstWhere((f) => f.name.endsWith('README.md')),
      );

      final parts = sourceFile.name.split('/');
      if (parts.length > 1) {
        baseDir = '${parts.sublist(0, parts.length - 1).join('/')}/';
      }
    } catch (_) {}

    String getFullPath(String path) {
      if (baseDir == null || path.contains('/')) return path;
      return '$baseDir$path';
    }

    // 1. Resolve View (supports .yaml, .yml)
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
        }
      } catch (_) {}
    } else if (viewVal == null) {
      // Auto-discover view.yaml
      final candidates = ['view.yaml', 'view.yml'];
      for (final name in candidates) {
        try {
          final fullPath = getFullPath(name);
          final viewFile = archive.firstWhere(
            (f) => f.name == fullPath || f.name.endsWith(fullPath),
          );
          final content = utf8.decode(viewFile.content as List<int>);
          manifest['view'] = ExtensionMetadata.yamlToMap(content);
          break;
        } catch (_) {}
      }
    }

    // 2. Resolve Script (supports .js)
    final scriptVal = manifest['script'];
    if (scriptVal == null) {
      // If no script specified, try finding main.js
      final name = 'main.js';
      try {
        final fullPath = getFullPath(name);
        final scriptFile = archive.firstWhere(
          (f) => f.name == fullPath || f.name.endsWith(fullPath),
        );
        manifest['script'] = utf8.decode(scriptFile.content as List<int>);
      } catch (_) {}
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

    // 1. Prepare manifest data
    final manifest = metadata.toJson();

    // If view is complex Map, separate into YAML file
    if (manifest['view'] is Map) {
      final viewYaml = _mapToYaml(manifest['view'] as Map<String, dynamic>);
      final viewBytes = utf8.encode(viewYaml);
      archive.addFile(ArchiveFile('view.yaml', viewBytes.length, viewBytes));
      manifest['view'] = 'view.yaml';
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

    // Generate README.md with metadata block
    final jsonEncoder = const JsonEncoder.withIndent('  ');
    final metadataJson = jsonEncoder.convert(manifest);
    final readmeContent =
        '''
<!-- ESSENMELIA_EXTEND $metadataJson -->

# ${manifest['name'] ?? 'Untitled Extension'}

${manifest['description'] ?? ''}

*Generated by Essenmelia*
''';

    final readmeBytes = utf8.encode(readmeContent);
    archive.addFile(ArchiveFile('README.md', readmeBytes.length, readmeBytes));

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
