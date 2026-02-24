import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/ui_state_provider.dart';
import '../services/update_check_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends ConsumerWidget {
  final bool isSidePanel;
  const AboutScreen({super.key, this.isSidePanel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // App Icon & Name
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 64,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Essenmelia',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '...';
              return Text(
                'Version $version',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              );
            },
          ),
          const SizedBox(height: 48),

          // Action List
          _buildActionCard(theme, [
            _AboutActionItem(
              icon: Icons.system_update_rounded,
              title: '检查应用更新',
              onTap: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('正在检查更新...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                final hasUpdate = await ref
                    .read(updateCheckServiceProvider)
                    .checkForUpdates(manual: true);

                if (!hasUpdate && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('当前已是最新版本')),
                  );
                }
              },
            ),
            _AboutActionItem(
              icon: Icons.code_rounded,
              title: 'GitHub 仓库',
              onTap: () => launchUrl(
                Uri.parse('https://github.com/AOE20000/Essenmelia'),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ]),
          
          const SizedBox(height: 24),
          Text(
            '© 2026 Essenmelia Team',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: isSidePanel ? Colors.transparent : null,
      appBar: AppBar(
        title: const Text('关于'),
        centerTitle: isSidePanel ? false : null,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            isSidePanel ? Icons.arrow_back_ios_new : Icons.arrow_back,
            size: isSidePanel ? 20 : null,
          ),
          onPressed: () {
            if (isSidePanel) {
              ref.read(leftPanelContentProvider.notifier).state =
                  LeftPanelContent.none;
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: content,
    );
  }

  Widget _buildActionCard(ThemeData theme, List<Widget> children) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _AboutActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AboutActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
