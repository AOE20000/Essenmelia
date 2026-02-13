import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/repository_extension.dart';

class ExtensionRepositoryService {
  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/essenmelia/extensions-store/main/manifest.json';

  /// 尝试使用镜像地址（针对 GitHub 访问受限地区）
  static const String mirrorManifestUrl =
      'https://fastly.jsdelivr.net/gh/essenmelia/extensions-store@main/manifest.json';

  Future<RepositoryManifest> fetchManifest([String? url]) async {
    final targetUrl = url ?? defaultManifestUrl;

    try {
      debugPrint('Fetching repository manifest from: $targetUrl');
      final response = await http
          .get(Uri.parse(targetUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RepositoryManifest.fromJson(data);
      } else {
        // 如果主地址返回错误且是默认地址，尝试镜像
        if (url == null) {
          debugPrint('Status ${response.statusCode}, attempting mirror URL...');
          return fetchManifest(mirrorManifestUrl);
        }
        throw '服务器返回错误: ${response.statusCode}';
      }
    } on SocketException catch (e) {
      debugPrint('Network error: $e');
      // 如果主地址失败且是默认地址，尝试镜像
      if (url == null) {
        debugPrint('Attempting mirror URL...');
        return fetchManifest(mirrorManifestUrl);
      }
      throw '网络连接失败，请检查网络设置或代理';
    } on TimeoutException {
      if (url == null) {
        return fetchManifest(mirrorManifestUrl);
      }
      throw '连接超时，请稍后重试';
    } catch (e) {
      debugPrint('Repository fetch error: $e');
      throw '无法加载仓库: $e';
    }
  }
}

final extensionRepositoryServiceProvider = Provider(
  (ref) => ExtensionRepositoryService(),
);

final repositoryUrlProvider = StateProvider<String?>((ref) => null);

final extensionRepositoryManifestProvider = FutureProvider<RepositoryManifest>((
  ref,
) async {
  final service = ref.read(extensionRepositoryServiceProvider);
  final customUrl = ref.watch(repositoryUrlProvider);
  return service.fetchManifest(customUrl);
});
