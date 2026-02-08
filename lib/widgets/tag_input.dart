import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tags_provider.dart';

class TagInput extends ConsumerStatefulWidget {
  final List<String> initialTags;
  final Function(List<String>) onChanged;

  const TagInput({
    super.key,
    required this.initialTags,
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
    final query = _controller.text.toLowerCase();
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
      _showSuggestions = true; // Always show if there is text, even if 0 suggestions (to allow creating)
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
      
      // Auto-add to global list
      ref.read(tagsProvider.notifier).addTag(cleanTag);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedTags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTags.map((tag) {
                return Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                );
              }).toList(),
            ),
          ),
        
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Tags',
            hintText: 'Type to search or create...',
            prefixIcon: Icon(Icons.tag),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(),
          ),
          onSubmitted: _addTag,
        ),
        
        if (_showSuggestions)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                if (_suggestions.isEmpty)
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text('Create "${_controller.text}"'),
                    onTap: () => _addTag(_controller.text),
                  )
                else
                  ..._suggestions.map((tag) => ListTile(
                    leading: const Icon(Icons.label_outline),
                    title: Text(tag),
                    onTap: () => _addTag(tag),
                  )),
              ],
            ),
          ),
      ],
    );
  }
}
