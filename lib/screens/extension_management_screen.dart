import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../extensions/services/extension_repository_service.dart';
import '../extensions/models/repository_extension.dart';
import '../extensions/manager/extension_manager.dart';
import '../extensions/services/extension_lifecycle_service.dart';
import '../extensions/core/base_extension.dart';
import '../widgets/universal_image.dart';
import '../l10n/app_localizations.dart';
import 'extension_details_screen.dart';

import '../extensions/widgets/installation_confirm_dialog.dart';
import '../extensions/core/extension_metadata.dart';

final extensionSearchQueryProvider = StateProvider<String>((ref) => '');

class ExtensionManagementScreen extends ConsumerStatefulWidget {
  const ExtensionManagementScreen({super.key});

  @override
  ConsumerState<ExtensionManagementScreen> createState() =>
      _ExtensionManagementScreenState();
}

class _ExtensionManagementScreenState
    extends ConsumerState<ExtensionManagementScreen> {
  @override
  void initState() {
    super.initState();
    _autoRefreshIfNeeded();
  }

  void _autoRefreshIfNeeded() {
    final hasRefreshed = ref.read(hasInitialRefreshedProvider);
    if (!hasRefreshed) {
      Future.microtask(() {
        ref.read(hasInitialRefreshedProvider.notifier).state = true;
        ref.read(includeGitHubSearchProvider.notifier).state = true;
      });
    }
  }

  void _showAddExtensionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => const _AddExtensionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final manager = ref.watch(extensionManagerProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(l10n.extensionManagement),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => _showAddExtensionSheet(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.invalidate(extensionRepositoryManifestProvider);
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBar(
                hintText: l10n.searchExtensions,
                leading: const Icon(Icons.search_rounded),
                onChanged: (value) {
                  ref.read(extensionSearchQueryProvider.notifier).state = value;
                },
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
          ),
          if (manager.installedExtensions.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text(
                  l10n.installedExtensions,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ext = manager.installedExtensions.values.elementAt(
                    index,
                  );
                  return _ExtensionCard(
                    child: _InstalledExtensionItem(extension: ext),
                  );
                }, childCount: manager.installedExtensions.length),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  Text(
                    l10n.availableExtensions,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Add filter or other controls here if needed
                ],
              ),
            ),
          ),
          _buildRepositoryList(context, ref),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildRepositoryList(BuildContext context, WidgetRef ref) {
    final manifestAsync = ref.watch(extensionRepositoryManifestProvider);
    final searchQuery = ref.watch(extensionSearchQueryProvider).toLowerCase();

    return manifestAsync.when(
      data: (extensions) {
        final filtered = extensions.where((ext) {
          final matchesSearch =
              ext.name.toLowerCase().contains(searchQuery) ||
              ext.description.toLowerCase().contains(searchQuery);

          // 如果已安装，不显示在商店列表? 或者显示为已安装/更新?
          // 这里我们显示所有，已安装的会有状态标记
          return matchesSearch;
        }).toList();

        if (filtered.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No extensions found',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final ext = filtered[index];
              return _ExtensionCard(child: _StoreExtensionItem(extension: ext));
            }, childCount: filtered.length),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Failed to load extensions: $err',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  final Widget child;

  const _ExtensionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _InstalledExtensionItem extends ConsumerWidget {
  final BaseExtension extension;

  const _InstalledExtensionItem({required this.extension});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final manager = ref.watch(extensionManagerProvider);
    final newVersion = manager.availableUpdates[extension.metadata.id];
    final hasUpdate = newVersion != null;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ExtensionDetailsScreen(extension: extension),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Hero(
              tag: 'ext_icon_${extension.metadata.id}',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  extension.metadata.icon,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          extension.metadata.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUpdate)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'UPDATE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasUpdate
                        ? '新版本 v$newVersion 可用'
                        : extension.metadata.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasUpdate
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: hasUpdate ? l10n.update : l10n.uninstall,
              icon: Icon(
                hasUpdate
                    ? Icons.system_update_alt_rounded
                    : Icons.delete_outline_rounded,
                color: hasUpdate
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
              onPressed: () async {
                final lifecycleService = ref.read(
                  extensionLifecycleServiceProvider,
                );
                final l10n = AppLocalizations.of(context)!;

                if (hasUpdate) {
                  await lifecycleService.installFromUrl(
                    context,
                    'https://github.com/${extension.metadata.repoFullName}/archive/refs/heads/main.zip',
                  );
                } else {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.uninstall),
                      content: Text(
                        l10n.uninstallConfirmation(extension.metadata.name),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          child: Text(l10n.uninstall),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    await lifecycleService.uninstall(extension.metadata.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已卸载 ${extension.metadata.name}'),
                        ),
                      );
                    }
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreExtensionItem extends ConsumerWidget {
  final RepositoryExtension extension;

  const _StoreExtensionItem({required this.extension});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final manager = ref.watch(extensionManagerProvider);
    final l10n = AppLocalizations.of(context)!;

    final installed = manager.installedExtensions.values
        .cast<BaseExtension?>()
        .firstWhere(
          (ie) =>
              ie?.metadata.repoFullName != null &&
              ie?.metadata.repoFullName == extension.repoFullName,
          orElse: () => null,
        );

    final isUpdate =
        installed != null &&
        extension.version != 'unknown' &&
        extension.version != installed.metadata.version;

    return InkWell(
      onTap: () async {
        if (extension.repoFullName == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.extensionInstallError)));
          return;
        }

        // Show loading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        try {
          // Fetch README
          final readme = await ref
              .read(extensionRepositoryServiceProvider)
              .fetchReadme(extension.repoFullName!);

          if (!context.mounted) return;
          Navigator.of(context, rootNavigator: true).pop(); // Close loading

          if (readme == null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.extensionInstallError)));
            return;
          }

          // Parse Metadata
          final metadata = ExtensionMetadata.fromReadme(readme);
          if (metadata == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid extension format')),
            );
            return;
          }

          // Show Confirmation Dialog (Preview Mode)
          await InstallationConfirmDialog.show(
            context,
            newMeta: metadata,
            readme: readme,
            oldMeta: installed?.metadata,
            downloadUrl: extension.downloadUrl,
          );
        } catch (e) {
          if (context.mounted) {
            Navigator.of(
              context,
              rootNavigator: true,
            ).pop(); // Ensure loading closed
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: extension.iconUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: UniversalImage(imageUrl: extension.iconUrl!),
                    )
                  : Icon(
                      Icons.extension_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    extension.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isUpdate
                        ? l10n.updateAvailable(extension.version)
                        : extension.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isUpdate
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () async {
                final lifecycleService = ref.read(
                  extensionLifecycleServiceProvider,
                );
                await lifecycleService.installFromUrl(
                  context,
                  extension.downloadUrl,
                );
              },
              icon: Icon(
                isUpdate
                    ? Icons.system_update_alt_rounded
                    : Icons.download_rounded,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddExtensionSheet extends ConsumerWidget {
  const _AddExtensionSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycleService = ref.read(extensionLifecycleServiceProvider);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('添加扩展', style: theme.textTheme.titleLarge),
        ),
        ListTile(
          leading: const Icon(Icons.paste_rounded),
          title: const Text('从剪贴板导入'),
          subtitle: const Text('支持 GitHub 链接或 JSON 内容'),
          onTap: () async {
            await lifecycleService.installFromClipboard(context);
            if (context.mounted) Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.folder_open_rounded),
          title: const Text('从文件导入'),
          subtitle: const Text('支持 .zip 或 .json 文件'),
          onTap: () async {
            await lifecycleService.installFromFile(context);
            if (context.mounted) Navigator.pop(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.link_rounded),
          title: const Text('从 URL 导入'),
          subtitle: const Text('输入下载链接'),
          onTap: () async {
            final url = await _showUrlInputDialog(context);
            if (url != null && context.mounted) {
              await lifecycleService.installFromUrl(context, url);
              if (context.mounted) Navigator.pop(context);
            }
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<String?> _showUrlInputDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入 URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com/extension.zip',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
                Navigator.pop(context, url);
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }
}

// _ReadmePreviewSheet removed as it is replaced by InstallationConfirmDialog
