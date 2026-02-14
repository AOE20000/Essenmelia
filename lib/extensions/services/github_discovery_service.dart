import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/repository_extension.dart';

class GitHubDiscoveryService {
  static const String searchKeyword = 'essenmelia-extension';
  static const String githubApiBase = 'https://api.github.com';

  /// 搜索包含特定关键字的仓库
  Future<List<RepositoryExtension>> searchExtensions() async {
    try {
      // 搜索包含 topic 或名称中含有 essenmelia-extension 的仓库
      final query = 'essenmelia-extension in:name,description,topics';
      final url = '$githubApiBase/search/repositories?q=$query&sort=updated';
      
      debugPrint('GitHub Search: $url');
      final response = await http.get(Uri.parse(url), headers: {
        'Accept': 'application/vnd.github.v3+json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List items = data['items'] ?? [];
        
        final List<RepositoryExtension> results = [];
        for (var item in items) {
          final fullName = item['full_name'];
          final defaultBranch = item['default_branch'] ?? 'main';
          
          // 构建 README 的 Raw 链接
          final readmeUrl = 'https://raw.githubusercontent.com/$fullName/$defaultBranch/README.md';
          // 构建 ZIP 下载链接
          final downloadUrl = 'https://github.com/$fullName/archive/refs/heads/$defaultBranch.zip';
          
          // 尝试从 README 提取元数据
          final ext = await _fetchAndParseReadme(readmeUrl, fullName, downloadUrl);
          if (ext != null) {
            results.add(ext);
          } else {
            // 如果解析失败，先提供一个占位信息，至少让用户能看到仓库
            results.add(RepositoryExtension(
              id: 'github:${item['id']}',
              name: item['name'].toString().replaceAll('essenmelia-extension-', ''),
              description: item['description'] ?? 'No description provided',
              author: item['owner']['login'],
              version: 'unknown',
              downloadUrl: downloadUrl,
              repoFullName: fullName,
              readmeUrl: readmeUrl,
            ));
          }
        }
        return results;
      } else {
        throw 'GitHub API 错误: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('GitHub Discovery Error: $e');
      rethrow;
    }
  }

  /// 获取并解析 README 中的元数据块
  Future<RepositoryExtension?> _fetchAndParseReadme(String url, String repoFullName, String downloadUrl) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return parseMetadataFromReadme(response.body, repoFullName, downloadUrl);
      }
    } catch (e) {
      debugPrint('Fetch README failed for $repoFullName: $e');
    }
    return null;
  }

  /// 从 README 文本中解析元数据
  /// 支持格式: <!-- ESSENMELIA_METADATA { ... } -->
  RepositoryExtension? parseMetadataFromReadme(String content, String repoFullName, String downloadUrl) {
    try {
      final regExp = RegExp(r'<!--\s*ESSENMELIA_METADATA\s*(\{[\s\S]*?\})\s*-->');
      final match = regExp.firstMatch(content);
      
      if (match != null) {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr);
          return RepositoryExtension(
            id: data['id'] ?? 'github:$repoFullName',
            name: data['name'] ?? repoFullName.split('/').last,
            description: data['description'] ?? '',
            author: data['author'] ?? repoFullName.split('/').first,
            version: data['version'] ?? '1.0.0',
            downloadUrl: downloadUrl,
            iconUrl: data['iconUrl'],
            repoFullName: repoFullName,
            readmeUrl: 'https://raw.githubusercontent.com/$repoFullName/main/README.md',
          );
        }
      }
    } catch (e) {
      debugPrint('Parse README metadata error: $e');
    }
    return null;
  }
}
