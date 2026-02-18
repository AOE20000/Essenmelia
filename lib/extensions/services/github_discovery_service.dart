import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/repository_extension.dart';

class GitHubDiscoveryService {
  static const String searchTopic = 'essenmelia-extend';
  static const String githubApiBase = 'https://api.github.com';

  /// 搜索包含特定关键字的仓库
  Future<List<RepositoryExtension>> searchExtensions() async {
    try {
      // 严格判定：仅搜索带有 topic:essenmelia-extend 的仓库
      final query = 'topic:$searchTopic';
      final url =
          '$githubApiBase/search/repositories?q=${Uri.encodeComponent(query)}&sort=updated';

      debugPrint('GitHub Search: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Essenmelia-App',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['items'] ?? [];

        final List<Future<RepositoryExtension?>> futures = [];

        for (var item in items) {
          futures.add(_processRepositoryItem(item));
        }

        final results = await Future.wait(futures);
        return results.whereType<RepositoryExtension>().toList();
      } else {
        throw 'GitHub API 错误: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('GitHub Discovery Error: $e');
      rethrow;
    }
  }

  Future<RepositoryExtension?> _processRepositoryItem(dynamic item) async {
    try {
      // 严格校验：确保返回结果中确实包含指定的 topic
      final List topics = item['topics'] ?? [];
      if (!topics.contains(searchTopic)) {
        return null;
      }

      final fullName = item['full_name'];
      final defaultBranch = item['default_branch'] ?? 'main';
      final downloadUrl =
          'https://github.com/$fullName/archive/refs/heads/$defaultBranch.zip';

      String version = 'unknown';
      String author = item['owner']['login'];

      // 步骤 1: 立即创建基础扩展对象 (基于仓库名称和描述)
      return RepositoryExtension(
        id: 'github:${item['id']}',
        name: item['name'].toString().replaceAll('essenmelia-extension-', ''),
        description: item['description'] ?? 'No description provided',
        author: author,
        version: version,
        downloadUrl: downloadUrl,
        repoFullName: fullName,
        readmeUrl: 'https://github.com/$fullName/blob/$defaultBranch/README.md',
      );
    } catch (e) {
      debugPrint('Error processing item $item: $e');
      return null;
    }
  }
}
