import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../extensions/base_extension.dart';
import '../extensions/extension_manager.dart';
import '../extensions/extension_api_registry.dart';

class ExtensionDetailsScreen extends ConsumerStatefulWidget {
  final BaseExtension extension;

  const ExtensionDetailsScreen({super.key, required this.extension});

  @override
  ConsumerState<ExtensionDetailsScreen> createState() =>
      _ExtensionDetailsScreenState();
}

class _ExtensionDetailsScreenState
    extends ConsumerState<ExtensionDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = widget.extension.metadata;
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(extensionAuthStateProvider);
    final authNotifier = ref.read(extensionAuthStateProvider.notifier);
    final isUntrusted = authNotifier.isUntrusted(metadata.id);
    final isRunning = authNotifier.isRunning(metadata.id);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.extensionDetails),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Header Info Card
            _buildHeaderCard(theme, metadata),
            const SizedBox(height: 24),

            // Main Controls
            _buildControlSection(
              theme,
              metadata,
              isRunning,
              isUntrusted,
              authNotifier,
            ),
            const SizedBox(height: 24),

            // Permissions Section
            _buildPermissionsSection(theme, metadata, authState, authNotifier),
            const SizedBox(height: 32),

            // Action Buttons
            _buildActionButtons(theme, metadata, authNotifier),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme, ExtensionMetadata metadata) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Hero(
            tag: 'ext_icon_${metadata.id}',
            child: Icon(
              metadata.icon,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          metadata.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.versionAuthorLabel(metadata.version, metadata.author),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              Text(
                metadata.description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${metadata.id}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildControlSection(
    ThemeData theme,
    ExtensionMetadata metadata,
    bool isRunning,
    bool isUntrusted,
    ExtensionAuthNotifier authNotifier,
  ) {
    final sandboxId = authNotifier.getSandboxId(metadata.id);
    final isShared = sandboxId != metadata.id;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            l10n.extensionRuntimeSection,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: isRunning,
                onChanged: (val) => authNotifier.setRunning(metadata.id, val),
                title: Text(l10n.extensionEnable),
                subtitle: Text(
                  isRunning ? l10n.extensionRunning : l10n.extensionStopped,
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isRunning ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: isRunning
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
              ),
              const Divider(height: 1, indent: 64),
              SwitchListTile(
                value: isUntrusted,
                onChanged: isRunning
                    ? (val) => authNotifier.setUntrusted(metadata.id, val)
                    : null,
                title: Text(l10n.extensionRestrictedAccess),
                subtitle: Text(l10n.extensionRestrictedAccessDesc),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isUntrusted && isRunning
                        ? theme.colorScheme.error.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isUntrusted
                        ? Icons.security_rounded
                        : Icons.verified_user_rounded,
                    color: isUntrusted && isRunning
                        ? theme.colorScheme.error
                        : (isRunning
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 64),
              ListTile(
                onTap: () => _showSandboxConfigDialog(
                  theme,
                  metadata,
                  sandboxId,
                  authNotifier,
                ),
                title: Text(l10n.extensionSandboxIsolation),
                subtitle: Text(
                  isShared
                      ? l10n.extensionSharedSandbox(sandboxId)
                      : l10n.extensionIsolatedSandbox,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isShared
                        ? theme.colorScheme.secondary.withValues(alpha: 0.1)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isShared ? Icons.hub_rounded : Icons.lock_person_rounded,
                    color: isShared
                        ? theme.colorScheme.secondary
                        : theme.colorScheme.outline,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSandboxConfigDialog(
    ThemeData theme,
    ExtensionMetadata metadata,
    String currentSandboxId,
    ExtensionAuthNotifier authNotifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: currentSandboxId == metadata.id ? '' : currentSandboxId,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.hub_rounded),
        title: Text(l10n.extensionSandboxGroup),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.extensionSandboxDesc,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: l10n.extensionSandboxId,
                hintText: l10n.extensionSandboxDefaultHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                prefixIcon: const Icon(Icons.tag_rounded),
                helperText: l10n.extensionSandboxTip,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              authNotifier.setSandboxId(metadata.id, controller.text.trim());
              Navigator.pop(context);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsSection(
    ThemeData theme,
    ExtensionMetadata metadata,
    Map<String, List<String>> authState,
    ExtensionAuthNotifier authNotifier,
  ) {
    final permissions = metadata.requiredPermissions;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${l10n.extensionRequestedPermissions} (${permissions.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _showAllPermissionsDialog(
                theme,
                metadata,
                authState,
                authNotifier,
              ),
              child: Text(l10n.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (permissions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(l10n.extensionNoPermissions)),
          )
        else
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: permissions.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
              itemBuilder: (context, index) {
                final perm = permissions[index];
                final isGranted =
                    authState[metadata.id]?.contains(perm.name) ?? false;

                return SwitchListTile(
                  value: isGranted,
                  onChanged: (val) =>
                      authNotifier.togglePermission(metadata.id, perm),
                  title: Text(
                    perm.getLabel(l10n),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(perm.getDescription(l10n)),
                  secondary: Icon(
                    isGranted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isGranted
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showAllPermissionsDialog(
    ThemeData theme,
    ExtensionMetadata metadata,
    Map<String, List<String>> authState,
    ExtensionAuthNotifier authNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  l10n.allSystemPermissions,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: ExtensionPermission.values.length,
                  itemBuilder: (context, index) {
                    final perm = ExtensionPermission.values[index];
                    final isGranted =
                        authState[metadata.id]?.contains(perm.name) ?? false;
                    final isRequested = metadata.requiredPermissions.contains(
                      perm,
                    );

                    final registry = ref.read(extensionApiRegistryProvider);
                    final permApis =
                        registry.getRequiredPermissions()[perm] ?? [];

                    return SwitchListTile(
                      value: isGranted,
                      onChanged: (val) =>
                          authNotifier.togglePermission(metadata.id, perm),
                      title: Row(
                        children: [
                          Icon(
                            perm.icon,
                            size: 20,
                            color: isGranted
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 12),
                          Text(perm.getLabel(l10n)),
                          if (isRequested)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                l10n.extensionRequested,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(perm.getDescription(l10n)),
                          if (permApis.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...permApis.map(
                              (api) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    Expanded(
                                      child: Text(
                                        api.getOperation(l10n) ??
                                            api.methodName,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(
    ThemeData theme,
    ExtensionMetadata metadata,
    ExtensionAuthNotifier authNotifier,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final manager = ref.watch(extensionManagerProvider);
    final newVersion = manager.availableUpdates[metadata.id];
    final hasUpdate = newVersion != null;

    return Column(
      children: [
        if (hasUpdate) ...[
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () => _handleUpdate(context, ref, metadata),
              icon: const Icon(Icons.system_update_alt_rounded),
              label: Text(
                l10n.updateAvailable(newVersion),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.tertiary,
                foregroundColor: theme.colorScheme.onTertiary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: () {
              final manager = ref.read(extensionManagerProvider);
              final extension = widget.extension;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) =>
                      extension.build(context, manager.getApiFor(extension)),
                ),
              );
            },
            icon: const Icon(Icons.launch_rounded),
            label: Text(
              l10n.extensionOpen,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showExportMenu(theme, metadata),
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(l10n.extensionExport),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    _confirmUninstall(theme, metadata, authNotifier),
                icon: const Icon(Icons.delete_sweep_rounded),
                label: Text(l10n.extensionUninstall),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleUpdate(
    BuildContext context,
    WidgetRef ref,
    ExtensionMetadata metadata,
  ) async {
    final repoFullName = metadata.repoFullName;
    if (repoFullName == null) return;

    final url = 'https://github.com/$repoFullName/archive/refs/heads/main.zip';
    final manager = ref.read(extensionManagerProvider);
    final result = await manager.importFromUrl(url);
    if (result != null && context.mounted) {
      // 更新成功后，由于 ExtensionDetailsScreen 依赖的 extension 实例已过期（Metadata 已变），
      // 最好关闭当前页面或刷新
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('扩展更新成功')));
    }
  }

  void _showExportMenu(ThemeData theme, ExtensionMetadata metadata) {
    final manager = ref.read(extensionManagerProvider);
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.extensionExport,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildExportOption(
                theme,
                icon: Icons.link_rounded,
                title: l10n.extensionCopyGitHubLink,
                subtitle: l10n.extensionCopyGitHubLinkSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  manager.copyGitHubLink(metadata.id).then((_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制 GitHub 链接')),
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                theme,
                icon: Icons.folder_zip_outlined,
                title: l10n.extensionExportZip,
                subtitle: l10n.extensionExportZipSubtitle,
                onTap: () {
                  Navigator.pop(context);
                  manager.exportExtensionAsZip(metadata.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportOption(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUninstall(
    ThemeData theme,
    ExtensionMetadata metadata,
    ExtensionAuthNotifier authNotifier,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
        title: Text(l10n.extensionUninstallConfirm),
        content: Text(l10n.extensionUninstallMessage(metadata.name)),
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
            child: Text(l10n.extensionUninstall),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(extensionManagerProvider).removeExtension(metadata.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
