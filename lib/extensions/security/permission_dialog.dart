import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

enum PermissionManagementDecision {
  allowOnce,
  allowCategoryOnce,
  allowAllOnce,
  allowNextRun,
  deny,
}

class PermissionManagementDialog extends StatefulWidget {
  final String extensionName;
  final String operationDescription;
  final String categoryName;
  final bool isPostHoc;

  const PermissionManagementDialog({
    super.key,
    required this.extensionName,
    required this.operationDescription,
    required this.categoryName,
    this.isPostHoc = false,
  });

  @override
  State<PermissionManagementDialog> createState() =>
      _PermissionManagementDialogState();
}

class _PermissionManagementDialogState
    extends State<PermissionManagementDialog> {
  double _sliderValue = 0;

  List<Map<String, dynamic>> _getLevels(AppLocalizations l10n) {
    return [
      {
        'label': l10n.extensionDecisionDeny,
        'description': l10n.extensionDecisionDenyDesc,
        'decision': PermissionManagementDecision.deny,
        'color': Colors.red,
        'icon': Icons.block_flipped,
      },
      {
        'label': l10n.extensionDecisionOnce,
        'description': l10n.extensionDecisionOnceDesc,
        'decision': PermissionManagementDecision.allowOnce,
        'color': Colors.orange,
        'icon': Icons.looks_one_outlined,
      },
      {
        'label': l10n.extensionDecisionNext,
        'description': l10n.extensionDecisionNextDesc,
        'decision': PermissionManagementDecision.allowNextRun,
        'color': Colors.blue,
        'icon': Icons.fast_forward_outlined,
      },
      {
        'label': l10n.extensionDecisionSessionCategory,
        'description': l10n.extensionDecisionSessionCategoryDesc,
        'decision': PermissionManagementDecision.allowCategoryOnce,
        'color': Colors.indigo,
        'icon': Icons.category_outlined,
      },
      {
        'label': l10n.extensionDecisionSessionAll,
        'description': l10n.extensionDecisionSessionAllDesc,
        'decision': PermissionManagementDecision.allowAllOnce,
        'color': Colors.purple,
        'icon': Icons.security_outlined,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final levels = _getLevels(l10n);
    final currentLevel = levels[_sliderValue.toInt()];

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isPostHoc
                ? Icons.security_rounded
                : Icons.warning_amber_rounded,
            color: widget.isPostHoc
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
          const SizedBox(width: 12),
          Text(
            widget.isPostHoc
                ? l10n.extensionInterceptedTitle
                : l10n.extensionRestrictedAccess,
          ),
        ],
      ),
      content: SizedBox(
        width: 300, // Fixed width
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge,
                children: [
                  TextSpan(
                    text: l10n.extensionInterceptedDesc(
                      widget.extensionName,
                      widget.isPostHoc
                          ? l10n.extensionInterceptedActionTried
                          : l10n.extensionInterceptedActionWants,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isPostHoc
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isPostHoc
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : theme.colorScheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 20,
                    color: widget.isPostHoc
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.operationDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: widget.isPostHoc
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Slider area
            Center(
              child: Column(
                children: [
                  SizedBox(
                    height: 28, // Fixed height
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          currentLevel['icon'],
                          color: currentLevel['color'],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentLevel['label'],
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: currentLevel['color'],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40, // Fixed height
                    child: Text(
                      currentLevel['description'],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: currentLevel['color'].withValues(
                        alpha: 0.5,
                      ),
                      thumbColor: currentLevel['color'],
                      overlayColor: currentLevel['color'].withValues(
                        alpha: 0.2,
                      ),
                      valueIndicatorColor: currentLevel['color'],
                    ),
                    child: Slider(
                      value: _sliderValue,
                      min: 0,
                      max: 4,
                      divisions: 4,
                      onChanged: (val) => setState(() => _sliderValue = val),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: FilledButton(
            onPressed: () => Navigator.pop(context, currentLevel['decision']),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              backgroundColor: currentLevel['color'],
            ),
            child: Text(l10n.extensionConfirmChoice),
          ),
        ),
      ],
    );
  }
}
