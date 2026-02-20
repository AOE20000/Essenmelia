// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../runtime/api/extension_api_registry.dart';
import '../core/extension_permission.dart';
import '../utils/mock_data_generator.dart';
import 'base_extension_service.dart';

/// System/Basic extension API implementation (Network, File, Share)
class SystemExtensionApiHandler extends BaseExtensionService {
  SystemExtensionApiHandler(super.ref);

  @override
  void register(ExtensionApiRegistry registry) {
    // Network Operations
    _registerNetworkApi(registry);

    // File Operations
    _registerFileApi(registry);

    // System Info
    registerApi(
      registry,
      'getSystemInfo',
      _getSystemInfo,
      permission: ExtensionPermission.systemInfo,
      operation: '获取设备基础信息 (系统版本, SDK 等)',
      operationEn: 'Get System Info (OS, SDK, etc.)',
      category: '系统信息',
      categoryEn: 'System Info',
    );

    registerApi(
      registry,
      'getDbSize',
      _getDbSize,
      permission: ExtensionPermission.manageDb,
      operation: '获取数据库占用大小',
      operationEn: 'Get Database Storage Size',
      category: '数据管理',
      categoryEn: 'Data Management',
    );
  }

  void _registerNetworkApi(ExtensionApiRegistry registry) {
    const methods = ['httpGet', 'httpPost', 'httpPut', 'httpDelete'];
    const operations = ['访问网络资源', '发送网络数据', '更新网络数据', '删除网络资源'];
    const operationsEn = [
      'Access Network Resources',
      'Send Network Data',
      'Update Network Data',
      'Delete Network Resources',
    ];

    for (var i = 0; i < methods.length; i++) {
      registerApi(
        registry,
        methods[i],
        (params, {required isUntrusted}) =>
            _httpRequest(methods[i], params, isUntrusted: isUntrusted),
        permission: ExtensionPermission.network,
        operation: operations[i],
        operationEn: operationsEn[i],
        category: '网络访问',
        categoryEn: 'Network Access',
      );
    }

    registerApi(
      registry,
      'openUrl',
      _openUrl,
      permission: ExtensionPermission.network,
      operation: '在浏览器中打开链接',
      operationEn: 'Open Link in Browser',
      category: '网络访问',
      categoryEn: 'Network Access',
    );
  }

  void _registerFileApi(ExtensionApiRegistry registry) {
    registerApi(
      registry,
      'exportFile',
      _exportFile,
      permission: ExtensionPermission.fileSystem,
      operation: '导出文件并调起系统分享',
      operationEn: 'Export File and Share',
      category: '文件操作',
      categoryEn: 'File Operations',
    );
    registerApi(
      registry,
      'pickFile',
      _pickFile,
      permission: ExtensionPermission.fileSystem,
      operation: '从您的设备选择并读取文件',
      operationEn: 'Select and Read File from Device',
      category: '文件操作',
      categoryEn: 'File Operations',
    );
  }

  // Unified HTTP Request Handler
  Future<dynamic> _httpRequest(
    String method,
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) {
    print('SystemExtension: _httpRequest called for $method');
    return execute(params, (p) async {
      final url = p.get<String>('url');
      print('SystemExtension: Requesting URL: $url');
      final headers = p.getMap<String, String>('headers');
      final body = p.getOptional('body'); // dynamic body

      // Map method name to HTTP verb
      final verb = method.replaceFirst('http', '').toUpperCase();

      if (isUntrusted) {
        print('SystemExtension: Untrusted request, returning mock data');
        final mockData = MockDataGenerator.generateNetworkResponse(url, verb);
        return jsonEncode(mockData);
      }

      http.Response response;
      final uri = Uri.parse(url);
      final timeout = const Duration(seconds: 15);

      print('SystemExtension: Sending $verb request to $uri');
      try {
        switch (verb) {
          case 'GET':
            response = await http.get(uri, headers: headers).timeout(timeout);
            break;
          case 'POST':
            response = await http
                .post(uri, headers: headers, body: body)
                .timeout(timeout);
            break;
          case 'PUT':
            response = await http
                .put(uri, headers: headers, body: body)
                .timeout(timeout);
            break;
          case 'DELETE':
            response = await http
                .delete(uri, headers: headers)
                .timeout(timeout);
            break;
          default:
            throw ArgumentError('Unsupported HTTP method: $verb');
        }
        print('SystemExtension: Response received: ${response.statusCode}');
        return response.body;
      } catch (e, stack) {
        print('SystemExtension: Request Error: $e\n$stack');
        rethrow;
      }
    });
  }

  Future<dynamic> _openUrl(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) {
    return execute(params, (p) async {
      final url = p.get<String>('url');
      if (isUntrusted) return false;
      return await launchUrl(Uri.parse(url));
    });
  }

  Future<dynamic> _exportFile(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) {
    return execute(params, (p) async {
      final content = p.get<String>('content');
      final fileName = p.get<String>('fileName');

      if (isUntrusted) {
        return true;
      }

      try {
        final tempDir = await getTemporaryDirectory();
        final safeFileName = path.basename(fileName);
        final file = File('${tempDir.path}/$safeFileName');
        await file.writeAsString(content);

        final result = await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Exported from Essenmelia',
          subject: fileName,
        );
        return result.status == ShareResultStatus.success;
      } catch (e) {
        return false;
      }
    });
  }

  Future<dynamic> _pickFile(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) {
    return execute(params, (p) async {
      final allowedExtensions = p.getList<String>('allowedExtensions');

      if (isUntrusted) {
        final ext = allowedExtensions?.firstOrNull;
        return MockDataGenerator.generateFileContent(ext);
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
    });
  }

  Future<dynamic> _getSystemInfo(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) {
    // execute wrapper is optional if no params are needed, but good for consistency
    return execute(params, (p) async {
      if (isUntrusted) {
        return MockDataGenerator.generateSystemInfo();
      }
      return {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'locale': Platform.localeName,
        'sdkVersion': '3.38.9-preview',
      };
    });
  }

  Future<dynamic> _getDbSize(
    Map<String, dynamic> params, {
    required bool isUntrusted,
  }) {
    return execute(params, (p) async {
      final extId = p.get<String>('extensionId');
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
    });
  }
}

/// Provider
final systemExtensionServiceProvider = Provider((ref) {
  final registry = ref.watch(extensionApiRegistryProvider);
  final handler = SystemExtensionApiHandler(ref);
  handler.register(registry);
  return handler;
});
