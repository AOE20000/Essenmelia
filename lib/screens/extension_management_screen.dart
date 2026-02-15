import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../extensions/services/extension_repository_service.dart';
import '../extensions/models/repository_extension.dart';
import '../extensions/extension_manager.dart';
import '../extensions/base_extension.dart';
import '../widgets/universal_image.dart';
import '../l10n/app_localizations.dart';
import 'extension_details_screen.dart';

class ExtensionManagementScreen extends ConsumerWidget {
  const ExtensionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifestAsync = ref.watch(extensionRepositoryManifestProvider);
    final theme = Theme.of(context);
    final manager = ref.watch(extensionManagerProvider);
    final l10n = AppLocalizations.of(context)!;

    // 获取内置扩展元数据
    final builtInExtensions = manager.getBuiltInExtensions();
    // 获取已安装扩展的 ID
    final installedIds = manager.extensions.map((e) => e.metadata.id).toSet();

    // 筛选出未安装的内置扩展
    final uninstalledBuiltIn = builtInExtensions
        .where((e) => !installedIds.contains(e.id))
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
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    ref.refresh(extensionRepositoryManifestProvider),
              ),
            ],
          ),

          // --- 已安装扩展 ---
          if (installedIds.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.extensionSectionInstalled,
              Icons.check_circle_outline,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ext = manager.extensions[index];
                  return _buildInstalledCard(context, ref, ext)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                      .slideX(begin: 0.1, end: 0);
                }, childCount: manager.extensions.length),
              ),
            ),
          ],

          // --- 内置扩展 (未安装) ---
          if (uninstalledBuiltIn.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              l10n.extensionSectionBuiltIn,
              Icons.extension_rounded,
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ext = uninstalledBuiltIn[index];
                  return _buildExtensionCard(context, ref, ext)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                      .slideX(begin: 0.1, end: 0);
                }, childCount: uninstalledBuiltIn.length),
              ),
            ),
          ],

          // --- 在线扩展 ---
          _buildSectionHeader(
            context,
            l10n.extensionSectionOnline,
            Icons.cloud_queue_rounded,
          ),
          manifestAsync.when(
            data: (extensions) {
              final uninstalledOnline = extensions
                  .where((e) => !installedIds.contains(e.id))
                  .toList();

              return uninstalledOnline.isEmpty
                  ? _buildEmptyState(context, theme)
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final ext = uninstalledOnline[index];
                          return _buildExtensionCard(context, ref, ext)
                              .animate()
                              .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                              .slideX(begin: 0.1, end: 0);
                        }, childCount: uninstalledOnline.length),
                      ),
                    );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => SliverFillRemaining(
              hasScrollBody: false,
              child: _buildErrorState(context, theme, err.toString(), ref),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
            onPressed: () => _showAddOptions(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l10n.addExtension),
          ).animate().scale(
            delay: 400.ms,
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms),
      ),
    );
  }

  void _showAddOptions(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_open_rounded),
              title: Text(l10n.importFromLocalFile),
              subtitle: Text(l10n.selectJsonExtension),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(extensionManagerProvider).importFromFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_rounded),
              title: Text(l10n.downloadAndInstallFromLink),
              subtitle: Text(l10n.extensionLinkSubtitle),
              onTap: () {
                Navigator.pop(context);
                _showUrlImportDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste_rounded),
              title: Text(l10n.installFromClipboard),
              subtitle: Text(l10n.installFromClipboardSubtitle),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(extensionManagerProvider).importFromClipboard();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showUrlImportDialog(BuildContext context, WidgetRef ref) {
    final urlController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downloadAndInstallFromLink),
        content: TextField(
          controller: urlController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.enterUrlOrGithubLink,
            hintText: 'https://...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final url = urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                await ref.read(extensionManagerProvider).importFromUrl(url);
              }
            },
            child: Text(l10n.install),
          ),
        ],
      ),
    );
  }

  Widget _buildInstalledCard(
    BuildContext context,
    WidgetRef ref,
    BaseExtension ext,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Hero(
          tag: 'ext_icon_${ext.metadata.id}',
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ext.metadata.icon, color: theme.colorScheme.primary),
          ),
        ),
        title: Text(
          ext.metadata.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              ext.metadata.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.versionAuthorLabel(
                ext.metadata.version,
                ext.metadata.author,
              ),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.delete_outline_rounded,
            color: theme.colorScheme.error,
          ),
          onPressed: () => _confirmUninstall(context, ref, ext),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ExtensionDetailsScreen(extension: ext),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmUninstall(
    BuildContext context,
    WidgetRef ref,
    BaseExtension ext,
  ) async {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.uninstallExtension),
        content: Text(l10n.uninstallConfirmation(ext.metadata.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(l10n.uninstall),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(extensionManagerProvider).removeExtension(ext.metadata.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.extensionUninstalled(ext.metadata.name))),
        );
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.store_mall_directory_outlined,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noAvailableExtensions,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ThemeData theme,
    String error,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
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
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _showCustomUrlDialog(context, ref),
              icon: const Icon(Icons.link),
              label: Text(l10n.useCustomStoreLink),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomUrlDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.customStore),
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
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                _loadCustomManifest(context, ref, url);
              }
            },
            child: Text(l10n.load),
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
  }

  Widget _buildExtensionCard(
    BuildContext context,
    WidgetRef ref,
    RepositoryExtension ext,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => _showExtensionDetails(context, ref, ext),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      l10n.authorLabel(ext.author),
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
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                              l10n.versionAuthorLabel(ext.version, ext.author),
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
                    l10n.aboutExtension,
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
                  label: Text(l10n.installExtension),
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
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(l10n.installingExtension(ext.name))),
    );

    try {
      final success = await ref
          .read(extensionManagerProvider)
          .importFromUrl(ext.downloadUrl);

      if (success != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.installSuccess(ext.name))),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.installFailed)),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.installError(e.toString()))),
      );
    }
  }
}
