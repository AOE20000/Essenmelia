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
        title: Text(l10n.manageAndPermissions),
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
          'v${metadata.version} • ${metadata.author}',
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
            l10n.localeName == 'zh' ? '运行与安全' : 'Runtime & Security',
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
                title: Text(
                  l10n.localeName == 'zh' ? '启用扩展' : 'Enable Extension',
                ),
                subtitle: Text(
                  isRunning
                      ? (l10n.localeName == 'zh' ? '正在运行' : 'Running')
                      : (l10n.localeName == 'zh' ? '已停止' : 'Stopped'),
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
                title: Text(
                  l10n.localeName == 'zh' ? '受限访问' : 'Restricted Access',
                ),
                subtitle: Text(
                  l10n.localeName == 'zh'
                      ? '开启后每次访问敏感数据需授权'
                      : 'Grant access for sensitive data each time',
                ),
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
                title: Text(
                  l10n.localeName == 'zh' ? '沙箱隔离' : 'Sandbox Isolation',
                ),
                subtitle: Text(
                  isShared
                      ? (l10n.localeName == 'zh'
                            ? '共用沙箱: $sandboxId'
                            : 'Shared Sandbox: $sandboxId')
                      : (l10n.localeName == 'zh' ? '独立沙箱' : 'Isolated Sandbox'),
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
    final isEn = l10n.localeName != 'zh';
    final controller = TextEditingController(
      text: currentSandboxId == metadata.id ? '' : currentSandboxId,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.hub_rounded),
        title: Text(isEn ? 'Sandbox Group' : '配置沙箱组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn
                  ? 'Sandbox groups determine data isolation. Enter the same ID to share storage.'
                  : '沙箱组决定了扩展之间的数据隔离。输入相同的组 ID 以共享存储空间。',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: isEn ? 'Sandbox ID' : '沙箱组 ID',
                hintText: isEn ? 'Default to Extension ID' : '默认为扩展 ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                prefixIcon: const Icon(Icons.tag_rounded),
                helperText: isEn
                    ? 'Tip: Active extensions usually share the same group'
                    : '提示：激活类程序通常需要与主扩展处于同一沙箱组',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEn ? 'Cancel' : '取消'),
          ),
          FilledButton(
            onPressed: () {
              authNotifier.setSandboxId(metadata.id, controller.text.trim());
              Navigator.pop(context);
            },
            child: Text(isEn ? 'Save' : '保存配置'),
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
              '${l10n.localeName == 'zh' ? '权限申请' : 'Requested Permissions'} (${permissions.length})',
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
              child: Text(l10n.localeName == 'zh' ? '查看全部' : 'View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (permissions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                l10n.localeName == 'zh'
                    ? '此扩展未申请任何权限'
                    : 'No permissions requested',
              ),
            ),
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
                    perm.getLabel(context),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    perm.getDescription(context),
                    style: const TextStyle(fontSize: 12),
                  ),
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
                  l10n.localeName == 'zh' ? '所有系统权限' : 'All System Permissions',
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
                          Text(perm.getLabel(context)),
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
                                l10n.localeName == 'zh' ? '已申请' : 'Requested',
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
                          Text(perm.getDescription(context)),
                          if (permApis.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: permApis.map((api) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    api.getOperation(l10n.localeName == 'en') ??
                                        api.methodName,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 9,
                                    ),
                                  ),
                                );
                              }).toList(),
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
    return Column(
      children: [
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
              l10n.localeName == 'zh' ? '打开扩展界面' : 'Open Extension',
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
                label: Text(
                  l10n.localeName == 'zh' ? '导出与转换' : 'Export & Convert',
                ),
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
                label: const Text('卸载'),
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

  void _showExportMenu(ThemeData theme, ExtensionMetadata metadata) {
    final manager = ref.read(extensionManagerProvider);
    final l10n = AppLocalizations.of(context)!;
    final isZh = l10n.localeName == 'zh';

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
                isZh ? '选择导出格式' : 'Choose Export Format',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildExportOption(
                theme,
                icon: Icons.description_outlined,
                title: isZh ? '标准 JSON 包' : 'Standard JSON Package',
                subtitle: isZh
                    ? '单文件，适合分发与分享'
                    : 'Single file, best for sharing',
                onTap: () {
                  Navigator.pop(context);
                  manager.exportExtension(metadata.id);
                },
              ),
              const SizedBox(height: 12),
              _buildExportOption(
                theme,
                icon: Icons.folder_zip_outlined,
                title: isZh ? '扩展 ZIP 包' : 'Extension ZIP Package',
                subtitle: isZh ? '完整仓库包，包含所有资源' : 'Complete repository archive',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
        title: const Text('卸载确认'),
        content: Text('确定要卸载扩展 "${metadata.name}" 吗？此操作将删除其所有关联数据且不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('确认卸载'),
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
