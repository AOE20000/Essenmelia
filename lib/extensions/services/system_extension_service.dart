import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../extension_api_registry.dart';

/// 系统/基础功能相关的扩展 API 实现 (网络、文件、分享)
class SystemExtensionApiHandler {
  SystemExtensionApiHandler(Ref ref);

  void register(ExtensionApiRegistry registry) {
    registry.register('httpGet', _httpGet);
    registry.register('httpPost', _httpPost);
    registry.register('httpPut', _httpPut);
    registry.register('httpDelete', _httpDelete);
    registry.register('openUrl', _openUrl);
    registry.register('exportFile', _exportFile);
    registry.register('pickFile', _pickFile);
    registry.register('getDbSize', _getDbSize);
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

    final response = await http.put(
      Uri.parse(url),
      headers: headers,
      body: body,
    );
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

    final response = await http.delete(Uri.parse(url), headers: headers);
    return response.body;
  }

  Future<dynamic> _openUrl(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) async {
    final url = params['url'] as String;
    if (isUntrusted) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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

    final response = await http.get(Uri.parse(url), headers: headers);
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

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: body,
    );
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
      // 返回模拟文件内容
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
}

/// 提供自动注册的 Provider
final systemExtensionServiceProvider = Provider((ref) {
  final registry = ref.watch(extensionApiRegistryProvider);
  final handler = SystemExtensionApiHandler(ref);
  handler.register(registry);
  return handler;
});
