import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../providers/db_provider.dart';
import '../providers/events_provider.dart';
import '../providers/filtered_events_provider.dart';
import '../providers/selection_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tags_provider.dart';
import '../providers/ui_state_provider.dart';
import '../extensions/extension_manager.dart';
import '../screens/extension_management_screen.dart';
import '../widgets/universal_image.dart';
import '../widgets/welcome_overlay.dart';
import 'edit_event_sheet.dart';
import 'event_detail_screen.dart';
import 'settings_sheet.dart';
import 'steps_editor_screen.dart';
import 'db_manager_screen.dart';
import 'manage_tags_screen.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isTagsExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleTagsExpanded() {
    setState(() => _isTagsExpanded = !_isTagsExpanded);
  }

  void _showAddExtensionDialog(BuildContext context) {
    final urlController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addExtension),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: Text(l10n.importFromLocalFile),
              subtitle: Text(l10n.selectJsonExtension),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                await ref.read(extensionManagerProvider).importFromFile();
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: l10n.enterUrlOrGithubLink,
                  hintText: 'https://...',
                  isDense: true,
                ),
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.download),
              label: Text(l10n.downloadAndInstallFromLink),
              onPressed: () async {
                final url = urlController.text.trim();
                if (url.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = navigatorKey.currentState;
                  Navigator.pop(context);
                  final ext = await ref
                      .read(extensionManagerProvider)
                      .importFromUrl(url);

                  if (!mounted) return;

                  if (ext != null && navigator != null) {
                    navigator.push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ExtensionManagementScreen(extension: ext),
                      ),
                    );
                  } else if (ext == null) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l10n.downloadFailedCheckLink)),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _showExtensionContextMenu(BuildContext context, dynamic ext) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.manageAndPermissions),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ExtensionManagementScreen(extension: ext),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.exportExtensionPackage),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(extensionManagerProvider)
                    .exportExtension(ext.metadata.id);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                l10n.uninstall,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmUninstall(context, ext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUninstall(BuildContext context, dynamic ext) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmUninstall),
        content: Text(l10n.uninstallExtensionWarning(ext.metadata.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              ref
                  .read(extensionManagerProvider)
                  .removeExtension(ext.metadata.id);

              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.extensionUninstalled)),
              );
            },
            child: Text(
              l10n.uninstall,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(dbProvider);

    return dbAsync.when(
      data: (_) => _buildAdaptiveLayout(context),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Database Error: $err'))),
    );
  }

  Widget _buildAdaptiveLayout(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1024;
    final currentTab = ref.watch(homeTabProvider);
    final isSelectionMode = ref.watch(selectionProvider).isNotEmpty;
    final leftPanelContent = ref.watch(leftPanelContentProvider);
    final leftPanelEventId = ref.watch(leftPanelEventIdProvider);
    final selectedEventId = ref.watch(selectedEventIdProvider);

    return Scaffold(
      floatingActionButton:
          currentTab == HomeTab.events &&
              (!isSelectionMode &&
                  !(isLargeScreen &&
                      leftPanelContent == LeftPanelContent.addEvent))
          ? FloatingActionButton(
              onPressed: () => _handleOpenAddEvent(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: !isLargeScreen
          ? NavigationBar(
              selectedIndex: currentTab.index,
              onDestinationSelected: (index) {
                ref.read(homeTabProvider.notifier).state =
                    HomeTab.values[index];
              },
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.event_note_outlined),
                  selectedIcon: const Icon(Icons.event_note),
                  label: AppLocalizations.of(context)!.navEvents,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.extension_outlined),
                  selectedIcon: const Icon(Icons.extension),
                  label: AppLocalizations.of(context)!.navExtensions,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.settings_outlined),
                  selectedIcon: const Icon(Icons.settings),
                  label: AppLocalizations.of(context)!.settings,
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (isLargeScreen)
              NavigationRail(
                extended: screenWidth >= 1200,
                selectedIndex: currentTab.index,
                onDestinationSelected: (index) {
                  ref.read(homeTabProvider.notifier).state =
                      HomeTab.values[index];
                },
                labelType: screenWidth >= 1200
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.event_note_outlined),
                    selectedIcon: const Icon(Icons.event_note),
                    label: Text(AppLocalizations.of(context)!.navEvents),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.extension_outlined),
                    selectedIcon: const Icon(Icons.extension),
                    label: Text(AppLocalizations.of(context)!.navExtensions),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(AppLocalizations.of(context)!.settings),
                  ),
                ],
              ),
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTabContent(
                          context,
                          currentTab,
                          isLargeScreen,
                        ),
                      ),
                      if (isLargeScreen && selectedEventId != null)
                        _SideDetailPanel(
                              screenWidth: screenWidth,
                              selectedEventId: selectedEventId,
                            )
                            .animate()
                            .fadeIn(duration: 200.ms)
                            .slideX(
                              begin: 0.1,
                              end: 0,
                              duration: 400.ms,
                              curve: Curves.easeOutCubic,
                            ),
                    ],
                  ),
                  // Scrim for Left Panel
                  if (isLargeScreen &&
                      leftPanelContent != LeftPanelContent.none)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () =>
                            ref.read(leftPanelContentProvider.notifier).state =
                                LeftPanelContent.none,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ).animate().fadeIn(duration: 200.ms),

                  // Top Layer: Left Floating Side Panel (Large Screen)
                  if (isLargeScreen &&
                      leftPanelContent != LeftPanelContent.none)
                    Positioned(
                          left: 0,
                          top: 16,
                          bottom: 16,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: _SideLeftPanel(
                              screenWidth: screenWidth,
                              content: leftPanelContent,
                              eventId: leftPanelEventId,
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 200.ms)
                        .slideX(
                          begin: -0.2,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    HomeTab tab,
    bool isLargeScreen,
  ) {
    return AnimatedSwitcher(
      duration: 400.ms,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _getTabWidget(tab),
    );
  }

  Widget _getTabWidget(HomeTab tab) {
    final l10n = AppLocalizations.of(context)!;
    switch (tab) {
      case HomeTab.events:
        return _buildMainContent(context);
      case HomeTab.extensions:
        final extensionManager = ref.watch(extensionManagerProvider);
        final extensions = extensionManager.extensions;
        final authNotifier = ref.watch(extensionAuthStateProvider.notifier);

        return Scaffold(
          key: const ValueKey('extensions'),
          appBar: AppBar(
            title: Text(l10n.navExtensions),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddExtensionDialog(context),
                tooltip: l10n.addExtension,
              ),
            ],
          ),
          body: extensions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.extension_off_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noExtensionsInstalled,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: extensions.length,
                  itemBuilder: (context, index) {
                    final ext = extensions[index];
                    final isRunning = authNotifier.isRunning(ext.metadata.id);

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: isRunning ? 2 : 0,
                      color: isRunning
                          ? null
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isRunning
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onLongPress: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExtensionManagementScreen(extension: ext),
                            ),
                          );
                        },
                        onSecondaryTap: () =>
                            _showExtensionContextMenu(context, ext),
                        onTap: () {
                          if (!isRunning) {
                            // 没运行时，点击跳转到详情页以启用
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExtensionManagementScreen(extension: ext),
                              ),
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ext.build(
                                context,
                                extensionManager.getApiFor(ext),
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Opacity(
                                    opacity: isRunning ? 1.0 : 0.4,
                                    child: Icon(
                                      ext.metadata.icon,
                                      size: 48,
                                      color: isRunning
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    ext.metadata.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: isRunning
                                              ? null
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.outline,
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    ext.metadata.description,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline
                                              .withValues(
                                                alpha: isRunning ? 1.0 : 0.6,
                                              ),
                                        ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!isRunning)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n.deactivated,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      case HomeTab.settings:
        return const SettingsSheet(key: ValueKey('settings'));
    }
  }

  Widget _buildMainContent(BuildContext context) {
    final filteredEvents = ref.watch(filteredEventsProvider);
    final selectedIds = ref.watch(selectionProvider);
    final isSelectionMode = selectedIds.isNotEmpty;
    final displaySettings = ref.watch(displaySettingsProvider);
    final selectedEventId = ref.watch(selectedEventIdProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1024;
    final isSmallScreen = screenWidth < 600;

    // Handle cross-screen detail navigation logic
    if (selectedEventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isLargeScreen && context.mounted) {
          // Switch from Large side panel to Small full screen
          final id = selectedEventId;
          ref.read(selectedEventIdProvider.notifier).state = null;
          context.push('/event/$id');
        }
      });
    }

    // Adaptive column count
    final itemsPerRow = displaySettings.itemsPerRow.clamp(
      1,
      isSmallScreen ? 2 : 5,
    );

    return Row(
      children: [
        // Main Content Area
        Expanded(
          child: Column(
            children: [
              // Fixed Top Bar
              _buildFixedTopBar(
                context,
                isSelectionMode,
                selectedIds,
                isLargeScreen,
              ),

              // Scrolling Content
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // Welcome (only in normal mode)
                    if (!isSelectionMode)
                      const SliverToBoxAdapter(child: WelcomeCard()),

                    // The Grid
                    if (filteredEvents.isEmpty)
                      const _EmptyStateSliver()
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverMasonryGrid.count(
                          crossAxisCount: itemsPerRow,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childCount: filteredEvents.length,
                          itemBuilder: (context, index) {
                            final event = filteredEvents[index];
                            return _EventCard(
                                  key: ValueKey(event.id),
                                  event: event,
                                  collapseImage: displaySettings.collapseImages,
                                  isFocused:
                                      isLargeScreen &&
                                      selectedEventId == event.id,
                                  isSelected: selectedIds.contains(event.id),
                                  isSelectionMode: isSelectionMode,
                                )
                                .animate()
                                .fadeIn(delay: (30 * index).ms)
                                .slideY(begin: 0.1, end: 0);
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Right Side Panel (Large Screen Details) - Stays in Row
        if (isLargeScreen && selectedEventId != null)
          _SideDetailPanel(
            screenWidth: screenWidth,
            selectedEventId: selectedEventId,
          ),
      ],
    );
  }

  void _handleOpenAddEvent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1024) {
      ref.read(leftPanelContentProvider.notifier).state =
          LeftPanelContent.addEvent;
      ref.read(leftPanelEventIdProvider.notifier).state = null;
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const EditEventSheet()),
      );
    }
  }

  Widget _buildFixedTopBar(
    BuildContext context,
    bool isSelectionMode,
    Set<String> selectedIds,
    bool isLargeScreen,
  ) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Upper Part: Search/Settings OR Selection Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isSelectionMode
                ? _buildSelectionBar(context, selectedIds)
                : Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: Theme.of(context).textTheme.bodyMedium,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(
                                context,
                              )!.searchPlaceholder,
                              hintStyle: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                            .read(searchProvider.notifier)
                                            .setQuery('');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (val) =>
                                ref.read(searchProvider.notifier).setQuery(val),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 12),

          // Lower Part: Tag Bar with Status, Tags, Sort, and Expand
          _buildTagBar(context),

          // Expanded Tags Panel
          ClipRect(
            child: AnimatedAlign(
              duration: 300.ms,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: _isTagsExpanded ? 1.0 : 0.0,
              child: AnimatedSize(
                duration: 300.ms,
                curve: Curves.easeOutCubic,
                child: _buildExpandedTagsPanel(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagBar(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Status Filters (Radio-style)
          _StatusToggleButtons(
            currentFilter: searchState.statusFilter,
            onChanged: (filter) =>
                ref.read(searchProvider.notifier).setStatusFilter(filter),
          ),

          const Spacer(),

          // Sort Button
          _SortMenu(compact: true),

          // Expand Button
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: Icon(
                  _isTagsExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: searchState.selectedTags.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: _toggleTagsExpanded,
                tooltip: "Expand Tags",
              ),
              if (searchState.selectedTags.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedTagsPanel(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final searchState = ref.watch(searchProvider);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.noTagsYet,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (searchState.selectedTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.tagsSelected(searchState.selectedTags.length),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          final screenWidth = MediaQuery.of(context).size.width;
                          if (screenWidth >= 1024) {
                            ref.read(leftPanelContentProvider.notifier).state =
                                LeftPanelContent.manageTags;
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ManageTagsScreen(),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: Text(AppLocalizations.of(context)!.manageTags),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () =>
                            ref.read(searchProvider.notifier).clearTags(),
                        icon: const Icon(Icons.clear_all_rounded, size: 16),
                        label: Text(AppLocalizations.of(context)!.clearAllTags),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.error,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          final screenWidth = MediaQuery.of(context).size.width;
                          if (screenWidth >= 1024) {
                            ref.read(leftPanelContentProvider.notifier).state =
                                LeftPanelContent.manageTags;
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ManageTagsScreen(),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: Text(AppLocalizations.of(context)!.manageTags),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: theme.colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tags.map((tag) {
                  final isSelected = searchState.selectedTags.contains(tag);
                  return _CustomFilterChip(
                    label: tag,
                    isSelected: isSelected,
                    onSelected: (val) =>
                        ref.read(searchProvider.notifier).toggleTag(tag),
                  );
                }).toList(),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context, Set<String> selectedIds) {
    final count = selectedIds.length;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(selectionProvider.notifier).clear(),
            ),
            const SizedBox(width: 8),
            Text(
              '$count ${AppLocalizations.of(context)!.selected}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.label_outline),
              tooltip: AppLocalizations.of(context)!.batchEditTags,
              onPressed: () => _showBatchEditTagsSheet(context, selectedIds),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _confirmBatchDelete(context, count),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBatchDelete(BuildContext context, int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteSelectedConfirmation),
        content: Text(
          AppLocalizations.of(context)!.deleteSelectedMessage(count),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppLocalizations.of(context)!.delete,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(batchActionsProvider).deleteSelected();
    }
  }

  void _showBatchEditTagsSheet(BuildContext context, Set<String> selectedIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BatchEditTagsSheet(selectedIds: selectedIds),
    );
  }
}

class _BatchEditTagsSheet extends ConsumerWidget {
  final Set<String> selectedIds;

  const _BatchEditTagsSheet({required this.selectedIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                l10n.batchEditTagsTitle(selectedIds.length),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          tagsAsync.when(
            data: (allTags) {
              if (allTags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      l10n.noTags,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                );
              }

              return eventsAsync.when(
                data: (allEvents) {
                  final selectedEvents = allEvents
                      .where((e) => selectedIds.contains(e.id))
                      .toList();

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      // 统计该标签在选中事件中的出现次数
                      final count = selectedEvents
                          .where((e) => e.tags?.contains(tag) ?? false)
                          .length;

                      // 状态判断
                      final bool isAllSelected = count == selectedEvents.length;
                      final bool isNoneSelected = count == 0;
                      final bool isPartialSelected =
                          !isAllSelected && !isNoneSelected;

                      return _TagBatchChip(
                        label: tag,
                        isAllSelected: isAllSelected,
                        isPartialSelected: isPartialSelected,
                        onTap: () async {
                          // 点击逻辑：
                          // 1. 如果是部分选中或未选中 -> 变为全部选中（为所有事件添加该标签）
                          // 2. 如果是全部选中 -> 变为未选中（从所有事件中移除该标签）
                          final bool shouldAdd = !isAllSelected;

                          for (final event in selectedEvents) {
                            final currentTags = List<String>.from(
                              event.tags ?? [],
                            );
                            if (shouldAdd) {
                              if (!currentTags.contains(tag)) {
                                currentTags.add(tag);
                              }
                            } else {
                              currentTags.remove(tag);
                            }
                            await ref
                                .read(eventsProvider.notifier)
                                .updateEventTags(event.id, currentTags);
                          }
                        },
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const SizedBox.shrink(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TagBatchChip extends StatelessWidget {
  final String label;
  final bool isAllSelected;
  final bool isPartialSelected;
  final VoidCallback onTap;

  const _TagBatchChip({
    required this.label,
    required this.isAllSelected,
    required this.isPartialSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color textColor;
    IconData? icon;

    if (isAllSelected) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
      icon = Icons.check_circle_rounded;
    } else if (isPartialSelected) {
      backgroundColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      icon = Icons.remove_circle_outline_rounded;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      );
      textColor = theme.colorScheme.onSurfaceVariant;
      icon = null;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: isPartialSelected
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: isAllSelected || isPartialSelected
                    ? FontWeight.bold
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  final bool compact;
  const _SortMenu({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<SortOrder>(
      icon: Icon(
        Icons.sort_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: compact ? 20 : 24,
      ),
      tooltip: AppLocalizations.of(context)!.sort,
      onSelected: (order) =>
          ref.read(searchProvider.notifier).setSortOrder(order),
      itemBuilder: (context) => [
        _sortItem(
          context,
          SortOrder.createdAtDesc,
          AppLocalizations.of(context)!.sortNewest,
        ),
        _sortItem(
          context,
          SortOrder.createdAtAsc,
          AppLocalizations.of(context)!.sortOldest,
        ),
        _sortItem(
          context,
          SortOrder.titleAsc,
          AppLocalizations.of(context)!.sortTitleAZ,
        ),
        _sortItem(
          context,
          SortOrder.titleDesc,
          AppLocalizations.of(context)!.sortTitleZA,
        ),
        _sortItem(
          context,
          SortOrder.progressDesc,
          AppLocalizations.of(context)!.sortProgressHigh,
        ),
        _sortItem(
          context,
          SortOrder.progressAsc,
          AppLocalizations.of(context)!.sortProgressLow,
        ),
      ],
    );
  }

  PopupMenuItem<SortOrder> _sortItem(
    BuildContext context,
    SortOrder value,
    String label,
  ) {
    return PopupMenuItem(value: value, child: Text(label));
  }
}

class _CustomFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const _CustomFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => onSelected(!isSelected),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusToggleButtons extends StatelessWidget {
  final EventStatusFilter currentFilter;
  final Function(EventStatusFilter) onChanged;

  const _StatusToggleButtons({
    required this.currentFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SegmentedButton<EventStatusFilter>(
      segments: [
        ButtonSegment<EventStatusFilter>(
          value: EventStatusFilter.all,
          label: Text(l10n.statusAll, style: const TextStyle(fontSize: 12)),
        ),
        ButtonSegment<EventStatusFilter>(
          value: EventStatusFilter.notStarted,
          label: Text(
            l10n.statusNotStarted,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        ButtonSegment<EventStatusFilter>(
          value: EventStatusFilter.inProgress,
          label: Text(
            l10n.statusInProgress,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        ButtonSegment<EventStatusFilter>(
          value: EventStatusFilter.completed,
          label: Text(
            l10n.statusCompleted,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
      selected: {currentFilter},
      onSelectionChanged: (Set<EventStatusFilter> newSelection) {
        onChanged(newSelection.first);
      },
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.zero,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        selectedBackgroundColor: theme.colorScheme.primary,
        selectedForegroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }
}

class _EmptyStateSliver extends StatelessWidget {
  const _EmptyStateSliver();
  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noEventSelected,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.tryAdjustingFilters,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideLeftPanel extends ConsumerWidget {
  final double _screenWidth;
  final LeftPanelContent _content;
  final String? _eventId;

  const _SideLeftPanel({
    required double screenWidth,
    required LeftPanelContent content,
    String? eventId,
  }) : _screenWidth = screenWidth,
       _content = content,
       _eventId = eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget child;
    switch (_content) {
      case LeftPanelContent.settings:
        child = const SettingsSheet(isSidePanel: true);
        break;
      case LeftPanelContent.stepsEditor:
        final id = _eventId;
        if (id == null) {
          child = const Center(child: Text("No event selected"));
        } else {
          child = StepsEditorScreen(eventId: id, isSidePanel: true);
        }
        break;
      case LeftPanelContent.addEvent:
        child = const EditEventSheet(isSidePanel: true);
        break;
      case LeftPanelContent.editEvent:
        final id = _eventId;
        final event = ref
            .watch(eventsProvider)
            .asData
            ?.value
            .cast<Event?>()
            .firstWhere((e) => e?.id == id, orElse: () => null);
        if (event == null) {
          child = const Center(child: Text("Event not found"));
        } else {
          child = EditEventSheet(event: event, isSidePanel: true);
        }
        break;
      case LeftPanelContent.dbManager:
        child = const DatabaseManagerScreen(isSidePanel: true);
        break;
      case LeftPanelContent.manageTags:
        child = const ManageTagsScreen(isSidePanel: true);
        break;
      case LeftPanelContent.none:
        return const SizedBox.shrink();
    }

    return Container(
      width: _screenWidth * 0.35, // Increased slightly for better readability
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SideDetailPanel extends StatelessWidget {
  final double screenWidth;
  final String selectedEventId;

  const _SideDetailPanel({
    required this.screenWidth,
    required this.selectedEventId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: screenWidth * 0.35, // Match Left Panel width
      margin: const EdgeInsets.only(left: 8), // Small gap from main content
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: EventDetailScreen(eventId: selectedEventId, isSidePanel: true),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final Event event;
  final bool collapseImage;
  final bool isFocused;
  final bool isSelected;
  final bool isSelectionMode;

  const _EventCard({
    super.key,
    required this.event,
    this.collapseImage = false,
    this.isFocused = false,
    this.isSelected = false,
    this.isSelectionMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AnimatedScale(
      scale: isFocused ? 1.02 : 1.0,
      duration: 200.ms,
      curve: Curves.easeOutCubic,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: isSelected ? 0 : (isFocused ? 4 : 1),
        shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: (isSelected || isFocused)
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: (isSelected || isFocused) ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () => _handleTap(context, ref),
          onLongPress: () =>
              ref.read(selectionProvider.notifier).toggle(event.id),
          child: Stack(
            children: [
              // Content
              Opacity(
                opacity: isSelected ? 0.4 : 1.0,
                child: _buildContent(context),
              ),

              // Selection Overlay
              if (isSelected)
                Positioned.fill(
                  child: Container(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    if (isSelectionMode) {
      ref.read(selectionProvider.notifier).toggle(event.id);
    } else if (MediaQuery.of(context).size.width >= 1024) {
      ref.read(selectedEventIdProvider.notifier).state = event.id;
    } else {
      context.push('/event/${event.id}');
    }
  }

  Widget _buildContent(BuildContext context) {
    final completedSteps = event.steps.where((s) => s.completed).length;
    final progress = event.steps.isNotEmpty
        ? completedSteps / event.steps.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (event.imageUrl != null && !collapseImage)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: UniversalImage(imageUrl: event.imageUrl!, fit: BoxFit.cover),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (event.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  event.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (event.tags?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                _TagsWrap(tags: event.tags!),
              ],
              if (event.steps.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ProgressBar(
                  progress: progress,
                  completed: completedSteps,
                  total: event.steps.length,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                DateFormat.yMMMd(
                  Localizations.localeOf(context).toString(),
                ).format(event.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagsWrap extends StatelessWidget {
  final List<String> tags;
  const _TagsWrap({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tags
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Text(
                tag,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final int completed;
  final int total;

  const _ProgressBar({
    required this.progress,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$completed / $total ${AppLocalizations.of(context)!.steps}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
