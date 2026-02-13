class RepositoryExtension {
  final String id;
  final String name;
  final String description;
  final String author;
  final String version;
  final String? iconUrl;
  final String downloadUrl;
  final List<String> tags;

  RepositoryExtension({
    required this.id,
    required this.name,
    required this.description,
    required this.author,
    required this.version,
    required this.downloadUrl,
    this.iconUrl,
    this.tags = const [],
  });

  factory RepositoryExtension.fromJson(Map<String, dynamic> json) {
    return RepositoryExtension(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      author: json['author'] ?? 'Unknown',
      version: json['version'] ?? '1.0.0',
      downloadUrl: json['downloadUrl'] ?? json['url'] ?? '',
      iconUrl: json['iconUrl'] ?? json['icon'],
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
    );
  }
}

class RepositoryManifest {
  final String name;
  final List<RepositoryExtension> extensions;

  RepositoryManifest({required this.name, required this.extensions});

  factory RepositoryManifest.fromJson(Map<String, dynamic> json) {
    return RepositoryManifest(
      name: json['name'] ?? 'Extension Repository',
      extensions:
          (json['extensions'] as List?)
              ?.map((e) => RepositoryExtension.fromJson(e))
              .toList() ??
          [],
    );
  }
}
