import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import 'db_manager_screen.dart';
import '../providers/ui_state_provider.dart';

class SettingsSheet extends ConsumerWidget {
  final bool isSidePanel;
  const SettingsSheet({super.key, this.isSidePanel = false});

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

  Widget _buildSettingsGroup(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          return Column(
            children: [
              child,
              if (index < children.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.3,
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final displaySettings = ref.watch(displaySettingsProvider);
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final maxDensity = isSmallScreen ? 2 : 5;

    final slivers = [
      if (!isSidePanel && screenWidth < 1024)
        SliverAppBar.large(
          title: Text(l10n.settings),
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: theme.colorScheme.surfaceTint,
          pinned: true,
        ),
      SliverToBoxAdapter(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(context, l10n.appearance),
                _buildSettingsGroup(context, [
                  // Language
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(l10n.language),
                    trailing: MenuAnchor(
                      builder: (context, controller, child) => TextButton.icon(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        label: Text(
                          locale == null
                              ? l10n.systemLanguage
                              : (locale.languageCode == 'en'
                                    ? l10n.english
                                    : l10n.chinese),
                        ),
                        icon: const Icon(Icons.arrow_drop_down),
                      ),
                      menuChildren: [
                        MenuItemButton(
                          onPressed: () =>
                              ref.read(localeProvider.notifier).setLocale(null),
                          child: Text(l10n.systemLanguage),
                        ),
                        MenuItemButton(
                          onPressed: () => ref
                              .read(localeProvider.notifier)
                              .setLocale(const Locale('en')),
                          child: Text(l10n.english),
                        ),
                        MenuItemButton(
                          onPressed: () => ref
                              .read(localeProvider.notifier)
                              .setLocale(const Locale('zh')),
                          child: Text(l10n.chinese),
                        ),
                      ],
                    ),
                  ),
                  // Theme Mode
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              switch (themeMode) {
                                ThemeModeOption.system => Icons.brightness_auto,
                                ThemeModeOption.light => Icons.light_mode,
                                ThemeModeOption.dark => Icons.dark_mode,
                              },
                              size: 24,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              l10n.darkMode,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeModeOption>(
                            segments: [
                              ButtonSegment(
                                value: ThemeModeOption.system,
                                label: Text(l10n.useSystemTheme),
                                icon: const Icon(Icons.brightness_auto),
                              ),
                              ButtonSegment(
                                value: ThemeModeOption.light,
                                label: Text(l10n.light),
                                icon: const Icon(Icons.light_mode),
                              ),
                              ButtonSegment(
                                value: ThemeModeOption.dark,
                                label: Text(l10n.dark),
                                icon: const Icon(Icons.dark_mode),
                              ),
                            ],
                            selected: {themeMode},
                            onSelectionChanged: (newSelection) {
                              ref
                                  .read(themeProvider.notifier)
                                  .setThemeMode(newSelection.first);
                            },
                            showSelectedIcon: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),

                _buildSectionHeader(context, l10n.cardDensity),
                _buildSettingsGroup(context, [
                  // Font
                  ListTile(
                    leading: const Icon(Icons.font_download_outlined),
                    title: Text(l10n.font),
                    trailing: MenuAnchor(
                      builder: (context, controller, child) => TextButton.icon(
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        label: Text(
                          displaySettings.useSystemFont
                              ? l10n.systemFont
                              : l10n.builtInFont,
                        ),
                        icon: const Icon(Icons.arrow_drop_down),
                      ),
                      menuChildren: [
                        MenuItemButton(
                          onPressed: () => ref
                              .read(displaySettingsProvider.notifier)
                              .setUseSystemFont(true),
                          child: Text(l10n.systemFont),
                        ),
                        MenuItemButton(
                          onPressed: () => ref
                              .read(displaySettingsProvider.notifier)
                              .setUseSystemFont(false),
                          child: Text(l10n.builtInFont),
                        ),
                      ],
                    ),
                  ),
                  // Collapse Images
                  SwitchListTile(
                    title: Text(l10n.collapseImages),
                    secondary: const Icon(Icons.image_not_supported_outlined),
                    value: displaySettings.collapseImages,
                    onChanged: (value) {
                      ref
                          .read(displaySettingsProvider.notifier)
                          .toggleCollapseImages();
                    },
                  ),
                  // Card Density
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.grid_view,
                              size: 24,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              l10n.cardDensity,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            segments: List.generate(
                              maxDensity,
                              (i) => ButtonSegment(
                                value: i + 1,
                                label: Text('${i + 1}'),
                              ),
                            ),
                            selected: {
                              displaySettings.itemsPerRow.clamp(1, maxDensity),
                            },
                            onSelectionChanged: (newSelection) {
                              ref
                                  .read(displaySettingsProvider.notifier)
                                  .setItemsPerRow(newSelection.first);
                            },
                            showSelectedIcon: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),

                _buildSectionHeader(context, l10n.help),
                _buildSettingsGroup(context, [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: Text(l10n.welcomeAndHelp),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ref.read(uiStateProvider.notifier).showHelp();
                    },
                  ),
                ]),

                _buildSectionHeader(context, l10n.databaseManager),
                _buildSettingsGroup(context, [
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text(l10n.databaseManager),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      if (screenWidth >= 1024) {
                        ref.read(leftPanelContentProvider.notifier).state =
                            LeftPanelContent.dbManager;
                      } else {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DatabaseManagerScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ]),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    ];

    if (isSidePanel) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.settings),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => ref.read(leftPanelContentProvider.notifier).state =
                LeftPanelContent.none,
          ),
        ),
        body: CustomScrollView(slivers: slivers),
      );
    }

    if (screenWidth < 1024 || !Navigator.canPop(context)) {
      return Scaffold(body: CustomScrollView(slivers: slivers));
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            ...slivers,
          ],
        ),
      ),
    );
  }
}
