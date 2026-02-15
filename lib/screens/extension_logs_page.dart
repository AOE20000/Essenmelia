import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../extensions/extension_log_manager.dart';
import '../l10n/app_localizations.dart';

class ExtensionLogsPage extends ConsumerWidget {
  const ExtensionLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final logs = ref.watch(extensionLogProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: Text(l10n.extensionLogsTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  ref.read(extensionLogProvider.notifier).clearLogs();
                },
              ),
            ],
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final log = logs[index];
                  return _buildLogItem(context, log);
                }, childCount: logs.length),
              ),
            ),
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
                          Text(
                            log.extensionName,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
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
                        log.params.isEmpty ? l10n.noParams : log.params.toString(),
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
                    _buildDetailRow(context, l10n.extensionNameLabel, log.extensionName),
                    _buildDetailRow(context, l10n.extensionIdLabel, log.extensionId),
                    _buildDetailRow(context, l10n.methodLabel, log.method),
                    _buildDetailRow(context, l10n.timeLabel, fullTimeStr),
                    _buildDetailRow(context, l10n.statusLabel, log.success ? l10n.successLabel : l10n.failedLabel),
                    _buildDetailRow(
                      context,
                      l10n.accessModeLabel,
                      log.isUntrusted ? l10n.restrictedAccessIntercepted : l10n.trustedModePassthrough,
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
}
