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
import '../extensions/manager/extension_manager.dart';
import '../extensions/security/extension_auth_notifier.dart';
import '../screens/extension_details_screen.dart';
import '../screens/extension_logs_page.dart';
import '../widgets/universal_image.dart';
import 'welcome_help_screen.dart';
import '../widgets/filter_bottom_sheet.dart';
import 'edit_event_sheet.dart';
import 'event_detail_screen.dart';
import 'settings_sheet.dart';
import 'steps_editor_screen.dart';
import 'db_manager_screen.dart';
import 'manage_tags_screen.dart';
import 'extension_management_screen.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final SearchController _searchController = SearchController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;

    // 逻辑：
    // 1. 如果在顶部，必须显示“新建”
    // 2. 如果向下滚动 (delta > 0)，显示“回到顶部”
    // 3. 如果向上滚动 (delta < -10)，恢复为“新建” (添加一点阈值防止抖动)

    if (currentOffset <= 0) {
      if (_showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    } else if (delta > 0) {
      if (!_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      }
    } else if (delta < -10) {
      if (_showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    }

    _lastScrollOffset = currentOffset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddExtensionDialog(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ExtensionManagementScreen(),
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
                        ExtensionDetailsScreen(extension: ext),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.extensionExport),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(extensionManagerProvider)
                    .exportExtensionAsZip(ext.metadata.id);
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
                SnackBar(
                  content: Text(l10n.extensionUninstalled(ext.metadata.name)),
                ),
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
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text(
            AppLocalizations.of(context)!.databaseError(err.toString()),
          ),
        ),
      ),
    );
  }

  Widget _buildAdaptiveLayout(BuildContext context) {
    ref.listen(uiStateProvider, (previous, next) {
      if (next.showWelcome && (previous == null || !previous.showWelcome)) {
        // 使用 rootNavigator 确保全屏，并防止重复弹窗
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => const WelcomeHelpScreen(),
          ),
        );
      }
    });

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
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  _showScrollToTop ? Icons.arrow_upward : Icons.add,
                  key: ValueKey(_showScrollToTop),
                ),
              ),
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
      duration: 300.ms,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren.map((child) => IgnorePointer(child: child)),
            currentChild ?? const SizedBox.shrink(),
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.01),
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
        return KeyedSubtree(
          key: const ValueKey('events'),
          child: _buildMainContent(context),
        );
      case HomeTab.extensions:
        final extensionManager = ref.watch(extensionManagerProvider);
        final extensions = extensionManager.extensions;
        final authNotifier = ref.watch(extensionAuthStateProvider.notifier);
        final showExtensionGuide = ref.watch(showExtensionGuideProvider);
        final theme = Theme.of(context);

        return Scaffold(
          key: const ValueKey('extensions'),
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            scrolledUnderElevation: 0,
            title: Text(
              l10n.navExtensions,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton.filledTonal(
                icon: const Icon(Icons.assignment_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ExtensionLogsPage(),
                    ),
                  );
                },
                tooltip: l10n.extensionLogs,
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddExtensionDialog(context),
                tooltip: l10n.addExtension,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: extensions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.extension_off_outlined,
                          size: 48,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.noExtensionsInstalled,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () => _showAddExtensionDialog(context),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.addExtension),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    if (showExtensionGuide)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Material(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          l10n.welcomeToExtensions,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          ref
                                              .read(
                                                showExtensionGuideProvider
                                                    .notifier,
                                              )
                                              .dismissGuide();
                                        },
                                        icon: const Icon(Icons.close, size: 18),
                                        tooltip: l10n.dontShowAgain,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.longPressToManageExtension,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.85,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final ext = extensions[index];
                          final isRunning = authNotifier.isRunning(
                            ext.metadata.id,
                          );

                          return Material(
                            color: isRunning
                                ? theme.colorScheme.surfaceContainerLow
                                : theme.colorScheme.surfaceContainerLowest,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                              side: BorderSide(
                                color: isRunning
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.15,
                                      )
                                    : theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                width: isRunning ? 1.5 : 1,
                              ),
                            ),
                            child: InkWell(
                              onLongPress: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ExtensionDetailsScreen(extension: ext),
                                  ),
                                );
                              },
                              onSecondaryTap: () =>
                                  _showExtensionContextMenu(context, ext),
                              onTap: () {
                                if (!isRunning) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ExtensionDetailsScreen(
                                            extension: ext,
                                          ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isRunning
                                                ? theme
                                                      .colorScheme
                                                      .primaryContainer
                                                      .withValues(alpha: 0.4)
                                                : theme
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Hero(
                                            tag: 'ext_icon_${ext.metadata.id}',
                                            child: Icon(
                                              ext.metadata.icon,
                                              size: 40,
                                              color: isRunning
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.outline,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          ext.metadata.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: isRunning
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                                color: isRunning
                                                    ? theme
                                                          .colorScheme
                                                          .onSurface
                                                    : theme
                                                          .colorScheme
                                                          .onSurfaceVariant
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                              ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          ext.metadata.description,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: theme.colorScheme.outline
                                                    .withValues(
                                                      alpha: isRunning
                                                          ? 0.9
                                                          : 0.6,
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
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          l10n.deactivated,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.outline,
                                              ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }, childCount: extensions.length),
                      ),
                    ),
                  ],
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
                  controller: _scrollController,
                  slivers: [
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
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
      return;
    }

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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final searchQuery = ref.watch(searchProvider).query;

    // Sync search controller if query changes externally (e.g., cleared from another place)
    if (_searchController.text != searchQuery) {
      _searchController.text = searchQuery;
    }

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: isSelectionMode
                  ? _buildSelectionBar(context, selectedIds)
                  : Row(
                      key: const ValueKey('search_bar_row'),
                      children: [
                        Expanded(
                          child: SearchBar(
                            controller: _searchController,
                            padding: const WidgetStatePropertyAll<EdgeInsets>(
                              EdgeInsets.symmetric(horizontal: 16.0),
                            ),
                            onChanged: (value) {
                              ref.read(searchProvider.notifier).setQuery(value);
                            },
                            leading: Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            hintText: l10n.searchPlaceholder,
                            elevation: const WidgetStatePropertyAll<double>(0),
                            backgroundColor: WidgetStatePropertyAll<Color>(
                              theme.colorScheme.surfaceContainerHigh,
                            ),
                            shape: WidgetStatePropertyAll<OutlinedBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            trailing: [
                              if (searchQuery.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(searchProvider.notifier)
                                        .setQuery('');
                                  },
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.tune_rounded),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              useSafeArea: true,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const FilterBottomSheet(),
                            );
                          },
                          tooltip: l10n.filter,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context, Set<String> selectedIds) {
    final count = selectedIds.length;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: theme.colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => ref.read(selectionProvider.notifier).clear(),
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.selectedItemsCount(count),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.label_outline_rounded),
              tooltip: l10n.batchEditTags,
              onPressed: () => _showBatchEditTagsSheet(context, selectedIds),
              color: theme.colorScheme.onPrimaryContainer,
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              tooltip: l10n.delete,
              onPressed: () => _confirmBatchDelete(context, count),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBatchDelete(BuildContext context, int count) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.deleteSelectedConfirmation),
          content: Text(l10n.deleteSelectedMessage(count)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                l10n.delete,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        );
      },
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

class _ReminderInfo extends StatelessWidget {
  final DateTime reminderTime;
  final String? recurrence;

  const _ReminderInfo({required this.reminderTime, this.recurrence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final l10n = AppLocalizations.of(context)!;

    String recurrenceText = '';
    IconData recurrenceIcon = Icons.notifications_outlined;

    if (recurrence != null && recurrence != 'none') {
      recurrenceIcon = Icons.update_rounded;
      switch (recurrence) {
        case 'daily':
          recurrenceText = l10n.recurrenceDaily;
          break;
        case 'weekly':
          recurrenceText = l10n.recurrenceWeekly;
          break;
        case 'monthly':
          recurrenceText = l10n.recurrenceMonthly;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(recurrenceIcon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${DateFormat.jm(locale).format(reminderTime)}$recurrenceText',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.batchEditTagsTitle(selectedIds.length),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          tagsAsync.when(
            data: (allTags) {
              if (allTags.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.label_off_outlined,
                        size: 48,
                        color: theme.colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noTags,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return eventsAsync.when(
                data: (allEvents) {
                  final selectedEvents = allEvents
                      .where((e) => selectedIds.contains(e.id))
                      .toList();

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: allTags.map((tag) {
                      final count = selectedEvents
                          .where((e) => e.tags?.contains(tag) ?? false)
                          .length;

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
    IconData icon;
    double iconSize = 18;

    if (isAllSelected) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
      icon = Icons.check_circle_rounded;
    } else if (isPartialSelected) {
      backgroundColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      icon = Icons.remove_circle_rounded;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHigh;
      textColor = theme.colorScheme.onSurfaceVariant;
      icon = Icons.circle_outlined;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: !isAllSelected && !isPartialSelected
                ? Border.all(color: theme.colorScheme.outlineVariant, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: textColor),
              const SizedBox(width: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: textColor,
                  fontWeight: isAllSelected || isPartialSelected
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateSliver extends ConsumerWidget {
  const _EmptyStateSliver();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final hasActiveFilter =
        searchState.query.isNotEmpty ||
        searchState.selectedTags.isNotEmpty ||
        searchState.statusFilter != EventStatusFilter.all;

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasActiveFilter
                  ? Icons.search_off_rounded
                  : Icons.event_busy_rounded,
              size: 80,
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              hasActiveFilter ? l10n.noMatchingEvents : l10n.noEventsYet,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasActiveFilter
                  ? l10n.tryAdjustingFilters
                  : l10n.createFirstEvent,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
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
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : (isFocused
                  ? theme.colorScheme.surfaceContainerHigh
                  : theme.colorScheme.surfaceContainerLow),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: isSelected
                ? theme.colorScheme.primary
                : (isFocused
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        )),
            width: isSelected ? 2 : (isFocused ? 1.5 : 1),
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
                opacity: isSelected ? 0.6 : 1.0,
                child: _buildContent(context),
              ),

              // Selection Overlay
              if (isSelected)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 16,
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
                  suffix: event.stepSuffix,
                ),
              ],
              if (event.reminderTime != null) ...[
                const SizedBox(height: 8),
                _ReminderInfo(
                  reminderTime: event.reminderTime!,
                  recurrence: event.reminderRecurrence,
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
  final String? suffix;

  const _ProgressBar({
    required this.progress,
    required this.completed,
    required this.total,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final suffixText = suffix ?? l10n.steps;

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
              '$completed / $total $suffixText',
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
