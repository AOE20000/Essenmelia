import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../extensions/core/extension_metadata.dart';
import '../extensions/core/base_extension.dart';
import '../extensions/core/extension_permission.dart';
import '../extensions/models/repository_extension.dart';
import '../extensions/manager/extension_manager.dart';
import '../extensions/services/extension_repository_service.dart';
import '../l10n/app_localizations.dart';
import 'universal_image.dart';

enum ExtensionActionType { install, update, uninstall, details }

class ExtensionActionSheet extends ConsumerWidget {
  final BaseExtension? installedExtension;
  final RepositoryExtension? repositoryExtension;
  final ExtensionActionType actionType;
  final VoidCallback? onActionCompleted;

  const ExtensionActionSheet({
    super.key,
    this.installedExtension,
    this.repositoryExtension,
    required this.actionType,
    this.onActionCompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    final String? repoFullName =
        installedExtension?.metadata.repoFullName ??
        repositoryExtension?.repoFullName;

    // Try to parse metadata from README if available
    ExtensionMetadata? readmeMetadata;
    if (repoFullName != null) {
      final readmeAsync = ref.watch(extensionReadmeProvider(repoFullName));
      if (readmeAsync.hasValue && readmeAsync.value != null) {
        final map = ExtensionManager.parseReadmeMetadata(readmeAsync.value!);
        if (map != null) {
          // Ensure critical fields are present
          if (map['id'] == null && repositoryExtension != null) {
            map['id'] = repositoryExtension!.id;
          }
          if (map['id'] == null && installedExtension != null) {
            map['id'] = installedExtension!.metadata.id;
          }
          try {
            readmeMetadata = ExtensionMetadata.fromJson(map);
          } catch (e) {
            debugPrint('Error parsing metadata from README: $e');
          }
        }
      }
    }

    // Determine metadata source (Prioritize README > Installed > Repository)
    final String name =
        readmeMetadata?.name ??
        installedExtension?.metadata.name ??
        repositoryExtension?.name ??
        'Unknown';
    final String description =
        readmeMetadata?.description ??
        installedExtension?.metadata.description ??
        repositoryExtension?.description ??
        '';
    final String version =
        readmeMetadata?.version ??
        installedExtension?.metadata.version ??
        repositoryExtension?.version ??
        '';
    final String author =
        readmeMetadata?.author ??
        installedExtension?.metadata.author ??
        repositoryExtension?.author ??
        'Unknown';
    final String? iconUrl = repositoryExtension?.iconUrl;
    final IconData? iconData =
        readmeMetadata?.icon ?? installedExtension?.metadata.icon;
    final List<ExtensionPermission> permissions =
        readmeMetadata?.requiredPermissions ??
        installedExtension?.metadata.requiredPermissions ??
        [];
    final List<String> tags =
        readmeMetadata?.tags ??
        installedExtension?.metadata.tags ??
        repositoryExtension?.tags ??
        [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.85,
        minHeight: size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: iconUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: UniversalImage(imageUrl: iconUrl),
                        )
                      : Icon(
                          iconData ?? Icons.extension,
                          size: 32,
                          color: theme.colorScheme.primary,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v$version • $author',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                // Description
                Text(
                  l10n.aboutExtension,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Permissions (Only for installed or if we could fetch them)
                if (permissions.isNotEmpty) ...[
                  Text(
                    l10n.extensionRequestedPermissions, // Ensure this key exists or use fallback
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...permissions.map((p) => _buildPermissionItem(context, p)),
                  const SizedBox(height: 24),
                ],

                // Readme (if available)
                if (repoFullName != null) ...[
                  Text(
                    'README',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildReadme(context, ref, repoFullName),
                  const SizedBox(height: 24),
                ],

                if (tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
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
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),

          // Action Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _handleAction(context, ref),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: actionType == ExtensionActionType.uninstall
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    foregroundColor: actionType == ExtensionActionType.uninstall
                        ? theme.colorScheme.onError
                        : theme.colorScheme.onPrimary,
                  ),
                  icon: Icon(_getActionIcon()),
                  label: Text(_getActionLabel(context)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(
    BuildContext context,
    ExtensionPermission permission,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(permission.icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(permission.getLabel(l10n), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildReadme(
    BuildContext context,
    WidgetRef ref,
    String repoFullName,
  ) {
    final readmeAsync = ref.watch(extensionReadmeProvider(repoFullName));
    final theme = Theme.of(context);

    return readmeAsync.when(
      data: (content) {
        if (content == null || content.isEmpty) {
          return const SizedBox.shrink();
        }

        // Trigger update logic
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(extensionManagerProvider)
              .processReadmeUpdate(content, repoFullName);
        });

        // Clean metadata block
        final cleanReadme = content
            .replaceAll(
              RegExp(r'<!--\s*ESSENMELIA_EXTEND[\s\S]*?-->', multiLine: true),
              '',
            )
            .trim();

        if (cleanReadme.isEmpty) {
          return const SizedBox.shrink();
        }

        return MarkdownBody(
          data: cleanReadme,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  IconData _getActionIcon() {
    switch (actionType) {
      case ExtensionActionType.install:
        return Icons.download_rounded;
      case ExtensionActionType.update:
        return Icons.system_update_alt_rounded;
      case ExtensionActionType.uninstall:
        return Icons.delete_forever_rounded;
      case ExtensionActionType.details:
        return Icons.open_in_new_rounded;
    }
  }

  String _getActionLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (actionType) {
      case ExtensionActionType.install:
        return l10n.install;
      case ExtensionActionType.update:
        return l10n.update; // Ensure l10n has this key or 'Update'
      case ExtensionActionType.uninstall:
        return l10n.uninstall;
      case ExtensionActionType.details:
        return l10n.manageAndPermissions; // Or 'Open'
    }
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref) async {
    final manager = ref.read(extensionManagerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      switch (actionType) {
        case ExtensionActionType.install:
          if (repositoryExtension != null) {
            navigator.pop(); // Close sheet first
            messenger.showSnackBar(
              const SnackBar(content: Text('Starting install...')),
            );
            await manager.importFromUrl(
              repositoryExtension!.downloadUrl,
              skipConfirmation: true,
            );
          }
          break;
        case ExtensionActionType.update:
          if (installedExtension != null &&
              installedExtension!.metadata.repoFullName != null) {
            navigator.pop();
            final url =
                'https://github.com/${installedExtension!.metadata.repoFullName}/archive/refs/heads/main.zip';
            messenger.showSnackBar(
              const SnackBar(content: Text('Starting update...')),
            );
            await manager.importFromUrl(url, skipConfirmation: true);
          } else if (repositoryExtension != null) {
            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Starting update...')),
            );
            await manager.importFromUrl(
              repositoryExtension!.downloadUrl,
              skipConfirmation: true,
            );
          }
          break;
        case ExtensionActionType.uninstall:
          if (installedExtension != null) {
            navigator.pop();
            await manager.removeExtension(installedExtension!.metadata.id);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Uninstalled ${installedExtension!.metadata.name}',
                ),
              ),
            );
          }
          break;
        case ExtensionActionType.details:
          navigator.pop();
          // Maybe navigate to full details screen if needed, or just close
          break;
      }
      onActionCompleted?.call();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }
}
