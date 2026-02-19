/// Installation confirmation dialog
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import '../core/extension_metadata.dart';
import '../core/extension_permission.dart';
import '../runtime/api/extension_api_registry.dart';
import '../services/extension_lifecycle_service.dart';
import '../../l10n/app_localizations.dart';

/// 扩展安装/更新确认对话框
class InstallationConfirmDialog extends ConsumerStatefulWidget {
  final ExtensionMetadata newMeta;
  final String? newContent;
  final ExtensionMetadata? oldMeta;
  final String? oldContent;
  final String? readme;
  final String? downloadUrl;
  final Future<void> Function(
    bool isUntrusted,
    void Function(double, String)? onProgress,
  )?
  onConfirm;

  const InstallationConfirmDialog({
    super.key,
    required this.newMeta,
    this.newContent,
    this.oldMeta,
    this.oldContent,
    this.readme,
    this.downloadUrl,
    this.onConfirm,
  });

  /// 显示对话框的静态方法
  ///
  /// 返回一个 Map，包含用户确认状态 'confirmed' 和是否受限 'isUntrusted'
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required ExtensionMetadata newMeta,
    String? newContent,
    ExtensionMetadata? oldMeta,
    String? oldContent,
    String? readme,
    String? downloadUrl,
    Future<void> Function(
      bool isUntrusted,
      void Function(double, String)? onProgress,
    )?
    onConfirm,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => InstallationConfirmDialog(
        newMeta: newMeta,
        newContent: newContent,
        oldMeta: oldMeta,
        oldContent: oldContent,
        readme: readme,
        downloadUrl: downloadUrl,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  ConsumerState<InstallationConfirmDialog> createState() =>
      _InstallationConfirmDialogState();
}

class _InstallationConfirmDialogState
    extends ConsumerState<InstallationConfirmDialog> {
  bool isUntrusted = false; // 默认不开启受限访问（即信任模式）
  bool _isInstalling = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;

  Future<void> _startInstall() async {
    if (widget.downloadUrl == null && widget.onConfirm == null) {
      Navigator.pop(context, {'confirmed': true, 'isUntrusted': isUntrusted});
      return;
    }

    setState(() {
      _isInstalling = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusMessage = 'Preparing...';
    });

    try {
      if (widget.onConfirm != null) {
        await widget.onConfirm!(isUntrusted, (progress, message) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusMessage = message;
            });
          }
        });
      } else {
        await ref
            .read(extensionLifecycleServiceProvider)
            .installFromUrl(
              context,
              widget.downloadUrl!,
              skipConfirmation: true,
              isUntrusted: isUntrusted,
              onProgress: (progress, message) {
                if (mounted) {
                  setState(() {
                    _progress = progress;
                    _statusMessage = message;
                  });
                }
              },
            );
      }

      if (mounted) {
        Navigator.pop(context, {'confirmed': true, 'isUntrusted': isUntrusted});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstalling = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isUpdate = widget.oldMeta != null; // 判断是否为更新操作

    // 如果有 README，且内容大小比较小（说明可能只是元数据，没有完整 ZIP 内容），
    // 我们可以认为是 "预览模式" (Readme Only)
    // 但这里简单起见，我们总是展示 README 如果有的话。
    // 我们可以用 DefaultTabController 来分 "概览" 和 "详情" (Diff)

    // 计算权限差异
    final newPerms = widget.newMeta.requiredPermissions.toSet();
    final oldPerms = widget.oldMeta?.requiredPermissions.toSet() ?? {};
    final addedPerms = newPerms.difference(oldPerms);
    final removedPerms = oldPerms.difference(newPerms);

    return DraggableScrollableSheet(
      initialChildSize: 0.85, // 稍微加大一点以容纳 README
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // 顶部拖拽条
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUpdate
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isUpdate ? Icons.system_update_alt : Icons.add_box_outlined,
                    color: isUpdate
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSecondaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUpdate ? l10n.extensionUpdate : l10n.extensionInstall,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.readme != null)
                        Text(
                          'Contains README',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 内容区域 (使用 DefaultTabController 如果有 README)
          Expanded(
            child: widget.readme != null
                ? DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        TabBar(
                          labelColor: theme.colorScheme.primary,
                          unselectedLabelColor:
                              theme.colorScheme.onSurfaceVariant,
                          indicatorColor: theme.colorScheme.primary,
                          dividerColor: Colors.transparent, // 去掉下划线
                          tabs: [
                            const Tab(text: 'README'),
                            Tab(text: l10n.extensionPermissions), // 权限 / 详情
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildReadmeView(
                                context,
                                theme,
                                scrollController,
                              ),
                              _buildDetailsList(
                                context,
                                l10n,
                                theme,
                                isUpdate,
                                addedPerms,
                                removedPerms,
                                newPerms,
                                oldPerms,
                                controller: scrollController,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildDetailsList(
                    context,
                    l10n,
                    theme,
                    isUpdate,
                    addedPerms,
                    removedPerms,
                    newPerms,
                    oldPerms,
                    controller: scrollController,
                  ),
          ),

          // 底部操作区域
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _startInstall,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(l10n.retry),
                        ),
                      ),
                    ],
                  ),
                ] else if (_isInstalling) ...[
                  Text(
                    _statusMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _progress,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _startInstall,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: isUpdate
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(isUpdate ? l10n.update : l10n.install),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadmeView(
    BuildContext context,
    ThemeData theme,
    ScrollController controller,
  ) {
    return Markdown(
      controller: controller,
      data: widget.readme ?? '',
      padding: const EdgeInsets.all(24),
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium,
        h1: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        h2: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        h3: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 4),
          ),
        ),
        code: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDetailsList(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    bool isUpdate,
    Set<ExtensionPermission> addedPerms,
    Set<ExtensionPermission> removedPerms,
    Set<ExtensionPermission> newPerms,
    Set<ExtensionPermission> oldPerms, {
    ScrollController? controller,
  }) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // 扩展信息卡片 (图标、名称、ID)
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Hero(
                    tag: 'ext_icon_${widget.newMeta.id}',
                    child: Icon(
                      widget.newMeta.icon,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.newMeta.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.newMeta.id,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 版本与信息对比区域
        Text(
          l10n.extensionInformation,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // 版本对比
        _buildDiffRow(
          context,
          l10n.extensionVersion,
          widget.oldMeta?.version ?? l10n.extensionNotInstalled,
          widget.newMeta.version,
          isHighlight: widget.oldMeta?.version != widget.newMeta.version,
        ),
        // 代码大小对比
        // 如果是从 readme 导入的，且 newContent 较小 (比如 < 5KB)，而没有 zip，
        // 说明我们可能只是在预览元数据。这时候显示大小可能误导。
        // 不过我们这里显示的 newContent.length 是传入的 content 长度。
        // 如果是 installFromUrl (fetch readme first)，newContent 是生成的 JSON。
        // 它的长度很小。
        // 我们可以加一个判断：如果 readme != null 且 newContent.length < 10KB ?
        // 或者我们就不显示 Code Size 除非是 Update？
        // 代码大小对比
        if (widget.newContent != null)
          _buildDiffRow(
            context,
            l10n.extensionCodeSize,
            '${widget.oldContent?.length ?? 0} chars',
            '${widget.newContent!.length} chars',
            isHighlight: widget.oldContent?.length != widget.newContent!.length,
          ),
        // 如果是更新，显示存储占用对比
        if (isUpdate)
          FutureBuilder<int>(
            future: _getExtensionDbSize(widget.newMeta.id),
            builder: (context, snapshot) {
              final size = snapshot.data ?? 0;
              return _buildDiffRow(
                context,
                l10n.extensionStorageSize,
                _formatSize(size),
                _formatSize(size),
              );
            },
          ),
        const SizedBox(height: 24),

        // 安全/信任设置卡片
        Material(
          color: isUntrusted
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.1)
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color:
                  (isUntrusted
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.2),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => isUntrusted = !isUntrusted),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUntrusted
                          ? theme.colorScheme.error.withValues(alpha: 0.1)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUntrusted
                          ? Icons.security_rounded
                          : Icons.verified_user_rounded,
                      color: isUntrusted
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUntrusted
                              ? l10n.extensionRestrictedAccess
                              : l10n.extensionFullTrust,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isUntrusted
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          isUntrusted
                              ? l10n.extensionRestrictedAccessDesc
                              : l10n.extensionFullTrustDesc,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isUntrusted,
                    onChanged: (val) => setState(() => isUntrusted = val),
                    activeThumbColor: theme.colorScheme.error,
                    activeTrackColor: theme.colorScheme.errorContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // 权限声明区域
        Row(
          children: [
            Text(
              l10n.extensionPermissionsStatement,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (isUpdate && addedPerms.isEmpty && removedPerms.isEmpty)
              Text(
                l10n.extensionNoChanges,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (newPerms.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              l10n.extensionNoPermissionsRequired,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                if (!isUpdate)
                  // 安装模式：显示所有需要的权限
                  ...newPerms.map(
                    (p) => _buildPermissionItem(
                      context,
                      p,
                      theme.colorScheme.primary,
                    ),
                  )
                else ...[
                  // 更新模式：显示权限变更（新增、移除、不变）
                  ...addedPerms.map(
                    (p) => _buildPermissionItem(
                      context,
                      p,
                      Colors.green,
                      suffix: ' (+)',
                    ),
                  ),
                  ...removedPerms.map(
                    (p) => _buildPermissionItem(
                      context,
                      p,
                      Colors.red,
                      suffix: ' (-)',
                      isRemoved: true,
                    ),
                  ),
                  ...newPerms
                      .intersection(oldPerms)
                      .map(
                        (p) => _buildPermissionItem(
                          context,
                          p,
                          theme.colorScheme.outline,
                        ),
                      ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// 构建差异对比行
  Widget _buildDiffRow(
    BuildContext context,
    String label,
    String oldVal,
    String newVal, {
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                if (oldVal != newVal) ...[
                  // 如果值不一致，先显示旧值并加删除线
                  Flexible(
                    child: Text(
                      oldVal,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline.withValues(alpha: 0.7),
                        decoration: TextDecoration.lineThrough,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                ],
                // 显示新值
                Flexible(
                  child: Text(
                    newVal,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isHighlight
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isHighlight
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个权限条目
  Widget _buildPermissionItem(
    BuildContext context,
    ExtensionPermission permission,
    Color color, {
    String suffix = '',
    bool isRemoved = false,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final registry = ref.read(extensionApiRegistryProvider);
    // 获取该权限下包含的具体 API 列表
    final permApis = registry.getRequiredPermissions()[permission] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧权限图标
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(permission.icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          // 右侧权限详情
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 权限名称
                Text(
                  '${permission.getLabel(l10n)}$suffix',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    decoration: isRemoved ? TextDecoration.lineThrough : null,
                  ),
                ),
                // 权限描述
                Text(
                  permission.getDescription(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    decoration: isRemoved ? TextDecoration.lineThrough : null,
                  ),
                ),
                // 显示该权限包含的具体 API 列表 (Chips)
                if (permApis.isNotEmpty && !isRemoved) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: permApis.map((api) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          api.getOperation(l10n) ?? api.methodName,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 获取扩展数据库大小
  Future<int> _getExtensionDbSize(String extensionId) async {
    try {
      final boxName = 'ext_$extensionId';
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$boxName.hive');
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      // Ignore
    }
    return 0;
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
