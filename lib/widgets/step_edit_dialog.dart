import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

Future<void> showStepEditDialog({
  required BuildContext context,
  required String initialDescription,
  required void Function(String newDescription) onSaved,
  void Function()? onDeleted,
  String? hintText,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final controller = TextEditingController(text: initialDescription);
  controller.selection = TextSelection.fromPosition(
    TextPosition(offset: controller.text.length),
  );

  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(l10n.edit),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            minLines: 1,
            decoration: InputDecoration(
              hintText: hintText ?? l10n.stepDescription,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHigh,
              prefixIcon: const Icon(Icons.checklist_rounded, size: 20),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        controller.clear();
                        setDialogState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onChanged: (_) => setDialogState(() {}),
          ),
          actions: [
            if (onDeleted != null)
              TextButton.icon(
                onPressed: () {
                  onDeleted();
                  Navigator.pop(dialogContext);
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(l10n.delete),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final newDescription = controller.text.trim();
                if (newDescription.isNotEmpty) {
                  onSaved(newDescription);
                }
                Navigator.pop(dialogContext);
              },
              child: Text(l10n.confirm),
            ),
          ],
        );
      },
    ),
  );
}
