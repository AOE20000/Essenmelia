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
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            metadata.icon,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
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
    final sandboxId = authNotifier.getSandboxId(metadata.id);
    final isShared = sandboxId != metadata.id;

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
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
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
              const Divider(height: 1, indent: 56),
              ListTile(
                onTap: () => _showSandboxConfigDialog(
                  theme,
                  metadata,
                  sandboxId,
                  authNotifier,
                ),
                title: const Text('沙箱隔离组'),
                subtitle: Text(
                  isShared ? '正在使用共用沙箱: $sandboxId' : '默认隔离 (个体沙箱)',
                ),
                leading: Icon(
                  isShared ? Icons.group_work : Icons.phonelink_lock,
                  color: isShared
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                trailing: const Icon(Icons.edit_outlined, size: 20),
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
    final controller = TextEditingController(
      text: currentSandboxId == metadata.id ? '' : currentSandboxId,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('配置沙箱组'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '通过设置相同的沙箱 ID，可以让多个扩展共享同一个“虚拟环境”。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: '沙箱 ID (留空则恢复默认隔离)',
                hintText: '例如: activation_group',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                helperText: '提示：激活类程序通常需要与主扩展处于同一沙箱组',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              authNotifier.setSandboxId(metadata.id, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('保存'),
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
      await ref.read(extensionManagerProvider).removeExtension(metadata.id);
      if (mounted) Navigator.pop(context);
    }
  }
}
