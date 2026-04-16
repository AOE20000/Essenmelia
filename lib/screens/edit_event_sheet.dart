import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../providers/tags_provider.dart';
import '../widgets/tag_input.dart';
import '../widgets/batch_edit_tags_sheet.dart';
import '../widgets/universal_image.dart';
import '../providers/ui_state_provider.dart';
import '../features/quick_action/ocr_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../features/quick_action/contour_service.dart';

class EditEventSheet extends ConsumerStatefulWidget {
  final Event? event;
  final bool isSidePanel;
  const EditEventSheet({super.key, this.event, this.isSidePanel = false});

  @override
  ConsumerState<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends ConsumerState<EditEventSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _suffixController;
  late TextEditingController _reminderRepeatController;
  String? _currentImageUrl;
  List<String> _selectedTags = [];
  List<String> _recommendedTags = [];
  bool _isSaving = false;
  String _stepDisplayMode = 'hierarchy';
  List<EventReminder> _reminders = [];

  // ML 状态
  final OcrService _ocrService = OcrService();
  final ContourService _contourService = ContourService();
  bool _isProcessingML = false;
  List<String> _croppedImagePaths = [];
  String? _recognizedText;
  bool _wasAutoFilled = false; // 新增：标记是否发生了自动填充
  TextRecognitionScript _selectedOcrScript = TextRecognitionScript.chinese;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descController = TextEditingController(
      text: widget.event?.description ?? '',
    );
    _suffixController = TextEditingController(
      text: widget.event?.stepSuffix ?? '',
    );
    _reminderRepeatController = TextEditingController(
      text: '${widget.event?.reminderRepeatValue ?? 1}',
    );
    _currentImageUrl = widget.event?.imageUrl;
    _selectedTags = widget.event?.tags ?? [];
    _stepDisplayMode = _normalizeStepDisplayMode(widget.event?.stepDisplayMode);

    // Initialize reminders from event
    if (widget.event != null) {
      if ((widget.event!.reminders ?? []).isNotEmpty) {
        _reminders = widget.event!.reminders!
            .map((r) => EventReminder.fromJson(r.toJson()))
            .toList();
      } else if (widget.event!.reminderTime != null) {
        // Migration: convert old single reminder to new list
        final r = EventReminder()
          ..time = widget.event!.reminderTime!
          ..recurrence = widget.event!.reminderRecurrence ?? 'none'
          ..scheme = widget.event!.reminderScheme ?? 'notification'
          ..repeatValue = widget.event!.reminderRepeatValue
          ..repeatUnit = widget.event!.reminderRepeatUnit
          ..calendarEventId = widget.event!.calendarEventId;
        _reminders = [r];
      }
    }

    _titleController.addListener(_updateRecommendations);
    _descController.addListener(_updateRecommendations);

    // 初始推荐
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateRecommendations(),
    );
  }

  String _normalizeStepDisplayMode(String? mode) {
    return switch (mode) {
      null => 'hierarchy',
      'number' => 'hierarchy',
      'firstChar' => 'hierarchyFirstChar',
      'slider' => 'slider',
      'hierarchy' => 'hierarchy',
      'hierarchyFirstChar' => 'hierarchyFirstChar',
      _ => 'hierarchy',
    };
  }

  Widget _buildAdvancedSettingsButton(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showAdvancedSettings(theme),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_suggest_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.advancedSettingsAndReminders,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.advancedSettingsSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_reminders.isNotEmpty)
                Badge(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  label: Text(
                    '${_reminders.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAdvancedSettings(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 1.0,
              expand: false,
              builder: (context, scrollController) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Text(
                          l10n.advancedSettings,
                          style: theme.textTheme.headlineSmall?.copyWith(
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
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildStepDisplaySettingsInModal(theme, setModalState),
                        const SizedBox(height: 32),
                        _buildReminderSectionInModal(theme, setModalState),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      12 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(l10n.finishSettings),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepDisplaySettingsInModal(
    ThemeData theme,
    StateSetter setModalState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.settings_suggest_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.displaySettings,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.stepMarkerMode,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'hierarchy',
                      label: Text(l10n.markerHierarchy),
                      icon: const Icon(Icons.account_tree_outlined),
                    ),
                    ButtonSegment(
                      value: 'slider',
                      label: Text(l10n.markerSlider),
                      icon: const Icon(Icons.linear_scale),
                    ),
                  ],
                  selected: {
                    _stepDisplayMode == 'hierarchyFirstChar'
                        ? 'hierarchy'
                        : _stepDisplayMode,
                  },
                  onSelectionChanged: (Set<String> newSelection) {
                    setModalState(() {
                      final selectedMode = newSelection.first;
                      if (selectedMode == 'hierarchy') {
                        // 保留“分层+首字”子模式，不在切回分层时丢失
                        _stepDisplayMode = _stepDisplayMode == 'hierarchyFirstChar'
                            ? 'hierarchyFirstChar'
                            : 'hierarchy';
                      } else {
                        _stepDisplayMode = selectedMode;
                      }
                    });
                    setState(() {}); // 同步到外部状态
                  },
                ),
              ),
              if (_stepDisplayMode == 'hierarchy' ||
                  _stepDisplayMode == 'hierarchyFirstChar') ...[
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.markerFirstChar),
                  subtitle: Text(l10n.hierarchyFirstCharSubtitle),
                  value: _stepDisplayMode == 'hierarchyFirstChar',
                  onChanged: (enabled) {
                    setModalState(() {
                      _stepDisplayMode = enabled
                          ? 'hierarchyFirstChar'
                          : 'hierarchy';
                    });
                    setState(() {});
                  },
                ),
              ],
              const SizedBox(height: 20),
              Text(
                l10n.customCountSuffix,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Autocomplete<String>(
                    initialValue: TextEditingValue(
                      text: _suffixController.text,
                    ),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final events = ref.read(eventsProvider).value ?? [];
                      final suffixes = events
                          .map((e) => e.stepSuffix)
                          .where((s) => s != null && s.isNotEmpty)
                          .cast<String>()
                          .toSet()
                          .toList();

                      if (textEditingValue.text.isEmpty) {
                        return suffixes;
                      }
                      return suffixes.where((String option) {
                        return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        );
                      });
                    },
                    onSelected: (String selection) {
                      _suffixController.text = selection;
                      setState(() {});
                    },
                    fieldViewBuilder:
                        (
                          BuildContext context,
                          TextEditingController fieldTextEditingController,
                          FocusNode fieldFocusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          return TextField(
                            controller: fieldTextEditingController,
                            focusNode: fieldFocusNode,
                            onChanged: (value) {
                              _suffixController.text = value;
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: l10n.suffixHint,
                              prefixIcon: const Icon(Icons.label_outline),
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          );
                        },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: constraints.maxWidth,
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () {
                                    onSelected(option);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      option,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                l10n.suffixDefaultTip,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReminderSectionInModal(
    ThemeData theme,
    StateSetter setModalState,
  ) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.scheduledReminders,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton.filledTonal(
              onPressed: () => _addReminder(setModalState),
              icon: const Icon(Icons.add, size: 20),
              tooltip: l10n.addReminder,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_reminders.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                l10n.noReminderSet,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          )
        else
          ..._reminders.asMap().entries.map((entry) {
            final index = entry.key;
            final reminder = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: InkWell(
                  onTap: () => _editReminder(index, setModalState),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getReminderDescription(l10n, reminder),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reminder.scheme == 'calendar'
                                    ? l10n.systemCalendar
                                    : l10n.inAppNotification,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                          ),
                          onPressed: () {
                            setModalState(() {
                              _reminders.removeAt(index);
                            });
                            setState(() {});
                          },
                          color: theme.colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  void _addReminder(StateSetter setModalState) {
    final newReminder = EventReminder()
      ..time = DateTime.now().add(const Duration(minutes: 30));
    // Round to next 5 minutes
    newReminder.time = newReminder.time.subtract(
      Duration(
        minutes: newReminder.time.minute % 5,
        seconds: newReminder.time.second,
      ),
    );

    _showReminderEditor(newReminder, (updated) {
      setModalState(() {
        _reminders.add(updated);
      });
      setState(() {});
    });
  }

  void _editReminder(int index, StateSetter setModalState) {
    final reminder = _reminders[index];
    // Create a copy for editing
    final copy = EventReminder.fromJson(reminder.toJson());

    _showReminderEditor(copy, (updated) {
      setModalState(() {
        _reminders[index] = updated;
      });
      setState(() {});
    });
  }

  void _showReminderEditor(
    EventReminder reminder,
    Function(EventReminder) onSave,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Local state for the editor
    DateTime editTime = reminder.time;
    String editRecurrence = reminder.recurrence;
    String editScheme = reminder.scheme;
    int? editRepeatValue = reminder.repeatValue ?? 1;
    String? editRepeatUnit = reminder.repeatUnit ?? 'day';
    int? editTotalCycles = reminder.totalCycles;

    final repeatController = TextEditingController(text: '$editRepeatValue');
    final cycleController = TextEditingController(
      text: editTotalCycles != null ? '$editTotalCycles' : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setEditorState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.editEvent,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Time Picker
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () async {
                        final picked = await _pickDateTime(editTime);
                        if (picked != null) {
                          setEditorState(() => editTime = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                DateFormat.yMMMd(
                                  Localizations.localeOf(
                                    modalContext,
                                  ).toString(),
                                ).add_Hm().format(editTime),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 20,
                              color: theme.colorScheme.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(l10n.reminderScheme, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'notification',
                          label: Text(l10n.inAppNotification),
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                        ButtonSegment(
                          value: 'calendar',
                          label: Text(l10n.systemCalendar),
                          icon: const Icon(Icons.calendar_today_outlined),
                        ),
                      ],
                      selected: {editScheme},
                      onSelectionChanged: (val) =>
                          setEditorState(() => editScheme = val.first),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(l10n.repeatCycle, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 12),
                  // Standard Recurrence (SegmentedButton as requested)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'none',
                          label: Text(l10n.noRepeat),
                        ),
                        ButtonSegment(value: 'daily', label: Text(l10n.daily)),
                        ButtonSegment(
                          value: 'weekly',
                          label: Text(l10n.weekly),
                        ),
                        ButtonSegment(
                          value: 'monthly',
                          label: Text(l10n.monthly),
                        ),
                        ButtonSegment(
                          value: 'yearly',
                          label: Text(l10n.yearly),
                        ),
                        ButtonSegment(
                          value: 'custom',
                          label: Text(l10n.custom),
                        ),
                      ],
                      selected: {editRecurrence},
                      onSelectionChanged: (val) =>
                          setEditorState(() => editRecurrence = val.first),
                    ),
                  ),

                  if (editRecurrence == 'custom') ...[
                    const SizedBox(height: 16),
                    // Custom Interval Row (requested to be on its own row)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(l10n.repeatEvery),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: repeatController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (val) =>
                                  editRepeatValue = int.tryParse(val) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButton<String>(
                              value: editRepeatUnit,
                              underline: const SizedBox(),
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: 'minute',
                                  child: Text(l10n.minutes),
                                ),
                                DropdownMenuItem(
                                  value: 'hour',
                                  child: Text(l10n.hours),
                                ),
                                DropdownMenuItem(
                                  value: 'day',
                                  child: Text(l10n.days),
                                ),
                                DropdownMenuItem(
                                  value: 'week',
                                  child: Text(l10n.weeks),
                                ),
                                DropdownMenuItem(
                                  value: 'month',
                                  child: Text(l10n.months),
                                ),
                                DropdownMenuItem(
                                  value: 'year',
                                  child: Text(l10n.years),
                                ),
                              ],
                              onChanged: (val) =>
                                  setEditorState(() => editRepeatUnit = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (editRecurrence != 'none') ...[
                    const SizedBox(height: 24),
                    Text(
                      '${l10n.cycleCount} (${l10n.infinite})',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cycleController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '例如: 10',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.loop_rounded),
                      ),
                      onChanged: (val) => editTotalCycles = int.tryParse(val),
                    ),
                  ],

                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () {
                      reminder.time = editTime;
                      reminder.recurrence = editRecurrence;
                      reminder.scheme = editScheme;
                      reminder.repeatValue = editRepeatValue;
                      reminder.repeatUnit = editRepeatUnit;
                      reminder.totalCycles = editTotalCycles;
                      onSave(reminder);
                      Navigator.pop(modalContext);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(l10n.confirm),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null) return null;

    if (!mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _getReminderDescription(
    AppLocalizations l10n,
    EventReminder reminder,
  ) {
    final timeStr = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_Hm().format(reminder.time);

    if (reminder.recurrence == 'none') {
      return timeStr;
    }

    String recurrenceStr = '';
    switch (reminder.recurrence) {
      case 'daily':
        recurrenceStr = l10n.daily;
        break;
      case 'weekly':
        recurrenceStr = l10n.weekly;
        break;
      case 'monthly':
        recurrenceStr = l10n.monthly;
        break;
      case 'yearly':
        recurrenceStr = l10n.yearly;
        break;
      case 'custom':
        if (reminder.repeatValue != null && reminder.repeatUnit != null) {
          String unitLabel = '';
          switch (reminder.repeatUnit) {
            case 'minute':
              unitLabel = l10n.minutes;
              break;
            case 'hour':
              unitLabel = l10n.hours;
              break;
            case 'day':
              unitLabel = l10n.days;
              break;
            case 'week':
              unitLabel = l10n.weeks;
              break;
            case 'month':
              unitLabel = l10n.months;
              break;
            case 'year':
              unitLabel = l10n.years;
              break;
          }
          recurrenceStr =
              '${l10n.repeatEvery} ${reminder.repeatValue} $unitLabel';
        } else {
          recurrenceStr = l10n.custom;
        }
        break;
    }

    String result = '$timeStr ($recurrenceStr)';
    if (reminder.totalCycles != null && reminder.totalCycles! > 0) {
      result += ' · ${reminder.currentCycle ?? 0}/${reminder.totalCycles}';
    }
    return result;
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateRecommendations);
    _descController.removeListener(_updateRecommendations);
    _titleController.dispose();
    _descController.dispose();
    _suffixController.dispose();
    _reminderRepeatController.dispose();
    _ocrService.dispose();
    _contourService.dispose();
    super.dispose();
  }

  void _updateRecommendations() {
    final title = _titleController.text.toLowerCase();
    final desc = _descController.text.toLowerCase();
    final ocr = (_recognizedText ?? '').toLowerCase();
    final combined = '$title $desc $ocr';

    if (combined.trim().isEmpty) {
      if (_recommendedTags.isNotEmpty) {
        setState(() => _recommendedTags = []);
      }
      return;
    }

    final allTags = ref.read(tagsProvider).value ?? [];
    final recommendations = allTags.where((tag) {
      return combined.contains(tag.toLowerCase()) &&
          !_selectedTags.contains(tag);
    }).toList();

    if (recommendations.length != _recommendedTags.length ||
        !recommendations.every((t) => _recommendedTags.contains(t))) {
      setState(() => _recommendedTags = recommendations);
    }
  }

  void _clearImage() {
    setState(() {
      _currentImageUrl = null;
    });
  }

  Future<void> _handleImageFile(File file) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() {
        _isProcessingML = true;
        _croppedImagePaths = [];
      });

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'event_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          'event_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path)}';
      final savedPath = p.join(imagesDir.path, fileName);

      await file.copy(savedPath);

      setState(() {
        _currentImageUrl = savedPath;
      });

      // 默认不再启动 ML 处理，由用户手动点击触发
    } catch (e) {
      debugPrint('Error handling image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.processingImageFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingML = false);
    }
  }

  Future<void> _processImageML(
    File imageFile, {
    TextRecognitionScript? script,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    if (!Platform.isAndroid && !Platform.isIOS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.featureNotSupportedOnDesktop)),
        );
      }
      return;
    }

    if (script != null) {
      _selectedOcrScript = script;
    }

    setState(() => _isProcessingML = true);
    try {
      // 1. OCR 识别
      final textResult = await _ocrService.recognizeDetailed(
        imageFile.path,
        script: _selectedOcrScript,
      );
      final blocks = textResult['blocks'] as List<Map<String, dynamic>>;

      // 2. 物体检测与裁切
      final objectsResult = await _contourService.detectObjects(imageFile.path);
      final List<String> croppedPaths = [];

      final bytes = await imageFile.readAsBytes();
      img.Image? baseImage = img.decodeImage(bytes);

      if (baseImage != null) {
        baseImage = img.bakeOrientation(baseImage);
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(appDir.path, 'event_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final objects = objectsResult['objects'] as List<Map<String, dynamic>>;

        for (int i = 0; i < objects.length; i++) {
          final rect = objects[i]['rect'];
          final left = rect['left'].toInt().clamp(0, baseImage.width - 1);
          final top = rect['top'].toInt().clamp(0, baseImage.height - 1);
          final right = rect['right'].toInt().clamp(1, baseImage.width);
          final bottom = rect['bottom'].toInt().clamp(1, baseImage.height);

          int width = right - left;
          int height = bottom - top;

          if (width > 50 && height > 50) {
            final cropped = img.copyCrop(
              baseImage,
              x: left,
              y: top,
              width: width,
              height: height,
            );

            final croppedFile = File(
              p.join(
                imagesDir.path,
                'crop_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
              ),
            );
            await croppedFile.writeAsBytes(img.encodeJpg(cropped, quality: 85));
            croppedPaths.add(croppedFile.path);
          }
        }
      }

      if (mounted) {
        setState(() {
          _recognizedText = textResult['fullText'] as String;
          _croppedImagePaths = croppedPaths;
          // 重新计算标签推荐
          _updateRecommendations();
        });

        // 所有分析完成后再显示选择器，确保数据完整
        if (blocks.isNotEmpty || croppedPaths.isNotEmpty) {
          _showOcrResultPicker(imageFile, blocks);
        }
      }
    } catch (e) {
      debugPrint('ML Processing error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingML = false);
    }
  }

  void _showOcrResultPicker(
    File originalFile,
    List<Map<String, dynamic>> blocks,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // 本地暂存状态
    String tempImageUrl = _currentImageUrl ?? originalFile.path;
    String tempTitle = _titleController.text;
    String tempDescription = _descController.text;
    final Set<int> selectedBlockIndices = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverAppBar(
                        automaticallyImplyLeading: false,
                        pinned: true,
                        backgroundColor: theme.colorScheme.surface,
                        surfaceTintColor: theme.colorScheme.surfaceTint,
                        title: Text(
                          l10n.smartAnalysis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        actions: [
                          PopupMenuButton<TextRecognitionScript>(
                            tooltip: l10n.retryWithOtherLanguage,
                            icon: const Icon(Icons.translate),
                            onSelected: (script) {
                              Navigator.pop(context);
                              _processImageML(originalFile, script: script);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: TextRecognitionScript.chinese,
                                child: Text(l10n.ocrLanguageChinese),
                              ),
                              PopupMenuItem(
                                value: TextRecognitionScript.japanese,
                                child: Text(l10n.ocrLanguageJapanese),
                              ),
                              PopupMenuItem(
                                value: TextRecognitionScript.latin,
                                child: Text(l10n.ocrLanguageLatin),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // 精彩画面标题
                            _buildSectionHeader(
                              theme,
                              l10n.brilliantMoments,
                              l10n.aiCrop,
                            ),
                            const SizedBox(height: 16),
                            // 图片选择器
                            SizedBox(
                              height: 140,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                children: [
                                  _buildPickerImageItem(
                                    theme,
                                    originalFile.path,
                                    l10n.fullOriginalImage,
                                    tempImageUrl,
                                    (path) => setModalState(
                                      () => tempImageUrl = path,
                                    ),
                                  ),
                                  ..._croppedImagePaths.map(
                                    (path) => Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: _buildPickerImageItem(
                                        theme,
                                        path,
                                        null,
                                        tempImageUrl,
                                        (path) => setModalState(
                                          () => tempImageUrl = path,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // 文字识别标题
                            _buildSectionHeader(theme, l10n.ocrResults, null),
                            const SizedBox(height: 8),
                            Text(
                              l10n.ocrSelectionTip,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 文字选择 Wrap
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(blocks.length, (index) {
                                final isSelected = selectedBlockIndices
                                    .contains(index);
                                return FilterChip(
                                      label: Text(
                                        (blocks[index]['text'] as String)
                                            .replaceAll('\n', ' ')
                                            .trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          if (selected) {
                                            selectedBlockIndices.add(index);
                                          } else {
                                            selectedBlockIndices.remove(index);
                                          }
                                          _updateTempText(
                                            blocks,
                                            selectedBlockIndices,
                                            (t, d) {
                                              tempTitle = t;
                                              tempDescription = d;
                                            },
                                          );
                                        });
                                      },
                                      showCheckmark: true,
                                    )
                                    .animate()
                                    .fadeIn(delay: (index * 30).ms)
                                    .scale(duration: 200.ms);
                              }),
                            ),

                            if (selectedBlockIndices.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setModalState(() {
                                      tempTitle = '';
                                      tempDescription = '';
                                      selectedBlockIndices.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: Text(l10n.resetOcrSelection),
                                  style: TextButton.styleFrom(
                                    foregroundColor: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // 预览区域
                            if (tempTitle.isNotEmpty ||
                                tempDescription.isNotEmpty) ...[
                              _buildSectionHeader(theme, l10n.appPreview, null),
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (tempTitle.isNotEmpty) ...[
                                      Text(
                                        tempTitle,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                      ),
                                      if (tempDescription.isNotEmpty)
                                        const SizedBox(height: 12),
                                    ],
                                    if (tempDescription.isNotEmpty)
                                      Text(
                                        tempDescription,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              height: 1.5,
                                            ),
                                      ),
                                  ],
                                ),
                              ).animate().fadeIn().slideY(begin: 0.1),
                            ],
                            const SizedBox(height: 40),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
                // 底部操作栏
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _currentImageUrl = tempImageUrl;
                              _titleController.text = tempTitle;
                              _descController.text = tempDescription;
                              _wasAutoFilled = true;
                            });
                            Navigator.pop(context);
                            _clearAutoFillFlag();
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(l10n.confirmApply),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateTempText(
    List<Map<String, dynamic>> blocks,
    Set<int> selectedIndices,
    void Function(String title, String desc) onUpdate,
  ) {
    if (selectedIndices.isEmpty) {
      onUpdate('', '');
      return;
    }
    // Don't sort, keep selection order
    final orderedIndices = selectedIndices.toList();
    final firstIndex = orderedIndices.first;
    final title = (blocks[firstIndex]['text'] as String)
        .replaceAll('\n', ' ')
        .trim();

    String desc = '';
    if (orderedIndices.length > 1) {
      desc = orderedIndices
          .skip(1)
          .map(
            (idx) =>
                (blocks[idx]['text'] as String).replaceAll('\n', ' ').trim(),
          )
          .join('\n');
    }
    onUpdate(title, desc);
  }

  Widget _buildSectionHeader(ThemeData theme, String title, String? badge) {
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPickerImageItem(
    ThemeData theme,
    String path,
    String? label,
    String currentPath,
    Function(String) onSelect,
  ) {
    final isSelected = currentPath == path;
    return GestureDetector(
      onTap: () => onSelect(path),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(path), fit: BoxFit.cover, cacheWidth: 220),
              if (label != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
            ],
          ),
        ),
      ),
    );
  }

  void _clearAutoFillFlag() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _wasAutoFilled = false);
    });
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    if (details.files.isNotEmpty) {
      final firstFile = details.files.first;
      final ext = p.extension(firstFile.path).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext)) {
        await _handleImageFile(File(firstFile.path));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.unsupportedFileFormat,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _pasteImage() async {
    debugPrint('Clipboard: Starting paste operation...');
    try {
      // 1. 尝试获取图片字节 (部分平台如 Android 0.3.0 可能未实现此方法)
      try {
        final bytes = await Pasteboard.image;
        if (bytes != null) {
          debugPrint('Clipboard: Got image bytes (${bytes.length})');
          final tempDir = await getTemporaryDirectory();
          final file = File(
            p.join(
              tempDir.path,
              'pasted_${DateTime.now().millisecondsSinceEpoch}.png',
            ),
          );
          await file.writeAsBytes(bytes);
          await _handleImageFile(file);
          return;
        }
      } catch (e) {
        debugPrint(
          'Clipboard: Failed to get image bytes (Platform may not support): $e',
        );
      }

      // 2. 尝试获取文件路径
      try {
        final files = await Pasteboard.files();
        if (files.isNotEmpty) {
          debugPrint('Clipboard: Got files: $files');
          final firstFile = files.first;
          final ext = p.extension(firstFile).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.webp', '.gif'].contains(ext)) {
            await _handleImageFile(File(firstFile));
            return;
          }
        }
      } catch (e) {
        debugPrint('Clipboard: Failed to get file: $e');
      }

      // 3. 尝试获取文本 (可能是图片 URL)
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text;
      if (text != null && text.isNotEmpty) {
        debugPrint('Clipboard: Got text: $text');
        if (text.startsWith('http') &&
            (text.toLowerCase().contains('.jpg') ||
                text.toLowerCase().contains('.jpeg') ||
                text.toLowerCase().contains('.png') ||
                text.toLowerCase().contains('.webp'))) {
          // 这是一个图片 URL，尝试下载
          await _downloadAndHandleImage(text);
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.noImageInClipboard),
          ),
        );
      }
    } catch (e) {
      debugPrint('Clipboard: Paste flow error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.pasteFailed(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadAndHandleImage(String url) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() => _isSaving = true);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          p.join(
            tempDir.path,
            'downloaded_${DateTime.now().millisecondsSinceEpoch}${p.extension(url).isEmpty ? '.jpg' : p.extension(url)}',
          ),
        );
        await file.writeAsBytes(response.bodyBytes);
        await _handleImageFile(file);
      } else {
        throw 'HTTP ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToGetImageFromLink(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _exportImage() async {
    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    try {
      String filePath;
      if (_currentImageUrl!.startsWith('http')) {
        setState(() => _isSaving = true);
        final response = await http.get(Uri.parse(_currentImageUrl!));
        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          final uri = Uri.parse(_currentImageUrl!);
          String extension = p.extension(uri.path);
          if (extension.isEmpty) extension = '.jpg';

          final fileName =
              'exported_${DateTime.now().millisecondsSinceEpoch}$extension';
          final file = File(p.join(tempDir.path, fileName));
          await file.writeAsBytes(response.bodyBytes);
          filePath = file.path;
        } else {
          throw 'HTTP ${response.statusCode}';
        }
      } else {
        filePath = _currentImageUrl!;
      }

      final file = File(filePath);
      if (await file.exists()) {
        await SharePlus.instance.share(
          ShareParams(text: l10n.exportImage, files: [XFile(file.path)]),
        );
      } else {
        throw 'File not found';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted && _isSaving) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        await _handleImageFile(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToPickImage(e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _showImageOptions() {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.pickFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: Text(l10n.pasteFromClipboard),
              onTap: () {
                Navigator.pop(context);
                _pasteImage();
              },
            ),
            if (_currentImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  l10n.clearImage,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clearImage();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleContentInsertion(KeyboardInsertedContent content) async {
    debugPrint('Keyboard: Received content insertion: ${content.mimeType}');
    if (content.data != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File(
          p.join(
            tempDir.path,
            'ime_inserted_${DateTime.now().millisecondsSinceEpoch}.png',
          ),
        );
        await file.writeAsBytes(content.data!);
        await _handleImageFile(file);
      } catch (e) {
        debugPrint('Keyboard: Failed to handle content insertion: $e');
      }
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      // Sync legacy fields with the first reminder for backward compatibility
      DateTime? legacyTime;
      String? legacyRecurrence;
      String? legacyScheme;
      int? legacyRepeatValue;
      String? legacyRepeatUnit;

      if (_reminders.isNotEmpty) {
        final r = _reminders.first;
        legacyTime = r.time;
        legacyRecurrence = r.recurrence;
        legacyScheme = r.scheme;
        legacyRepeatValue = r.repeatValue;
        legacyRepeatUnit = r.repeatUnit;
      }

      if (widget.event != null) {
        await ref
            .read(eventsProvider.notifier)
            .updateEvent(
              id: widget.event!.id,
              title: title,
              description: _descController.text.trim(),
              imageUrl: _currentImageUrl,
              tags: _selectedTags,
              stepDisplayMode: _stepDisplayMode,
              stepSuffix: _suffixController.text.trim().isEmpty
                  ? null
                  : _suffixController.text.trim(),
              reminderTime: legacyTime,
              reminderRecurrence: legacyRecurrence,
              reminderScheme: legacyScheme,
              reminderRepeatValue: legacyRepeatValue,
              reminderRepeatUnit: legacyRepeatUnit,
              reminders: _reminders.isEmpty ? null : _reminders,
            );
      } else {
        await ref
            .read(eventsProvider.notifier)
            .addEvent(
              title: title,
              description: _descController.text.trim(),
              imageUrl: _currentImageUrl,
              tags: _selectedTags,
              stepDisplayMode: _stepDisplayMode,
              stepSuffix: _suffixController.text.trim().isEmpty
                  ? null
                  : _suffixController.text.trim(),
              reminderTime: legacyTime,
              reminderRecurrence: legacyRecurrence,
              reminderScheme: legacyScheme,
              reminderRepeatValue: legacyRepeatValue,
              reminderRepeatUnit: legacyRepeatUnit,
              reminders: _reminders.isEmpty ? null : _reminders,
            );
      }

      if (mounted) {
        if (widget.isSidePanel) {
          ref.read(leftPanelContentProvider.notifier).state =
              LeftPanelContent.none;
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('EditEventSheet: Save failed: $e');
      if (mounted) {
        final localL10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localL10n.error(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildImageArea(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _showImageOptions,
      onLongPress: _currentImageUrl != null ? _exportImage : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28), // MD3 Card radius
          boxShadow: _currentImageUrl != null
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_currentImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    UniversalImage(
                      imageUrl: _currentImageUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ).animate().fadeIn(duration: 400.ms),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.2),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                            stops: const [0.0, 0.2, 0.7, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 32,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ).animate().scale(
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.addStoryImage,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.imageUploadTip,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            if (_isProcessingML)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      color: theme.colorScheme.surface.withValues(alpha: 0.4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                                l10n.analyzingContent,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              )
                              .animate(
                                onPlay: (controller) => controller.repeat(),
                              )
                              .shimmer(
                                duration: 1500.ms,
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (_currentImageUrl != null)
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filledTonal(
                  onPressed: _clearImage,
                  icon: const Icon(Icons.close, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withValues(
                      alpha: 0.8,
                    ),
                  ),
                ),
              ),

            Positioned(
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  if (_currentImageUrl != null) ...[
                    _ImageActionButton(
                      icon: Icons.auto_awesome,
                      onPressed: () => _processImageML(File(_currentImageUrl!)),
                      tooltip: l10n.smartAnalysisTooltip,
                    ),
                    const SizedBox(width: 8),
                    _ImageActionButton(
                      icon: Icons.ios_share,
                      onPressed: _exportImage,
                      tooltip: l10n.exportOriginalImage,
                    ),
                  ],
                  const SizedBox(width: 8),
                  _ImageActionButton(
                    icon: Icons.content_paste,
                    onPressed: _pasteImage,
                    tooltip: l10n.pasteFromClipboard,
                  ),
                  const SizedBox(width: 8),
                  _ImageActionButton(
                    icon: Icons.photo_library,
                    onPressed: _pickImage,
                    tooltip: l10n.pickFromGallery,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFields(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Field - Large and bold, but within a container to define the text area
        TextField(
          controller: _titleController,
          contentInsertionConfiguration: ContentInsertionConfiguration(
            onContentInserted: _handleContentInsertion,
            allowedMimeTypes: const [
              'image/png',
              'image/jpeg',
              'image/gif',
              'image/webp',
            ],
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
          decoration: InputDecoration(
            hintText: l10n.title,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              fontWeight: FontWeight.bold,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            suffixIcon: _wasAutoFilled
                ? Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Tooltip(
                      message: l10n.autoFilledByAi,
                      child: Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  )
                : null,
          ),
        ),

        // Description Field - Integrated with title via border
        TextField(
          controller: _descController,
          maxLines: null,
          minLines: 5,
          contentInsertionConfiguration: ContentInsertionConfiguration(
            onContentInserted: _handleContentInsertion,
            allowedMimeTypes: const [
              'image/png',
              'image/jpeg',
              'image/gif',
              'image/webp',
            ],
          ),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.6,
          ),
          decoration: InputDecoration(
            hintText: l10n.description,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          ),
        ),
      ],
    );
  }

  Widget _buildTagSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.label_outline,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.tags,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.event != null)
              TextButton.icon(
                onPressed: () => _showBatchEditTags(context),
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(l10n.batchEditTags),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TagInput(
          initialTags: _selectedTags,
          recommendedTags: _recommendedTags,
          onChanged: (tags) {
            setState(() => _selectedTags = tags);
            _updateRecommendations();
          },
        ),
      ],
    );
  }

  void _showBatchEditTags(BuildContext context) async {
    if (widget.event == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BatchEditTagsSheet(selectedIds: {widget.event!.id}),
    );

    // After closing, refresh local tags from the updated event in the database
    if (mounted) {
      final events = ref.read(eventsProvider).value ?? [];
      final updatedEvent = events.cast<Event?>().firstWhere(
        (e) => e?.id == widget.event!.id,
        orElse: () => null,
      );
      if (updatedEvent != null) {
        setState(() {
          _selectedTags = List<String>.from(updatedEvent.tags ?? []);
        });
        _updateRecommendations();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final l10n = AppLocalizations.of(context)!;

    final content = SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildImageArea(theme),
          const SizedBox(height: 32),
          _buildTextFields(theme),
          const SizedBox(height: 24),
          _buildAdvancedSettingsButton(theme),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 24),
          _buildTagSection(theme),
        ]),
      ),
    );

    final body = DropTarget(
      onDragDone: _handleDrop,
      child: CustomScrollView(
        slivers: [
          if (!widget.isSidePanel && !isDesktop)
            SliverAppBar.large(
              title: Text(
                widget.event == null ? l10n.newEvent : l10n.editEvent,
              ),
              actions: [
                if (!_isSaving)
                  IconButton(icon: const Icon(Icons.check), onPressed: _save),
              ],
            )
          else if (widget.isSidePanel)
            SliverAppBar(
              floating: true,
              pinned: true,
              title: Text(
                widget.event == null ? l10n.newEvent : l10n.editEvent,
              ),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(leftPanelContentProvider.notifier).state =
                        LeftPanelContent.none,
              ),
              actions: [
                if (!_isSaving)
                  IconButton(icon: const Icon(Icons.check), onPressed: _save),
              ],
            )
          else if (isDesktop)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                    child: Row(
                      children: [
                        Text(
                          widget.event == null ? l10n.newEvent : l10n.editEvent,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(
                            widget.event == null ? l10n.create : l10n.save,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
          content,
        ],
      ),
    );

    return Scaffold(
      backgroundColor: isDesktop
          ? Colors.transparent
          : theme.colorScheme.surface,
      body: isDesktop && !widget.isSidePanel
          ? Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: body,
            )
          : body,
      bottomNavigationBar: (!isDesktop || widget.isSidePanel)
          ? Container(
              padding: EdgeInsets.fromLTRB(
                24,
                12,
                24,
                12 + MediaQuery.of(context).viewPadding.bottom,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              widget.event == null ? Icons.add : Icons.check,
                            ),
                      label: Text(
                        widget.event == null
                            ? l10n.createRecord
                            : l10n.saveChanges,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().slideY(
              begin: 1,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            )
          : null,
    );
  }
}

class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _ImageActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
