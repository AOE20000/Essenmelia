import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../extension_api_registry.dart';
import '../base_extension.dart';

/// 系统/基础功能相关的扩展 API 实现 (网络、文件、分享)
class SystemExtensionApiHandler {
  SystemExtensionApiHandler(Ref ref);

  void register(ExtensionApiRegistry registry) {
    registry.register(
      'httpGet',
      _httpGet,
      permission: ExtensionPermission.network,
      operation: '访问网络资源',
      operationEn: 'Access Network Resources',
      category: '网络访问',
      categoryEn: 'Network Access',
    );
    registry.register(
      'httpPost',
      _httpPost,
      permission: ExtensionPermission.network,
      operation: '发送网络数据',
      operationEn: 'Send Network Data',
      category: '网络访问',
      categoryEn: 'Network Access',
    );
    registry.register(
      'httpPut',
      _httpPut,
      permission: ExtensionPermission.network,
      operation: '更新网络数据',
      operationEn: 'Update Network Data',
      category: '网络访问',
      categoryEn: 'Network Access',
    );
    registry.register(
      'httpDelete',
      _httpDelete,
      permission: ExtensionPermission.network,
      operation: '删除网络资源',
      operationEn: 'Delete Network Resources',
      category: '网络访问',
      categoryEn: 'Network Access',
    );
    registry.register(
      'openUrl',
      _openUrl,
      permission: ExtensionPermission.network,
      operation: '在浏览器中打开链接',
      operationEn: 'Open Link in Browser',
      category: '网络访问',
      categoryEn: 'Network Access',
    );
    registry.register(
      'exportFile',
      _exportFile,
      permission: ExtensionPermission.fileSystem,
      operation: '导出文件并调起系统分享',
      operationEn: 'Export File and Share',
      category: '文件操作',
      categoryEn: 'File Operations',
    );
    registry.register(
      'pickFile',
      _pickFile,
      permission: ExtensionPermission.fileSystem,
      operation: '从您的设备选择并读取文件',
      operationEn: 'Select and Read File from Device',
      category: '文件操作',
      categoryEn: 'File Operations',
    );
    registry.register(
      'getSystemInfo',
      _getSystemInfo,
      permission: ExtensionPermission.systemInfo,
      operation: '获取设备基础信息 (系统版本, SDK 等)',
      operationEn: 'Get System Info (OS, SDK, etc.)',
      category: '系统信息',
      categoryEn: 'System Info',
    );
    registry.register(
      'getDbSize',
      _getDbSize,
      permission: ExtensionPermission.manageDb,
      operation: '获取数据库占用大小',
      operationEn: 'Get Database Storage Size',
      category: '数据管理',
      categoryEn: 'Data Management',
    );
  }

  Future<dynamic> _httpPut(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final url = params['url'] as String;
    final body = params['body'];
    final headers = (params['headers'] as Map?)?.cast<String, String>();

    if (isUntrusted) {
      return '{"status": "success", "message": "PUT request simulated"}';
    }

    final response = await http
        .put(Uri.parse(url), headers: headers, body: body)
        .timeout(const Duration(seconds: 15));
    return response.body;
  }

  Future<dynamic> _httpDelete(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final url = params['url'] as String;
    final headers = (params['headers'] as Map?)?.cast<String, String>();

    if (isUntrusted) {
      return '{"status": "success", "message": "DELETE request simulated"}';
    }

    final response = await http
        .delete(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 15));
    return response.body;
  }

  Future<dynamic> _openUrl(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final url = params['url'] as String;
    if (isUntrusted) return false;
    return await launchUrl(Uri.parse(url));
  }

  Future<dynamic> _getDbSize(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final extId = params['extensionId'] as String;
    try {
      final boxName = 'ext_$extId';
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$boxName.hive');
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      // Ignore
    }
    return 0;
  }

  Future<dynamic> _httpGet(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final url = params['url'] as String;
    final headers = (params['headers'] as Map?)?.cast<String, String>();

    if (isUntrusted) {
      // 受限模式下，禁止外网访问，返回模拟响应
      return '{"status": "success", "data": "Mock data from sandbox", "url": "$url"}';
    }

    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 15));
    return response.body;
  }

  Future<dynamic> _httpPost(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final url = params['url'] as String;
    final body = params['body'];
    final headers = (params['headers'] as Map?)?.cast<String, String>();

    if (isUntrusted) {
      return '{"status": "success", "message": "POST request simulated"}';
    }

    final response = await http
        .post(Uri.parse(url), headers: headers, body: body)
        .timeout(const Duration(seconds: 15));
    return response.body;
  }

  Future<dynamic> _exportFile(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final content = params['content'] as String;
    final fileName = params['fileName'] as String;

    if (isUntrusted) {
      // 欺骗：不执行真实导出，直接返回 true
      return true;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        fileNameOverrides: [fileName],
      );
      return result.status == ShareResultStatus.success;
    } catch (e) {
      return false;
    }
  }

  Future<dynamic> _pickFile(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final allowedExtensions = (params['allowedExtensions'] as List?)
        ?.cast<String>();

    if (isUntrusted) {
      // Return mock file content
      return 'id,title,content\n1,Mock Task,Description from sandbox';
    }

    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      return await file.readAsString();
    }
    return null;
  }

  Future<dynamic> _getSystemInfo(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
      'sdkVersion': '3.38.9-preview',
    };
  }
}

/// 提供自动注册的 Provider
final systemExtensionServiceProvider = Provider((ref) {
  final registry = ref.watch(extensionApiRegistryProvider);
  final handler = SystemExtensionApiHandler(ref);
  handler.register(registry);
  return handler;
});
