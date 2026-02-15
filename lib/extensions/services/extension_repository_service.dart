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

  // 内存缓存，仅在当前 App 会话有效
  static List<RepositoryExtension>? _cachedExtensions;

  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/essenmelia/extensions-store/main/manifest.json';

  /// 尝试使用镜像地址（针对 GitHub 访问受限地区）
  static const String mirrorManifestUrl =
      'https://fastly.jsdelivr.net/gh/essenmelia/extensions-store@main/manifest.json';

  /// 获取所有可用扩展（整合清单文件 + 可选的 GitHub 全局发现）
  Future<List<RepositoryExtension>> fetchAllAvailable(
      {bool includeGitHub = false}) async {
    try {
      final futures = <Future<List<RepositoryExtension>>>[
        fetchManifest().then((m) => m.extensions).catchError((e) {
          debugPrint('Manifest fetch failed: $e');
          return <RepositoryExtension>[];
        }),
      ];

      if (includeGitHub) {
        futures.add(_githubDiscovery.searchExtensions().catchError((e) {
          debugPrint('GitHub search failed: $e');
          return <RepositoryExtension>[];
        }));
      }

      final results = await Future.wait(futures);

      // 合并结果并根据 ID 去重
      final Map<String, RepositoryExtension> merged = {};
      for (var list in results) {
        for (var ext in list) {
          merged[ext.id] = ext;
        }
      }
      final list = merged.values.toList();

      // 如果抓取到了数据，更新缓存
      if (list.isNotEmpty) {
        _cachedExtensions = list;
      }
      return list;
    } catch (e) {
      // 如果抓取失败且有缓存，返回缓存
      if (_cachedExtensions != null) {
        debugPrint('Fetch failed, returning cached extensions: $e');
        return _cachedExtensions!;
      }
      rethrow;
    }
  }

  /// 获取当前缓存的扩展列表
  List<RepositoryExtension>? getCachedExtensions() => _cachedExtensions;

  /// 获取远程 README 内容
  Future<String?> fetchReadme(String repoFullName) async {
    try {
      final url = 'https://api.github.com/repos/$repoFullName/readme';
      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'application/vnd.github.raw',
              'User-Agent': 'Essenmelia-App',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      debugPrint('Fetch readme error: $e');
    }
    return null;
  }

  /// 获取清单文件中的扩展
  Future<RepositoryManifest> fetchManifest([String? url]) async {
    final targetUrl = url ?? defaultManifestUrl;

    try {
      debugPrint('Fetching repository manifest from: $targetUrl');
      final response = await http
          .get(
            Uri.parse(targetUrl),
            headers: {
              'User-Agent': 'Essenmelia-App',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RepositoryManifest.fromJson(data);
      } else if (response.statusCode == 404) {
        // 404 说明清单文件尚未创建，属于正常情况，返回空清单
        return RepositoryManifest(name: 'Empty Repository', extensions: []);
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

/// 是否包含 GitHub 搜索（手动触发）
final includeGitHubSearchProvider = StateProvider<bool>((ref) => false);

/// 是否已经进行过初次自动刷新
final hasInitialRefreshedProvider = StateProvider<bool>((ref) => false);

final extensionRepositoryManifestProvider =
    FutureProvider<List<RepositoryExtension>>((ref) async {
  final service = ref.read(extensionRepositoryServiceProvider);
  // 如果有自定义 URL，优先从自定义 URL 获取清单
  final customUrl = ref.watch(repositoryUrlProvider);
  if (customUrl != null) {
    final manifest = await service.fetchManifest(customUrl);
    return manifest.extensions;
  }

  final includeGitHub = ref.watch(includeGitHubSearchProvider);
  final hasInitialRefreshed = ref.watch(hasInitialRefreshedProvider);

  // 1. 如果有缓存且还没进行过初次刷新，优先返回缓存以提高响应速度
  if (!hasInitialRefreshed) {
    final cached = service.getCachedExtensions();
    if (cached != null) {
      return cached;
    }
  }

  // 2. 执行真正的获取逻辑
  // 注意：fetchAllAvailable 内部也有失败回退到缓存的逻辑
  return service.fetchAllAvailable(includeGitHub: includeGitHub);
});

final extensionReadmeProvider = FutureProvider.family<String?, String>((
  ref,
  repoFullName,
) async {
  final service = ref.read(extensionRepositoryServiceProvider);
  return service.fetchReadme(repoFullName);
});
