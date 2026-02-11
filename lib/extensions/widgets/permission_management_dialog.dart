import 'package:flutter/material.dart';

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

  List<Map<String, dynamic>> _getLevels(bool isEn) {
    return [
      {
        'label': isEn ? 'Deny Access' : '拒绝访问',
        'description': isEn
            ? 'Provides no data, which may cause errors or limited functionality.'
            : '不提供任何数据，可能导致扩展报错或功能受限。',
        'decision': PermissionManagementDecision.deny,
        'color': Colors.red,
        'icon': Icons.block_flipped,
      },
      {
        'label': isEn ? 'Allow Once' : '仅允许一次',
        'description': isEn
            ? 'Provides real data only for this specific request.'
            : '仅针对本次特定的数据请求提供真实数据。',
        'decision': PermissionManagementDecision.allowOnce,
        'color': Colors.orange,
        'icon': Icons.looks_one_outlined,
      },
      {
        'label': isEn ? 'Allow Next Time' : '仅下次允许',
        'description': isEn
            ? 'Intercepts now, but automatically allows the next time this access occurs.'
            : '本次保持拦截，但下次该扩展再次尝试此类访问时将自动通过。',
        'decision': PermissionManagementDecision.allowNextRun,
        'color': Colors.blue,
        'icon': Icons.fast_forward_outlined,
      },
      {
        'label': isEn ? 'Allow Category (Session)' : '本次运行时允许该类',
        'description': isEn
            ? 'Allows all access to this category until the app is closed.'
            : '在应用关闭前，允许该扩展访问所有此类数据。',
        'decision': PermissionManagementDecision.allowCategoryOnce,
        'color': Colors.indigo,
        'icon': Icons.category_outlined,
      },
      {
        'label': isEn ? 'Allow All (Session)' : '本次运行时全部允许',
        'description': isEn
            ? 'Allows all permissions for this extension until the app is closed.'
            : '在应用关闭前，对该扩展开放所有权限，不再弹窗询问。',
        'decision': PermissionManagementDecision.allowAllOnce,
        'color': Colors.purple,
        'icon': Icons.security_outlined,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final isEn = locale?.languageCode == 'en';
    final levels = _getLevels(isEn);
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
                ? (isEn ? 'Access Intercepted' : '拦截了一次访问')
                : (isEn ? 'Untrusted Extension' : '此拓展不受信任'),
          ),
        ],
      ),
      content: SizedBox(
        width: 300, // 固定宽度防止横向抖动
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: theme.textTheme.bodyLarge,
                children: [
                  TextSpan(text: isEn ? 'Extension ' : '拓展 '),
                  TextSpan(
                    text: widget.extensionName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: widget.isPostHoc
                        ? (isEn ? ' just tried to:' : ' 刚才尝试：')
                        : (isEn ? ' wants to:' : ' 想要：'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isPostHoc
                    ? theme.colorScheme.primaryContainer.withOpacity(0.3)
                    : theme.colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isPostHoc
                      ? theme.colorScheme.primary.withOpacity(0.2)
                      : theme.colorScheme.error.withOpacity(0.2),
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
            // 滑动条区域
            Center(
              child: Column(
                children: [
                  SizedBox(
                    height: 28, // 固定标签高度
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
                    height: 40, // 固定描述高度，防止文字换行引起抖动
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
                      activeTrackColor: currentLevel['color'].withOpacity(0.5),
                      thumbColor: currentLevel['color'],
                      overlayColor: currentLevel['color'].withOpacity(0.2),
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
            child: Text(isEn ? 'Confirm Choice' : '确认选择'),
          ),
        ),
      ],
    );
  }
}
