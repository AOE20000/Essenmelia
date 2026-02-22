import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../extensions/extension_log_manager.dart';
import '../l10n/app_localizations.dart';
import '../extensions/services/system_health_check_service.dart';
import '../providers/ui_state_provider.dart';

class ExtensionLogsPage extends ConsumerWidget {
  final bool isSidePanel;

  const ExtensionLogsPage({super.key, this.isSidePanel = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final logs = ref.watch(extensionLogProvider);
    final l10n = AppLocalizations.of(context)!;

    final contentSlivers = [
      if (logs.isEmpty)
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: colorScheme.outlineVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noApiLogs,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final log = logs[index];
              return _buildLogItem(context, log);
            }, childCount: logs.length),
          ),
        ),
    ];

    if (isSidePanel) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    // Assuming "back" means going back to extension list if opened from there,
                    // or just closing if it's the only thing.
                    // But usually logs are opened from the main extension tab toolbar.
                    // If we want to mimic "back", maybe go to extension manager?
                    // Actually, logs are global, not per extension.
                    // So maybe just close or go back to "none" if it was opened from menu.
                    // But usually back means "go back to previous panel state".
                    // For now, let's make it go to extensionManager if that makes sense,
                    // or just close if it was opened from top bar.
                    // The user said "like DB manager", DB manager has back button.
                    // Let's make it go to extensionManager if appropriate, or just close.
                    // Actually, if opened from the top bar of the main screen, there is no "previous" panel.
                    // So maybe just close it? Or maybe the back button isn't needed if it's a top level panel.
                    // But DB manager has it.
                    // Let's look at DB manager usage.
                    // If it's a top level thing, maybe we don't need back button, just close.
                    // But for consistency with the "left panel" design, let's include it.
                    // If we are in "Extension Logs", maybe back goes to "Extension List"?
                    ref.read(leftPanelContentProvider.notifier).state =
                        LeftPanelContent.none;
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.extensionLogsTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bug_report_outlined),
                  tooltip: l10n.healthCheckRunTooltip,
                  onPressed: () => _showHealthCheck(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    ref.read(extensionLogProvider.notifier).clearLogs();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    ref.read(leftPanelContentProvider.notifier).state =
                        LeftPanelContent.none;
                  },
                ),
              ],
            ),
          ),
          Expanded(child: CustomScrollView(slivers: contentSlivers)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text(l10n.extensionLogsTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.bug_report_outlined),
                tooltip: l10n.healthCheckRunTooltip,
                onPressed: () => _showHealthCheck(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  ref.read(extensionLogProvider.notifier).clearLogs();
                },
              ),
            ],
          ),
          ...contentSlivers,
        ],
      ),
    );
  }

  Widget _buildLogItem(BuildContext context, ExtensionLogEntry log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final timeStr = DateFormat('HH:mm:ss').format(log.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        color: colorScheme.surfaceContainerLow,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLogDetails(context, log),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: log.success
                        ? (log.isUntrusted
                              ? colorScheme.tertiaryContainer
                              : colorScheme.primaryContainer)
                        : colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    log.isUntrusted
                        ? Icons.security
                        : (log.success ? Icons.api : Icons.error_outline),
                    size: 20,
                    color: log.success
                        ? (log.isUntrusted
                              ? colorScheme.onTertiaryContainer
                              : colorScheme.onPrimaryContainer)
                        : colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.extensionName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(color: colorScheme.outlineVariant),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.method,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.params.isEmpty
                            ? l10n.noParams
                            : log.params.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                if (log.isUntrusted)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.restrictedAccess,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogDetails(BuildContext context, ExtensionLogEntry log) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final fullTimeStr = DateFormat(
      'yyyy-MM-dd HH:mm:ss.SSS',
    ).format(log.timestamp);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    log.success
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: log.success
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.logDetails,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildDetailRow(
                      context,
                      l10n.extensionNameLabel,
                      log.extensionName,
                    ),
                    _buildDetailRow(
                      context,
                      l10n.extensionIdLabel,
                      log.extensionId,
                    ),
                    _buildDetailRow(context, l10n.methodLabel, log.method),
                    _buildDetailRow(context, l10n.timeLabel, fullTimeStr),
                    _buildDetailRow(
                      context,
                      l10n.statusLabel,
                      log.success ? l10n.successLabel : l10n.failedLabel,
                    ),
                    _buildDetailRow(
                      context,
                      l10n.accessModeLabel,
                      log.isUntrusted
                          ? l10n.restrictedAccessIntercepted
                          : l10n.trustedModePassthrough,
                    ),
                    if (log.error != null)
                      _buildDetailRow(
                        context,
                        l10n.errorMessageLabel,
                        log.error!,
                        isError: true,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.paramsDetails,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        log.params.toString(),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isError ? theme.colorScheme.error : null,
              fontWeight: isError ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showHealthCheck(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) =>
            _HealthCheckView(scrollController: scrollController),
      ),
    );
  }
}

class _HealthCheckView extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _HealthCheckView({required this.scrollController});

  @override
  ConsumerState<_HealthCheckView> createState() => _HealthCheckViewState();
}

class _HealthCheckViewState extends ConsumerState<_HealthCheckView> {
  List<HealthTestResult> _results = [];
  bool _isRunning = false;
  bool _useSandbox = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_startTests);
  }

  Future<void> _startTests() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _results = [];
    });

    final service = ref.read(systemHealthCheckServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    await for (final results in service.runTests(
      l10n,
      useSandbox: _useSandbox,
    )) {
      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.monitor_heart_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppLocalizations.of(context)!.healthCheckTitle,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_isRunning)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                )
              else
                IconButton.filledTonal(
                  onPressed: _startTests,
                  icon: const Icon(Icons.refresh),
                  tooltip: AppLocalizations.of(
                    context,
                  )!.healthCheckRerunTooltip,
                ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(AppLocalizations.of(context)!.healthCheckEnvironment),
            subtitle: Text(
              _useSandbox
                  ? AppLocalizations.of(context)!.healthCheckSandboxMode
                  : AppLocalizations.of(context)!.healthCheckRealMode,
            ),
            value: _useSandbox,
            onChanged: _isRunning
                ? null
                : (value) {
                    setState(() {
                      _useSandbox = value;
                    });
                    _startTests();
                  },
            secondary: Icon(
              _useSandbox ? Icons.security : Icons.public,
              color: colorScheme.primary,
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              controller: widget.scrollController,
              itemCount: _results.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
              itemBuilder: (context, index) {
                final result = _results[index];
                final isFailed = result.status == HealthStatus.failed;
                final isWarning = result.status == HealthStatus.warning;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusIcon(result.status, colorScheme),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  result.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (result.duration != null)
                                  Text(
                                    '${result.duration!.inMilliseconds}ms',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.outline,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              result.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (result.message != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isFailed
                                        ? colorScheme.errorContainer.withValues(
                                            alpha: 0.5,
                                          )
                                        : (isWarning
                                              ? colorScheme.tertiaryContainer
                                                    .withValues(alpha: 0.5)
                                              : colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  width: double.infinity,
                                  child: Text(
                                    result.message!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isFailed
                                          ? colorScheme.onErrorContainer
                                          : (isWarning
                                                ? colorScheme
                                                      .onTertiaryContainer
                                                : colorScheme.onSurfaceVariant),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(HealthStatus status, ColorScheme colorScheme) {
    switch (status) {
      case HealthStatus.pending:
        return Icon(
          Icons.circle_outlined,
          color: colorScheme.outline,
          size: 24,
        );
      case HealthStatus.running:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        );
      case HealthStatus.success:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case HealthStatus.failed:
        return Icon(Icons.error, color: colorScheme.error, size: 24);
      case HealthStatus.warning:
        return Icon(Icons.warning_amber, color: colorScheme.tertiary, size: 24);
    }
  }
}
