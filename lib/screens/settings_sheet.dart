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
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final displaySettings = ref.watch(displaySettingsProvider);
    final l10n = AppLocalizations.of(context)!;

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final maxDensity = isSmallScreen ? 2 : 5;

    final body = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: [
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(context, l10n.appearance),
                // Language
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.language),
                  trailing: DropdownButton<Locale?>(
                    value: ref.watch(localeProvider),
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(l10n.systemLanguage),
                      ),
                      DropdownMenuItem(
                        value: const Locale('en'),
                        child: Text(l10n.english),
                      ),
                      DropdownMenuItem(
                        value: const Locale('zh'),
                        child: Text(l10n.chinese),
                      ),
                    ],
                    onChanged: (locale) {
                      ref.read(localeProvider.notifier).setLocale(locale);
                    },
                  ),
                ),
                // Theme Mode SegmentedButton
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            l10n.darkMode,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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

                _buildSectionHeader(context, l10n.cardDensity),
                // Font
                ListTile(
                  leading: const Icon(Icons.font_download_outlined),
                  title: Text(l10n.font),
                  trailing: DropdownButton<bool>(
                    value: displaySettings.useSystemFont,
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(12),
                    items: [
                      DropdownMenuItem(
                        value: true,
                        child: Text(l10n.systemFont),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text(l10n.builtInFont),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(displaySettingsProvider.notifier)
                            .setUseSystemFont(value);
                      }
                    },
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
                // Card Density SegmentedButton
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.grid_view,
                            size: 24,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            l10n.cardDensity,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
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

                _buildSectionHeader(context, l10n.help),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(l10n.welcomeAndHelp),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // 仅更新状态，由 HomePage 的监听器负责导航，避免重复 push
                    ref.read(uiStateProvider.notifier).showHelp();
                  },
                ),

                _buildSectionHeader(context, l10n.databaseManager),
                // Database Manager
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
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );

    if (isSidePanel || screenWidth < 1024 || !Navigator.canPop(context)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.settings),
          centerTitle: isSidePanel ? false : null,
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: Navigator.canPop(context),
          leading: isSidePanel
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () =>
                      ref.read(leftPanelContentProvider.notifier).state =
                          LeftPanelContent.none,
                )
              : null,
        ),
        body: body,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: body,
    );
  }
}
