import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/repository_extension.dart';
import 'github_discovery_service.dart';

/// 扩展仓库服务，负责获取在线扩展列表
class ExtensionRepositoryService {
  final GitHubDiscoveryService _githubDiscovery = GitHubDiscoveryService();

  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/essenmelia/extensions-store/main/manifest.json';

  /// 尝试使用镜像地址（针对 GitHub 访问受限地区）
  static const String mirrorManifestUrl =
      'https://fastly.jsdelivr.net/gh/essenmelia/extensions-store@main/manifest.json';

  /// 获取所有可用扩展（整合清单文件 + GitHub 全局发现）
  Future<List<RepositoryExtension>> fetchAllAvailable() async {
    final results = await Future.wait([
      fetchManifest().then((m) => m.extensions),
      _githubDiscovery.searchExtensions().catchError((e) {
        debugPrint('GitHub search failed: $e');
        return <RepositoryExtension>[];
      }),
    ]);

    // 合并结果并根据 ID 去重
    final Map<String, RepositoryExtension> merged = {};
    for (var list in results) {
      for (var ext in list) {
        merged[ext.id] = ext;
      }
    }
    return merged.values.toList();
  }

  /// 获取清单文件中的扩展
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

final extensionRepositoryManifestProvider = FutureProvider<List<RepositoryExtension>>((
  ref,
) async {
  final service = ref.read(extensionRepositoryServiceProvider);
  // 如果有自定义 URL，优先从自定义 URL 获取清单
  final customUrl = ref.watch(repositoryUrlProvider);
  if (customUrl != null) {
    final manifest = await service.fetchManifest(customUrl);
    return manifest.extensions;
  }
  // 否则返回所有可用扩展（内置清单 + GitHub 发现）
  return service.fetchAllAvailable();
});
