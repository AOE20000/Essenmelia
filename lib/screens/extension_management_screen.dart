import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../extensions/services/extension_repository_service.dart';
import '../extensions/models/repository_extension.dart';
import '../extensions/manager/extension_manager.dart';
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
    // 在 initState 中直接触发状态更新，确保首次 build 就能读取到正确的刷新意图
    _autoRefreshIfNeeded();
  }

  void _autoRefreshIfNeeded() {
    // 使用 read 获取当前状态
    final hasRefreshed = ref.read(hasInitialRefreshedProvider);
    if (!hasRefreshed) {
      // 标记为已刷新，并开启 GitHub 搜索
      // 注意：在 initState 中修改 provider 是允许的，它会影响接下来的首次 build
      Future.microtask(() {
        ref.read(hasInitialRefreshedProvider.notifier).state = true;
        ref.read(includeGitHubSearchProvider.notifier).state = true;
      });
    }
  }

  void _showManualImportDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final manager = ref.read(extensionManagerProvider);
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.manualImportTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.manualImportDescription,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: l10n.manualImportUrlHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['zip'],
                );
                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final bytes = await file.readAsBytes();
                  final success = await manager.importFromZip(bytes);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success != null ? '导入成功' : '导入失败'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.file_present),
              label: const Text('从本地 ZIP 文件导入'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isEmpty) return;

              final success = await manager.importFromUrl(url);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success != null ? '导入成功' : '导入失败')),
                );
              }
            },
            child: Text(l10n.import),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manifestAsync = ref.watch(extensionRepositoryManifestProvider);
    final theme = Theme.of(context);
    final manager = ref.watch(extensionManagerProvider);
    final l10n = AppLocalizations.of(context)!;
    final searchQuery = ref.watch(extensionSearchQueryProvider).toLowerCase();

    // 获取内置扩展信息
    final builtInExtensions = manager.getBuiltInExtensions();
    // 获取已安装扩展的 ID
    final installedIds = manager.extensions.map((e) => e.metadata.id).toSet();

    // 筛选逻辑
    bool matchesSearch(String? name, String? description, String? repo) {
      if (searchQuery.isEmpty) return true;
      return (name?.toLowerCase().contains(searchQuery) ?? false) ||
          (description?.toLowerCase().contains(searchQuery) ?? false) ||
          (repo?.toLowerCase().contains(searchQuery) ?? false);
    }

    // 筛选出已安装的扩展
    final filteredInstalled = manager.extensions
        .where(
          (e) => matchesSearch(
            e.metadata.name,
            e.metadata.description,
            e.metadata.repoFullName,
          ),
        )
        .toList();

    // 筛选出未安装的内置扩展
    final uninstalledBuiltIn = builtInExtensions
        .where((e) => !installedIds.contains(e.id))
        .where((e) => matchesSearch(e.name, e.description, null))
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
                icon: const Icon(Icons.add_link_rounded),
                tooltip: l10n.manualImport,
                onPressed: () => _showManualImportDialog(context, ref),
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

                  final count = await manager.checkForUpdates();

                  if (context.mounted) {
                    scaffold.hideCurrentSnackBar();
                    if (count > 0) {
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text('发现 $count 个可用更新'),
                          action: SnackBarAction(
                            label: '查看',
                            onPressed: () {
                              // 滚动到顶部或不做任何操作，因为列表会自动刷新
                            },
                          ),
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
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  // 同时刷新基础清单和深度 GitHub 发现
                  ref.read(includeGitHubSearchProvider.notifier).state = true;
                  final _ = ref.refresh(extensionRepositoryManifestProvider);
                },
              ),
            ],
          ),

          // 搜索栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SearchBar(
                hintText: '搜索名称、描述或仓库...',
                leading: const Icon(Icons.search),
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
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        ref.read(extensionSearchQueryProvider.notifier).state =
                            '';
                      },
                    ),
                ],
              ),
            ),
          ),

          // 使用 SliverMainAxisGroup 替代 SliverToBoxAdapter + Column 以支持真正的懒加载
          if (filteredInstalled.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                context,
                l10n.extensionSectionInstalled,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildGroupedItem(
                    index: index,
                    total: filteredInstalled.length,
                    theme: theme,
                    child: _buildInstalledItem(
                      context,
                      ref,
                      filteredInstalled[index],
                    ),
                  ),
                  childCount: filteredInstalled.length,
                ),
              ),
            ),
          ],

          // --- 内置扩展 (未安装) ---
          if (uninstalledBuiltIn.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(context, l10n.extensionSectionBuiltIn),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildGroupedItem(
                    index: index,
                    total: uninstalledBuiltIn.length,
                    theme: theme,
                    child: _buildStoreItem(
                      context,
                      ref,
                      uninstalledBuiltIn[index],
                    ),
                  ),
                  childCount: uninstalledBuiltIn.length,
                ),
              ),
            ),
          ],

          // --- 在线商店 (GitHub) ---
          SliverToBoxAdapter(
            child: _buildSectionHeader(context, l10n.extensionSectionOnline),
          ),

          manifestAsync.when(
            data: (extensions) {
              final uninstalledOnline = extensions
                  .where((e) {
                    // 优先通过 repoFullName 匹配，因为 e.id 是 GitHub 仓库 ID
                    final installed = manager.extensions
                        .cast<BaseExtension?>()
                        .firstWhere(
                          (ie) =>
                              ie?.metadata.repoFullName != null &&
                              ie?.metadata.repoFullName == e.repoFullName,
                          orElse: () => null,
                        );

                    // 如果没找到已安装的对应仓库，则显示
                    if (installed == null) return true;

                    // 如果已安装，但版本不同或未知，也显示在“在线商店”中供用户查看/更新
                    return e.version == 'unknown' ||
                        e.version != installed.metadata.version;
                  })
                  .where(
                    (e) => matchesSearch(e.name, e.description, e.repoFullName),
                  )
                  .toList();

              if (uninstalledOnline.isEmpty) {
                return SliverToBoxAdapter(
                  child: _buildEmptyStateWidget(context, theme),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildGroupedItem(
                      index: index,
                      total: uninstalledOnline.length,
                      theme: theme,
                      child: _buildStoreItem(
                        context,
                        ref,
                        uninstalledOnline[index],
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
              child: _buildErrorStateWidget(
                context,
                theme,
                err.toString(),
                ref,
              ),
            ),
          ),

          // 底部留白
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildGroupedItem({
    required Widget child,
    required int index,
    required int total,
    required ThemeData theme,
  }) {
    final isFirst = index == 0;
    final isLast = index == total - 1;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
      ),
      child: Column(
        children: [
          child,
          if (!isLast)
            Divider(
              height: 1,
              indent: 72,
              endIndent: 16,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInstalledItem(
    BuildContext context,
    WidgetRef ref,
    BaseExtension ext,
  ) {
    final theme = Theme.of(context);
    final manager = ref.watch(extensionManagerProvider);
    final newVersion = manager.availableUpdates[ext.metadata.id];
    final hasUpdate = newVersion != null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Hero(
        tag: 'ext_icon_${ext.metadata.id}',
        child: Badge(
          isLabelVisible: hasUpdate,
          label: const Text('NEW'),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ext.metadata.icon, color: theme.colorScheme.primary),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              ext.metadata.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (hasUpdate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                AppLocalizations.of(context)!.updateAvailable(newVersion),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        hasUpdate ? '点击更新到最新版本' : ext.metadata.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: hasUpdate
              ? theme.colorScheme.tertiary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasUpdate)
            IconButton(
              icon: Icon(
                Icons.download_rounded,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => _updateExtension(context, ref, ext),
            ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: theme.colorScheme.error,
            ),
            onPressed: () => _confirmUninstall(context, ref, ext),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ExtensionDetailsScreen(extension: ext),
          ),
        );
      },
    );
  }

  Future<void> _updateExtension(
    BuildContext context,
    WidgetRef ref,
    BaseExtension ext,
  ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ExtensionActionSheet(
        installedExtension: ext,
        actionType: ExtensionActionType.update,
        onActionCompleted: () {
          // Additional logic if needed after update
        },
      ),
    );
  }

  Widget _buildStoreItem(
    BuildContext context,
    WidgetRef ref,
    RepositoryExtension ext,
  ) {
    final theme = Theme.of(context);
    final manager = ref.watch(extensionManagerProvider);
    final l10n = AppLocalizations.of(context)!;

    // 检查是否已安装（通过仓库全名匹配，因为 ext.id 是 GitHub 内部 ID）
    final installed = manager.extensions.cast<BaseExtension?>().firstWhere(
      (ie) =>
          ie?.metadata.repoFullName != null &&
          ie?.metadata.repoFullName == ext.repoFullName,
      orElse: () => null,
    );

    // 如果已安装但版本不同或未知，则视为可更新
    final isUpdate =
        installed != null &&
        ext.version != 'unknown' &&
        ext.version != installed.metadata.version;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
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
      title: Text(
        ext.name,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        isUpdate ? l10n.updateAvailable(ext.version) : ext.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: isUpdate
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton.filledTonal(
        icon: Icon(
          isUpdate ? Icons.system_update_alt_rounded : Icons.download,
          size: 20,
        ),
        tooltip: isUpdate ? l10n.update : l10n.install,
        onPressed: () => _showExtensionDetails(context, ref, ext),
      ),
      onTap: () => _showExtensionDetails(context, ref, ext),
    );
  }

  Future<void> _confirmUninstall(
    BuildContext context,
    WidgetRef ref,
    BaseExtension ext,
  ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ExtensionActionSheet(
        installedExtension: ext,
        actionType: ExtensionActionType.uninstall,
        onActionCompleted: () {
          // Additional logic if needed after uninstall
        },
      ),
    );
  }

  Widget _buildEmptyStateWidget(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.store_mall_directory_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(l10n.noAvailableExtensions, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorStateWidget(
    BuildContext context,
    ThemeData theme,
    String error,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(l10n.failedToLoadStore, style: theme.textTheme.titleMedium),
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
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  void _showExtensionDetails(
    BuildContext context,
    WidgetRef ref,
    RepositoryExtension ext,
  ) {
    final manager = ref.read(extensionManagerProvider);
    final installedExt = manager.getExtension(ext.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ExtensionActionSheet(
        installedExtension: installedExt,
        repositoryExtension: ext,
        actionType: installedExt != null
            ? ExtensionActionType.update
            : ExtensionActionType.install,
      ),
    );
  }
}
