import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../providers/ui_state_provider.dart';
import '../services/update_check_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends ConsumerWidget {
  final bool isSidePanel;
  const AboutScreen({super.key, this.isSidePanel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // App Icon & Name
          SizedBox(
            width: 120,
            height: 120,
            child: Center(
              child: SvgPicture.asset(
                'assets/images/app_logo.svg',
                width: 100,
                height: 100,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.appTitle,
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
                l10n.extensionVersion(version),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            l10n.appDescription,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 48),

          // Action List
          _buildActionCard(theme, [
            _AboutActionItem(
              icon: Icons.system_update_rounded,
              title: l10n.checkForUpdates,
              onTap: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.checkingForUpdates),
                    duration: const Duration(seconds: 1),
                  ),
                );

                final hasUpdate = await ref
                    .read(updateCheckServiceProvider)
                    .checkForUpdates(manual: true);

                if (!hasUpdate && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.isLatestVersion)));
                }
              },
            ),
            _AboutActionItem(
              icon: Icons.code_rounded,
              title: l10n.githubRepository,
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
        title: Text(l10n.about),
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
