import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import '../base_extension.dart';

/// 扩展转换工具类
/// 负责处理 ExtensionMetadata 与物理包格式（ZIP）之间的相互转换
class ExtensionConverter {
  /// 从 ZIP 字节流中解析扩展内容（返回 JSON 字符串）
  /// 支持两种模式：
  /// 1. 根目录下包含 manifest.json
  /// 2. README.md 中包含 <!-- ESSENMELIA_METADATA { ... } --> HTML 注释
  static String? extractContentFromZip(Uint8List zipBytes) {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // 1. 优先查找 manifest.yaml 或 manifest.json
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

      // 2. 如果没有 manifest，尝试查找 README.md 中的内嵌元数据
      if (manifestFile == null) {
        try {
          final readmeFile = archive.firstWhere(
            (f) => f.name.endsWith('README.md'),
          );
          final readmeContent = utf8.decode(readmeFile.content as List<int>);

          // 使用正则提取 <!-- ESSENMELIA_METADATA { ... } -->
          final regExp = RegExp(
            r'<!--\s*ESSENMELIA_METADATA\s*([\s\S]*?)\s*-->',
          );
          final match = regExp.firstMatch(readmeContent);
          if (match != null) {
            final contentStr = match.group(1)?.trim();
            if (contentStr != null) {
              // 自动检测是 JSON 还是 YAML
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
    // 获取 manifest 所在目录
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

    // 1. 解析 View (支持 .json, .yaml, .yml)
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
    }

    // 2. 解析 Logic (支持 .json, .yaml, .yml)
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
    }

    // 3. 解析 Script (支持 .js)
    final scriptVal = manifest['script'];
    if (scriptVal == null) {
      // 如果没有指定 script，尝试查找目录下的 main.js 或 index.js
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

  /// 创建 ZIP 扩展包字节流 (用于导出)
  static Uint8List createZipPackage(ExtensionMetadata metadata) {
    final archive = Archive();

    // 1. 生成元数据 (manifest.yaml)
    final manifest = metadata.toJson();

    // 如果 view/logic 是复杂的 Map，我们将其分离为 YAML 文件
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

    // 处理脚本
    if (manifest['script'] is String &&
        (manifest['script'] as String).isNotEmpty) {
      final scriptContent = manifest['script'] as String;
      final scriptBytes = utf8.encode(scriptContent);
      archive.addFile(ArchiveFile('main.js', scriptBytes.length, scriptBytes));
      manifest['script'] = 'main.js';
    }

    // 移除 null 值和内部字段
    manifest.removeWhere((key, value) => value == null);

    final manifestYaml = _mapToYaml(manifest);
    final manifestBytes = utf8.encode(manifestYaml);
    archive.addFile(
      ArchiveFile('manifest.yaml', manifestBytes.length, manifestBytes),
    );

    final zipEncoder = ZipEncoder();
    return Uint8List.fromList(zipEncoder.encode(archive));
  }

  /// Simple Map to YAML helper method (no external generator library for lightweightness)
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
