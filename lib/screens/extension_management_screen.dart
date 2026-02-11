import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../extensions/base_extension.dart';
import '../extensions/extension_manager.dart';

class ExtensionManagementScreen extends ConsumerStatefulWidget {
  final BaseExtension extension;

  const ExtensionManagementScreen({super.key, required this.extension});

  @override
  ConsumerState<ExtensionManagementScreen> createState() =>
      _ExtensionManagementScreenState();
}

class _ExtensionManagementScreenState
    extends ConsumerState<ExtensionManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = widget.extension.metadata;
    final authState = ref.watch(extensionAuthStateProvider);
    final authNotifier = ref.read(extensionAuthStateProvider.notifier);
    final isUntrusted = authNotifier.isUntrusted(metadata.id);
    final isRunning = authNotifier.isRunning(metadata.id);

    return Scaffold(
      appBar: AppBar(title: const Text('扩展管理'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
            const SizedBox(height: 32),

            // Permissions Section
            _buildPermissionsSection(theme, metadata, authState, authNotifier),
            const SizedBox(height: 40),

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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            metadata.icon,
            size: 64,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          metadata.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ID: ${metadata.id} • v${metadata.version}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            metadata.description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '作者: ${metadata.author}',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '运行状态与安全',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                value: isRunning,
                onChanged: (val) => authNotifier.setRunning(metadata.id, val),
                title: const Text('启用此扩展'),
                subtitle: Text(isRunning ? '扩展正在后台运行' : '扩展已完全停止工作'),
                secondary: Icon(
                  isRunning ? Icons.play_circle : Icons.pause_circle_outline,
                  color: isRunning
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ),
              const Divider(height: 1, indent: 56),
              SwitchListTile(
                value: isUntrusted,
                onChanged: isRunning
                    ? (val) => authNotifier.setUntrusted(metadata.id, val)
                    : null,
                title: const Text('不信任模式 (隐身模式)'),
                subtitle: const Text('开启后，扩展每次访问敏感数据均需手动授权'),
                secondary: Icon(
                  isUntrusted ? Icons.security : Icons.verified_user_outlined,
                  color: isUntrusted && isRunning
                      ? theme.colorScheme.error
                      : (isRunning
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(
    ThemeData theme,
    ExtensionMetadata metadata,
    Map<String, List<String>> authState,
    ExtensionAuthNotifier authNotifier,
  ) {
    final permissions = metadata.requiredPermissions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '权限申请 (${permissions.length})',
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
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (permissions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('此扩展未申请任何权限')),
          )
        else
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: permissions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
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
                    perm.description,
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
      builder: (context) => DraggableScrollableSheet(
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
                '所有系统权限',
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

                  return SwitchListTile(
                    value: isGranted,
                    onChanged: (val) =>
                        authNotifier.togglePermission(metadata.id, perm),
                    title: Row(
                      children: [
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
                              '已申请',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(perm.description),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
    ThemeData theme,
    ExtensionMetadata metadata,
    ExtensionAuthNotifier authNotifier,
  ) {
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
            label: const Text(
              '打开扩展界面',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                onPressed: () => ref
                    .read(extensionManagerProvider)
                    .exportExtension(metadata.id),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('导出 JSON'),
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
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('卸载'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withOpacity(0.5),
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

  void _confirmUninstall(
    ThemeData theme,
    ExtensionMetadata metadata,
    ExtensionAuthNotifier authNotifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认卸载'),
        content: Text('确定要卸载“${metadata.name}”吗？这将清除该扩展的所有配置和数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: const Text('确认卸载'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authNotifier.uninstallExtension(metadata.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
