import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event.dart';
import '../providers/events_provider.dart';
import '../widgets/tag_input.dart';

import '../providers/ui_state_provider.dart';

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
  late TextEditingController _imageUrlController;
  List<String> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descController = TextEditingController(
      text: widget.event?.description ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.event?.imageUrl ?? '',
    );
    _selectedTags = widget.event?.tags ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    if (widget.event != null) {
      // Update existing
      // We need an updateEvent method in provider, but for now we can modify the Hive object directly
      // OR add updateEvent to provider.
      // Since Event extends HiveObject, we can just save it, BUT we need to notify listeners.
      // The EventsNotifier listens to the box, so saving the object should trigger updates.

      final event = widget.event!;
      event.title = title;
      event.description = _descController.text.trim();
      event.imageUrl = _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim();
      event.tags = _selectedTags;
      await event.save();
    } else {
      // Create new
      await ref
          .read(eventsProvider.notifier)
          .addEvent(
            title: title,
            description: _descController.text.trim(),
            imageUrl: _imageUrlController.text.trim().isEmpty
                ? null
                : _imageUrlController.text.trim(),
            tags: _selectedTags,
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
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64String = base64Encode(bytes);
        // Determine mime type roughly from extension or default to jpeg/png
        final mime = image.path.endsWith('.png') ? 'image/png' : 'image/jpeg';
        final dataUrl = 'data:$mime;base64,$base64String';

        setState(() {
          _imageUrlController.text = dataUrl;
        });
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.title,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.description,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _imageUrlController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.imageUrl,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.photo_library),
                onPressed: _pickImage,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TagInput(
            initialTags: _selectedTags,
            onChanged: (tags) => setState(() => _selectedTags = tags),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.event == null
                  ? AppLocalizations.of(context)!.createEvent
                  : AppLocalizations.of(context)!.saveChanges,
            ),
          ),
        ],
      ),
    );

    if (widget.isSidePanel || screenWidth < 1024) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.event == null
                ? AppLocalizations.of(context)!.newEvent
                : AppLocalizations.of(context)!.editEvent,
          ),
          centerTitle: widget.isSidePanel ? false : null,
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: widget.isSidePanel
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () =>
                      ref.read(leftPanelContentProvider.notifier).state =
                          LeftPanelContent.none,
                )
              : null,
          actions: [
            TextButton(
              onPressed: _save,
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        ),
        body: body,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: body,
    );
  }
}
