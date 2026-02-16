import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../l10n/app_localizations.dart';
import '../providers/ui_state_provider.dart';

class WelcomeHelpScreen extends ConsumerStatefulWidget {
  const WelcomeHelpScreen({super.key});

  @override
  ConsumerState<WelcomeHelpScreen> createState() => _WelcomeHelpScreenState();
}

class _WelcomeHelpScreenState extends ConsumerState<WelcomeHelpScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  String? _selectedDocTitle;
  Future<List<_DocItem>>? _docsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _docsFuture ??= _loadDocs(AppLocalizations.of(context)!);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(uiStateProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = theme.colorScheme;
    final isWelcomeMode = uiState.mode == WelcomeMode.welcome;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // 确保当页面通过任何方式关闭时（包括系统返回键），状态同步为已关闭
          ref.read(uiStateProvider.notifier).dismissWelcome();
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            isWelcomeMode ? l10n.exploreEssenmelia : l10n.helpAndDocs,
          ),
          centerTitle: true,
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
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
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: isWelcomeMode
              ? _buildOnboarding(context, theme, l10n)
              : _buildMarkdownReader(context, l10n, theme, colorScheme),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: uiState.mode.index,
          onDestinationSelected: (index) {
            final newMode = WelcomeMode.values[index];
            ref.read(uiStateProvider.notifier).setMode(newMode);
            if (newMode == WelcomeMode.welcome) {
              setState(() => _selectedDocTitle = null);
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome_rounded),
              label: l10n.welcome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.help_outline_rounded),
              selectedIcon: const Icon(Icons.help_rounded),
              label: l10n.help,
            ),
          ],
        ),
      ),
    );
  }

  // Removed _buildAppBar as it's replaced by standard Scaffold AppBar

  Widget _buildOnboarding(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final colorScheme = theme.colorScheme;
    final steps = [
      _GuideStep(
        title: 'Essenmelia',
        subtitle: l10n.welcomeSubtitle1,
        content: l10n.welcomeContent1,
        icon: Icons.auto_awesome_rounded,
        color: colorScheme.primary,
        image:
            'assets/images/welcome_1.png', // Optional: could use illustration
      ),
      _GuideStep(
        title: l10n.privacyFirst,
        subtitle: l10n.welcomeSubtitle2,
        content: l10n.welcomeContent2,
        icon: Icons.security_rounded,
        color: colorScheme.secondary,
      ),
      _GuideStep(
        title: l10n.highlyCustomizable,
        subtitle: l10n.welcomeSubtitle3,
        content: l10n.welcomeContent3,
        icon: Icons.dashboard_customize_rounded,
        color: colorScheme.tertiary,
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: steps.length,
            onPageChanged: (index) => setState(() => _currentStep = index),
            itemBuilder: (context, index) {
              final step = steps[index];
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 48,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Transform.rotate(
                              angle: (1.0 - value) * 0.2,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                step.color.withValues(alpha: 0.2),
                                step.color.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(48),
                            boxShadow: [
                              BoxShadow(
                                color: step.color.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(step.icon, color: step.color, size: 80),
                        ),
                      ),
                      const SizedBox(height: 64),
                      Text(
                        step.title,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: step.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          step.subtitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: step.color,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        step.content,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.6,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 17,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildOnboardingBottom(steps.length, colorScheme, l10n),
      ],
    );
  }

  Widget _buildOnboardingBottom(
    int totalSteps,
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalSteps,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentStep == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentStep == index
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: Text(
                        l10n.cancel, // Use cancel or similar
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () {
                      if (_currentStep < totalSteps - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                        );
                      } else {
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _currentStep == totalSteps - 1
                            ? l10n.startExperience
                            : l10n.nextStep,
                        key: ValueKey(_currentStep == totalSteps - 1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_DocItem>> _loadDocs(AppLocalizations l10n) async {
    // 仅保留图标映射和排序，标题/描述全部从Markdown解析
    final docIcons = {
      'assets/docs/architecture.md': Icons.account_tree_rounded,
      'assets/docs/api_usage.md': Icons.api_rounded,
      'assets/docs/extensions.md': Icons.extension_rounded,
      'assets/docs/create_repository_guide.md': Icons.terminal_rounded,
    };

    try {
      // 尝试加载新的二进制格式 Manifest (Flutter 3.19+)
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();

      final docPaths = assets
          .where((key) => key.startsWith('assets/docs/') && key.endsWith('.md'))
          .toList();

      final docs = await Future.wait(
        docPaths.map((path) async {
          String title;
          String description;

          try {
            // Read first few lines for metadata
            final content = await rootBundle.loadString(path);
            final lines = content.split('\n');

            // 1. Extract Title (first line starting with #)
            final titleLine = lines.firstWhere(
              (line) => line.trim().startsWith('# '),
              orElse: () => '',
            );

            if (titleLine.isNotEmpty) {
              title = titleLine.trim().substring(2).trim();
            } else {
              // Fallback to filename title case
              final filename = path.split('/').last.replaceAll('.md', '');
              title = filename
                  .split('_')
                  .map(
                    (word) => word.isNotEmpty
                        ? '${word[0].toUpperCase()}${word.substring(1)}'
                        : '',
                  )
                  .join(' ');
            }

            // 2. Extract Description (first non-empty, non-header line)
            final descLine = lines.firstWhere((line) {
              final trimmed = line.trim();
              return trimmed.isNotEmpty && !trimmed.startsWith('#');
            }, orElse: () => '');

            description = descLine.isNotEmpty
                ? descLine.trim()
                : path.split('/').last;
          } catch (e) {
            debugPrint('Error parsing doc metadata for $path: $e');
            // Fallback
            final filename = path.split('/').last.replaceAll('.md', '');
            title = filename
                .split('_')
                .map(
                  (word) => word.isNotEmpty
                      ? '${word[0].toUpperCase()}${word.substring(1)}'
                      : '',
                )
                .join(' ');
            description = path.split('/').last;
          }

          return _DocItem(
            title: title,
            description: description,
            icon: docIcons[path] ?? Icons.article_rounded,
            assetPath: path,
          );
        }),
      );

      // Sort: Known ones first, then alphabetical
      final orderedKnownKeys = [
        'assets/docs/architecture.md',
        'assets/docs/api_usage.md',
        'assets/docs/extensions.md',
        'assets/docs/create_repository_guide.md',
      ];

      docs.sort((a, b) {
        final indexA = orderedKnownKeys.indexOf(a.assetPath);
        final indexB = orderedKnownKeys.indexOf(b.assetPath);

        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;

        return a.title.compareTo(b.title);
      });

      return docs;
    } catch (e) {
      debugPrint('Error loading docs: $e');
      return [];
    }
  }

  Widget _buildMarkdownReader(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;

    return FutureBuilder<List<_DocItem>>(
      future: _docsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!;

        return Row(
          children: [
            if (isLargeScreen)
              Container(
                width: 320,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Text(
                        l10n.helpAndDocs,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final isSelected = _selectedDocTitle == doc.title;
                          return Material(
                            color: isSelected
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedDocTitle = doc.title),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      doc.icon,
                                      size: 20,
                                      color: isSelected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.title,
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  fontWeight: isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color: isSelected
                                                      ? colorScheme
                                                            .onPrimaryContainer
                                                      : colorScheme.onSurface,
                                                ),
                                          ),
                                          Text(
                                            doc.description,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: isSelected
                                                      ? colorScheme
                                                            .onPrimaryContainer
                                                            .withValues(
                                                              alpha: 0.7,
                                                            )
                                                      : colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: () {
                  final selectedDoc = docs
                      .where((d) => d.title == _selectedDocTitle)
                      .firstOrNull;

                  if (selectedDoc == null) {
                    return _buildDocPlaceholder(
                      isLargeScreen,
                      docs,
                      l10n,
                      theme,
                      colorScheme,
                    );
                  }

                  return _MarkdownContentViewer(
                    key: ValueKey(_selectedDocTitle),
                    doc: selectedDoc,
                    onBack: isLargeScreen
                        ? null
                        : () => setState(() => _selectedDocTitle = null),
                  );
                }(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDocPlaceholder(
    bool isLargeScreen,
    List<_DocItem> docs,
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    if (!isLargeScreen) {
      return ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: docs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final doc = docs[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _selectedDocTitle = doc.title),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(doc.icon, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            doc.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_stories_rounded,
            size: 80,
            color: colorScheme.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.selectDocToRead,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkdownContentViewer extends StatelessWidget {
  final _DocItem doc;
  final VoidCallback? onBack;

  const _MarkdownContentViewer({required this.doc, this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: onBack != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack,
              ),
            )
          : null,
      body: FutureBuilder<String>(
        future: rootBundle.loadString(doc.assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(l10n.loadFailed(snapshot.error.toString())),
            );
          }

          return Markdown(
            data: snapshot.data ?? '',
            padding: const EdgeInsets.all(32),
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              h1: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.primary,
                letterSpacing: -0.5,
              ),
              h2: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.secondary,
                letterSpacing: -0.3,
              ),
              h3: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.tertiary,
              ),
              p: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                color: colorScheme.onSurfaceVariant,
              ),
              code: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.onSurfaceVariant,
              ),
              codeblockDecoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              blockquote: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: colorScheme.primary, width: 4),
                ),
                color: colorScheme.primary.withValues(alpha: 0.05),
              ),
              listBullet: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GuideStep {
  final String title;
  final String subtitle;
  final String content;
  final IconData icon;
  final Color color;
  final String? image;

  _GuideStep({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.icon,
    required this.color,
    this.image,
  });
}

class _DocItem {
  final String title;
  final String description;
  final IconData icon;
  final String assetPath;

  _DocItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.assetPath,
  });
}
