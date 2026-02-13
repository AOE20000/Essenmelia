import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../extensions/services/extension_repository_service.dart';
import '../extensions/models/repository_extension.dart';
import '../extensions/extension_manager.dart';
import '../widgets/universal_image.dart';

class ExtensionRepositoryScreen extends ConsumerWidget {
  const ExtensionRepositoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestAsync = ref.watch(extensionRepositoryManifestProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('扩展仓库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(extensionRepositoryManifestProvider),
          ),
        ],
      ),
      body: manifestAsync.when(
        data: (manifest) => manifest.extensions.isEmpty
            ? _buildEmptyState(theme)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: manifest.extensions.length,
                itemBuilder: (context, index) {
                  final ext = manifest.extensions[index];
                  return _buildExtensionCard(context, ref, ext);
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            _buildErrorState(context, theme, err.toString(), ref),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('仓库中暂无可用扩展', style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ThemeData theme,
    String error,
    WidgetRef ref,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('无法加载仓库', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.refresh(extensionRepositoryManifestProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _showCustomUrlDialog(context, ref),
              icon: const Icon(Icons.link),
              label: const Text('使用自定义仓库链接'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomUrlDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义仓库'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Manifest JSON URL',
            hintText: 'https://example.com/manifest.json',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                // 这里我们可以临时改变 provider 的行为，或者直接调用 service
                _loadCustomManifest(context, ref, url);
              }
            },
            child: const Text('加载'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCustomManifest(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    ref.read(repositoryUrlProvider.notifier).state = url;
    // 改变 URL 后，extensionRepositoryManifestProvider 会自动重新加载
  }

  Widget _buildExtensionCard(
    BuildContext context,
    WidgetRef ref,
    RepositoryExtension ext,
  ) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showExtensionDetails(context, ref, ext),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ext.iconUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: UniversalImage(imageUrl: ext.iconUrl!),
                      )
                    : Icon(Icons.extension, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ext.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          'v${ext.version}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '作者: ${ext.author}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ext.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Download button
              IconButton.filledTonal(
                icon: const Icon(Icons.download),
                onPressed: () => _installExtension(context, ref, ext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExtensionDetails(
    BuildContext context,
    WidgetRef ref,
    RepositoryExtension ext,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ext.iconUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: UniversalImage(imageUrl: ext.iconUrl!),
                              )
                            : Icon(
                                Icons.extension,
                                size: 40,
                                color: theme.colorScheme.primary,
                              ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ext.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '版本 ${ext.version} • 作者 ${ext.author}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    '关于此扩展',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ext.description,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (ext.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ext.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _installExtension(context, ref, ext);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('安装扩展'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _installExtension(
    BuildContext context,
    WidgetRef ref,
    RepositoryExtension ext,
  ) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text('正在下载并安装 ${ext.name}...')),
    );

    try {
      final success = await ref
          .read(extensionManagerProvider)
          .importFromUrl(ext.downloadUrl);

      if (success != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('${ext.name} 安装成功')),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('安装失败，请检查链接或网络')),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('安装出错: $e')));
    }
  }
}
