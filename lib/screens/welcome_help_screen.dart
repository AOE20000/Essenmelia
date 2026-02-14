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
              if (Navigator.canPop(context)) Navigator.of(context).pop();
            },
          ),
          title: Text(isWelcomeMode ? '探索 Essenmelia' : '帮助与文档'),
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
              : _buildMarkdownReader(context, theme, l10n),
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
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: '欢迎',
            ),
            NavigationDestination(
              icon: Icon(Icons.help_outline_rounded),
              selectedIcon: Icon(Icons.help_rounded),
              label: '帮助',
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
        subtitle: '您的个人日程与灵感管理专家',
        content: '高效组织生活中的每一个精彩瞬间。无论是琐碎的日常，还是宏大的计划，都能在这里找到归宿。',
        icon: Icons.auto_awesome_rounded,
        color: colorScheme.primary,
      ),
      _GuideStep(
        title: '隐私优先',
        subtitle: '安全、透明、可控',
        content: '所有数据本地存储，非信任插件只能访问由系统生成的伪造数据，确保您的真实信息永不外泄。',
        icon: Icons.shield_rounded,
        color: colorScheme.secondary,
      ),
      _GuideStep(
        title: '高度自定义',
        subtitle: '随心而动，无限可能',
        content: '通过强大的插件系统，您可以轻松扩展应用功能。使用声明式 UI 引擎，定制属于您的专属管理工具。',
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: step.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Icon(step.icon, color: step.color, size: 80),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Text(
                      step.title,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.subtitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: step.color,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      step.content,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                  ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              totalSteps,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentStep == index ? 32 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentStep == index
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_currentStep < totalSteps - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                } else {
                  if (Navigator.canPop(context)) Navigator.of(context).pop();
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(_currentStep == totalSteps - 1 ? '开始体验' : '下一步'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownReader(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final docs = [
      _DocItem(
        title: '架构设计',
        description: '系统分层、隐私黑盒与权限模型',
        icon: Icons.account_tree_rounded,
        assetPath: 'assets/docs/architecture.md',
      ),
      _DocItem(
        title: 'API 使用指南',
        description: '核心方法、通知方案与外部集成',
        icon: Icons.api_rounded,
        assetPath: 'assets/docs/api_usage.md',
      ),
      _DocItem(
        title: '扩展开发规范',
        description: '元数据、UI 组件库与逻辑引擎',
        icon: Icons.extension_rounded,
        assetPath: 'assets/docs/extensions.md',
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1024;

    if (isLargeScreen) {
      return Row(
        children: [
          SizedBox(
            width: 320,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final isSelected = _selectedDocTitle == doc.title;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor: theme.colorScheme.secondaryContainer,
                    selectedColor: theme.colorScheme.onSecondaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    leading: Icon(
                      isSelected
                          ? doc.icon
                          : doc.icon, // Could use outlined vs filled if available
                      color: isSelected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      doc.title,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      doc.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onSecondaryContainer.withValues(
                                alpha: 0.7,
                              )
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => setState(() => _selectedDocTitle = doc.title),
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selectedDocTitle == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '请选择一个文档进行阅读',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildMarkdownContent(
                    docs.firstWhere((d) => d.title == _selectedDocTitle),
                    theme,
                  ),
          ),
        ],
      );
    }

    // Mobile Layout with AnimatedSwitcher for List/Detail
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _selectedDocTitle == null
          ? ListView.builder(
              key: const ValueKey('doc_list'),
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: theme.colorScheme.surfaceContainerLow,
                    leading: Icon(doc.icon, color: theme.colorScheme.primary),
                    title: Text(
                      doc.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(doc.description),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => setState(() => _selectedDocTitle = doc.title),
                  ),
                );
              },
            )
          : Column(
              key: const ValueKey('doc_detail'),
              children: [
                ListTile(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => setState(() => _selectedDocTitle = null),
                  ),
                  title: Text(
                    _selectedDocTitle!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildMarkdownContent(
                    docs.firstWhere((d) => d.title == _selectedDocTitle),
                    theme,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMarkdownContent(_DocItem doc, ThemeData theme) {
    return FutureBuilder<String>(
      future: rootBundle.loadString(doc.assetPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }

        return Markdown(
          data: snapshot.data ?? '',
          selectable: true,
          padding: const EdgeInsets.all(24),
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            h1: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              height: 2.0,
            ),
            h2: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
              height: 1.8,
            ),
            h3: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.tertiary,
            ),
            p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            listBullet: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
            blockquote: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            blockquoteDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 4),
              ),
            ),
            code: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              backgroundColor: theme.colorScheme.secondaryContainer,
              fontFamily: 'monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
    );
  }
}

class _GuideStep {
  final String title;
  final String subtitle;
  final String content;
  final IconData icon;
  final Color color;

  _GuideStep({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.icon,
    required this.color,
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
