import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../extensions/services/extension_repository_service.dart';
import '../extensions/models/repository_extension.dart';
import '../extensions/manager/extension_manager.dart';
import '../extensions/services/extension_lifecycle_service.dart';
import '../extensions/core/base_extension.dart';
import '../widgets/universal_image.dart';
import '../l10n/app_localizations.dart';
import '../widgets/extension_action_sheet.dart';
import 'extension_details_screen.dart';

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
    final manifestAsync = ref.watch(extensionRepositoryManifestProvider);
    final theme = Theme.of(context);
    final manager = ref.watch(extensionManagerProvider);
    final lifecycleService = ref.read(extensionLifecycleServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final searchQuery = ref.watch(extensionSearchQueryProvider).toLowerCase();

    bool matchesSearch(String? name, String? description, String? repo) {
      if (searchQuery.isEmpty) return true;
      return (name?.toLowerCase().contains(searchQuery) ?? false) ||
          (description?.toLowerCase().contains(searchQuery) ?? false) ||
          (repo?.toLowerCase().contains(searchQuery) ?? false);
    }

    final filteredInstalled = manager.extensions
        .where(
          (e) => matchesSearch(
            e.metadata.name,
            e.metadata.description,
            e.metadata.repoFullName,
          ),
        )
        .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(l10n.extensionManagementTitle),
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: theme.colorScheme.surfaceTint,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded),
                tooltip: l10n.manualImport,
                onPressed: () => _showAddExtensionSheet(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.update_rounded),
                tooltip: '检查更新',
                onPressed: () async {
                  final scaffold = ScaffoldMessenger.of(context);
                  scaffold.showSnackBar(
                    const SnackBar(
                      content: Text('正在检查更新...'),
                      duration: Duration(seconds: 1),
                    ),
                  );

                  final count = await lifecycleService.checkForUpdates();

                  if (context.mounted) {
                    scaffold.hideCurrentSnackBar();
                    if (count > 0) {
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text('发现 $count 个可用更新'),
                          action: SnackBarAction(label: '查看', onPressed: () {}),
                        ),
                      );
                    } else {
                      scaffold.showSnackBar(
                        const SnackBar(content: Text('暂无可用更新')),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {
                  ref.read(includeGitHubSearchProvider.notifier).state = true;
                  ref.invalidate(extensionRepositoryManifestProvider);
                },
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SearchBar(
                hintText: '搜索名称、描述或仓库...',
                leading: const Icon(Icons.search_rounded),
                elevation: WidgetStateProperty.all(0),
                backgroundColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHigh,
                ),
                onChanged: (value) {
                  ref.read(extensionSearchQueryProvider.notifier).state = value;
                },
                trailing: [
                  if (searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        ref.read(extensionSearchQueryProvider.notifier).state =
                            '';
                      },
                    ),
                ],
              ),
            ),
          ),

          if (filteredInstalled.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(title: l10n.extensionSectionInstalled),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ExtensionCard(
                    child: _InstalledExtensionItem(
                      extension: filteredInstalled[index],
                    ),
                  ),
                  childCount: filteredInstalled.length,
                ),
              ),
            ),
          ],

          SliverToBoxAdapter(
            child: _SectionHeader(title: l10n.extensionSectionOnline),
          ),

          manifestAsync.when(
            data: (extensions) {
              final uninstalledOnline = extensions
                  .where((e) {
                    final installed = manager.extensions
                        .cast<BaseExtension?>()
                        .firstWhere(
                          (ie) =>
                              ie?.metadata.repoFullName != null &&
                              ie?.metadata.repoFullName == e.repoFullName,
                          orElse: () => null,
                        );

                    if (installed == null) return true;
                    return e.version == 'unknown' ||
                        e.version != installed.metadata.version;
                  })
                  .where(
                    (e) => matchesSearch(e.name, e.description, e.repoFullName),
                  )
                  .toList();

              if (uninstalledOnline.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        '没有找到相关扩展',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ExtensionCard(
                      child: _StoreExtensionItem(
                        extension: uninstalledOnline[index],
                      ),
                    ),
                    childCount: uninstalledOnline.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (err, stack) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '加载失败: $err',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
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
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 12),
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
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  extension.metadata.icon,
                  color: theme.colorScheme.primary,
                  size: 28,
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
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUpdate)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'v$newVersion',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'v${extension.metadata.version}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => ExtensionActionSheet(
                    installedExtension: extension,
                    actionType: hasUpdate
                        ? ExtensionActionType.update
                        : ExtensionActionType
                              .uninstall, // Default action logic can be improved
                  ),
                );
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

    final installed = manager.extensions.cast<BaseExtension?>().firstWhere(
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
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => ExtensionActionSheet(
            repositoryExtension: extension,
            actionType: isUpdate
                ? ExtensionActionType.update
                : ExtensionActionType.install,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: extension.iconUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: UniversalImage(imageUrl: extension.iconUrl!),
                    )
                  : Icon(
                      Icons.extension_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
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
            FilledButton.tonalIcon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => ExtensionActionSheet(
                    repositoryExtension: extension,
                    actionType: isUpdate
                        ? ExtensionActionType.update
                        : ExtensionActionType.install,
                  ),
                );
              },
              icon: Icon(
                isUpdate
                    ? Icons.system_update_alt_rounded
                    : Icons.download_rounded,
                size: 18,
              ),
              label: Text(isUpdate ? l10n.update : l10n.install),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
