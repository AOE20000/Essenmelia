import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tags_provider.dart';

class TagInput extends ConsumerStatefulWidget {
  final List<String> initialTags;
  final List<String> recommendedTags;
  final Function(List<String>) onChanged;

  const TagInput({
    super.key,
    required this.initialTags,
    this.recommendedTags = const [],
    required this.onChanged,
  });

  @override
  ConsumerState<TagInput> createState() => _TagInputState();
}

class _TagInputState extends ConsumerState<TagInput> {
  late List<String> _selectedTags;
  final TextEditingController _controller = TextEditingController();
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _selectedTags = List.from(widget.initialTags);
    _controller.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onSearchChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _controller.text;
    final value = _controller.value;

    // 如果处于输入法组合输入状态（如拼音输入中），不进行自动分词
    if (value.composing.isValid) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    // 如果输入包含空格，则进行批量添加
    if (text.contains(' ')) {
      final parts = text.split(' ');
      // 最后一个可能还没输完，保留它
      final tagsToAdd = parts.sublist(0, parts.length - 1);
      final remaining = parts.last;

      bool changed = false;
      for (final tag in tagsToAdd) {
        final cleanTag = tag.trim();
        if (cleanTag.isNotEmpty && !_selectedTags.contains(cleanTag)) {
          _selectedTags.add(cleanTag);
          changed = true;
        }
      }

      if (changed) {
        setState(() {
          _controller.text = remaining;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: remaining.length),
          );
        });
        widget.onChanged(_selectedTags);
      }
    }

    final query = _controller.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final allTags = ref.read(tagsProvider).value ?? [];
    setState(() {
      _suggestions = allTags.where((tag) {
        return tag.toLowerCase().contains(query) &&
            !_selectedTags.contains(tag);
      }).toList();
      _showSuggestions = true;
    });
  }

  void _addTag(String tag) {
    final cleanTag = tag.trim();
    if (cleanTag.isEmpty) return;

    if (!_selectedTags.contains(cleanTag)) {
      setState(() {
        _selectedTags.add(cleanTag);
        _controller.clear();
        _suggestions = [];
        _showSuggestions = false;
      });
      widget.onChanged(_selectedTags);

      // Note: We no longer call ref.read(tagsProvider.notifier).addTag(cleanTag) immediately here.
      // It's handled collectively during the save process.
    } else {
      _controller.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
    widget.onChanged(_selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    final availableRecommendations = widget.recommendedTags
        .where((tag) => !_selectedTags.contains(tag))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTags.asMap().entries.map((entry) {
              final index = entry.key;
              final tag = entry.value;
              return Chip(
                key: ValueKey('tag_${tag}_$index'),
                label: Text(tag, style: const TextStyle(fontSize: 12)),
                onDeleted: () => _removeTag(tag),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              );
            }).toList(),
          ),
        ),
        if (availableRecommendations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)!.recommendedTags,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: availableRecommendations.map((tag) {
                    return ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      onPressed: () => _addTag(tag),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.tags,
            hintText: AppLocalizations.of(context)!.tagsPlaceholder,
            prefixIcon: const Icon(Icons.tag),
          ),
          onSubmitted: _addTag,
        ),

        if (_showSuggestions)
          Card(
            margin: const EdgeInsets.only(top: 4),
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  if (_suggestions.isEmpty)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: Text(
                        AppLocalizations.of(
                          context,
                        )!.createTag(_controller.text),
                      ),
                      onTap: () => _addTag(_controller.text),
                    )
                  else
                    ..._suggestions.map(
                      (tag) => ListTile(
                        leading: const Icon(Icons.label_outline),
                        title: Text(tag),
                        onTap: () => _addTag(tag),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
