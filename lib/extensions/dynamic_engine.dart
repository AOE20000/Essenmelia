import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tags_provider.dart';
import 'base_extension.dart';

/// 动态 UI 渲染器与逻辑执行引擎 (Path B & C)
class DynamicEngine extends ConsumerStatefulWidget {
  final ExtensionMetadata metadata;
  final ExtensionApi api;
  final Function(void Function(String, Map<String, dynamic>))? onRegister;

  const DynamicEngine({
    super.key,
    required this.metadata,
    required this.api,
    this.onRegister,
  });

  @override
  ConsumerState<DynamicEngine> createState() => _DynamicEngineState();
}

class _DynamicEngineState extends ConsumerState<DynamicEngine> {
  final Map<String, dynamic> _state = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    widget.onRegister?.call(handleEvent);
    _initializeLogic();
  }

  void handleEvent(String name, Map<String, dynamic> data) {
    if (widget.metadata.logic != null) {
      final onEvent =
          widget.metadata.logic!['onEvent'] as Map<String, dynamic>?;
      if (onEvent != null && onEvent.containsKey(name)) {
        final actions = onEvent[name] as List?;
        if (actions != null) {
          for (var action in actions) {
            _executeAction(action, eventData: data);
          }
        }
      }
    }
  }

  Future<void> _initializeLogic() async {
    if (widget.metadata.logic != null) {
      final onLoad = widget.metadata.logic!['onLoad'] as List?;
      if (onLoad != null) {
        for (var action in onLoad) {
          await _executeAction(action);
        }
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _executeAction(
    dynamic actionDef, {
    Map<String, dynamic>? eventData,
  }) async {
    debugPrint('Executing action: $actionDef');
    if (actionDef is String) {
      // Named action reference
      final actions =
          widget.metadata.logic?['actions'] as Map<String, dynamic>?;
      final sequence = actions?[actionDef] as List?;
      if (sequence != null) {
        for (var step in sequence) {
          await _executeAction(step, eventData: eventData);
        }
      }
      return;
    }

    if (actionDef is! Map<String, dynamic>) return;

    // --- Control Flow ---
    if (actionDef.containsKey('if')) {
      final condition = _resolveValue(actionDef['if'], eventData: eventData);
      final isTrue =
          condition == true ||
          (condition is String && condition.toLowerCase() == 'true');
      final branch = isTrue ? actionDef['then'] : actionDef['else'];
      if (branch is List) {
        for (var step in branch) {
          await _executeAction(step, eventData: eventData);
        }
      } else if (branch != null) {
        await _executeAction(branch, eventData: eventData);
      }
      return;
    }

    if (actionDef.containsKey('for')) {
      final list = _resolveValue(actionDef['in'], eventData: eventData);
      final varName = actionDef['for'] as String;
      final actions = actionDef['do'];
      if (list is List && actions != null) {
        for (var item in list) {
          final localEventData = Map<String, dynamic>.from(eventData ?? {});
          localEventData[varName] = item;
          if (actions is List) {
            for (var step in actions) {
              await _executeAction(step, eventData: localEventData);
            }
          } else {
            await _executeAction(actions, eventData: localEventData);
          }
        }
      }
      return;
    }

    final call = actionDef['call'] as String?;
    final assignTo = actionDef['assignTo'] as String?;
    final params = actionDef['params'] as Map<String, dynamic>? ?? {};

    debugPrint('Calling: $call with params: $params');
    dynamic result;

    // API Calls mapping
    switch (call) {
      case 'api.getEvents':
        result = await widget.api.getEvents();
        debugPrint('Got events: ${result?.length}');
        break;
      case 'api.getTags':
        result = await widget.api.getTags();
        break;
      case 'api.showSnackBar':
        final msg = _resolveValue(params['message'], eventData: eventData);
        widget.api.showSnackBar(msg.toString());
        break;
      case 'api.showConfirmDialog':
        result = await widget.api.showConfirmDialog(
          title: _resolveValue(
            params['title'],
            eventData: eventData,
          ).toString(),
          message: _resolveValue(
            params['message'],
            eventData: eventData,
          ).toString(),
          confirmLabel:
              _resolveValue(
                params['confirmLabel'],
                eventData: eventData,
              )?.toString() ??
              '确定',
          cancelLabel:
              _resolveValue(
                params['cancelLabel'],
                eventData: eventData,
              )?.toString() ??
              '取消',
        );
        break;
      case 'api.navigateTo':
        widget.api.navigateTo(params['route']);
        break;
      case 'api.exportFile':
        final content = _resolveValue(
          params['content'],
          eventData: eventData,
        ).toString();
        final fileName = _resolveValue(
          params['fileName'],
          eventData: eventData,
        ).toString();
        result = await widget.api.exportFile(content, fileName);
        break;
      case 'api.pickFile':
        result = await widget.api.pickFile(
          allowedExtensions: (params['allowedExtensions'] as List?)
              ?.map((e) => e.toString())
              .toList(),
        );
        break;
      case 'api.httpGet':
        result = await widget.api.httpGet(
          _resolveValue(params['url'], eventData: eventData).toString(),
          headers: (params['headers'] as Map?)?.cast<String, String>(),
        );
        break;
      case 'api.httpPost':
        result = await widget.api.httpPost(
          _resolveValue(params['url'], eventData: eventData).toString(),
          headers: (params['headers'] as Map?)?.cast<String, String>(),
          body: _resolveValue(params['body'], eventData: eventData),
        );
        break;
      case 'api.httpPut':
        result = await widget.api.httpPut(
          _resolveValue(params['url'], eventData: eventData).toString(),
          headers: (params['headers'] as Map?)?.cast<String, String>(),
          body: _resolveValue(params['body'], eventData: eventData),
        );
        break;
      case 'api.httpDelete':
        result = await widget.api.httpDelete(
          _resolveValue(params['url'], eventData: eventData).toString(),
          headers: (params['headers'] as Map?)?.cast<String, String>(),
        );
        break;
      case 'api.openUrl':
        await widget.api.openUrl(
          _resolveValue(params['url'], eventData: eventData).toString(),
        );
        break;
      case 'api.publishEvent':
        widget.api.publishEvent(
          _resolveValue(params['name'], eventData: eventData).toString(),
          (_resolveValue(params['data'], eventData: eventData) as Map?)
                  ?.cast<String, dynamic>() ??
              {},
        );
        break;
      case 'api.setSearchQuery':
        widget.api.setSearchQuery(
          _resolveValue(params['query'], eventData: eventData).toString(),
        );
        break;
      case 'api.addEvent':
        await widget.api.addEvent(
          title: _resolveValue(
            params['title'],
            eventData: eventData,
          ).toString(),
          description: _resolveValue(
            params['description'],
            eventData: eventData,
          )?.toString(),
          tags: (params['tags'] as List?)?.map((e) => e.toString()).toList(),
        );
        break;
      case 'api.deleteEvent':
        await widget.api.deleteEvent(
          _resolveValue(params['id'], eventData: eventData).toString(),
        );
        break;
      case 'api.addStep':
        await widget.api.addStep(
          _resolveValue(params['eventId'], eventData: eventData).toString(),
          _resolveValue(params['description'], eventData: eventData).toString(),
        );
        break;
      case 'api.addTag':
        await widget.api.addTag(
          _resolveValue(params['tag'], eventData: eventData).toString(),
        );
        break;
      case 'api.getDbSize':
        result = await widget.api.getDbSize();
        break;
      case 'api.getThemeMode':
        result = widget.api.getThemeMode();
        break;
      case 'api.getLocale':
        result = widget.api.getLocale();
        break;
      case 'state.set':
        result = _resolveValue(params['value'], eventData: eventData);
        break;
      case 'list.length':
        final list = _resolveValue(params['list'], eventData: eventData);
        result = (list is List) ? list.length : 0;
        debugPrint('List length: $result');
        break;
    }

    if (assignTo != null) {
      debugPrint('Assigning result to state.$assignTo: $result');
      if (mounted) {
        setState(() {
          _state[assignTo] = result;
        });
      }
    }
  }

  dynamic _resolveValue(dynamic val, {Map<String, dynamic>? eventData}) {
    if (val is Map) {
      return val.map(
        (k, v) => MapEntry(k, _resolveValue(v, eventData: eventData)),
      );
    }
    if (val is List) {
      return val.map((e) => _resolveValue(e, eventData: eventData)).toList();
    }
    if (val is! String) return val;

    // 1. 处理 ${event.xxx}
    final eventRegex = RegExp(r'\$\{event\.([^\}]+)\}');
    final eventMatches = eventRegex.allMatches(val).toList();
    if (eventMatches.length == 1 && eventMatches.first.group(0) == val) {
      final key = eventMatches.first.group(1)!;
      return eventData?[key];
    }

    // 2. 处理 ${state.xxx}
    final stateRegex = RegExp(r'\$\{state\.([^\}]+)\}');
    final stateMatches = stateRegex.allMatches(val).toList();
    if (stateMatches.length == 1 && stateMatches.first.group(0) == val) {
      final key = stateMatches.first.group(1)!;
      return _state[key];
    }

    String result = val;
    // 3. 混合替换
    for (final match in eventMatches) {
      final fullMatch = match.group(0)!;
      final key = match.group(1)!;
      final val = eventData?[key];
      result = result.replaceFirst(fullMatch, _stringify(val));
    }
    for (final match in stateMatches) {
      final fullMatch = match.group(0)!;
      final key = match.group(1)!;
      final val = _state[key];
      result = result.replaceFirst(fullMatch, _stringify(val));
    }
    return result;
  }

  String _stringify(dynamic stateValue) {
    if (stateValue == null) return '';
    if (stateValue is String || stateValue is num || stateValue is bool) {
      return stateValue.toString();
    }
    try {
      return jsonEncode(
        stateValue,
        toEncodable: (nonEncodable) {
          try {
            return (nonEncodable as dynamic).toJson();
          } catch (_) {
            return nonEncodable.toString();
          }
        },
      );
    } catch (e) {
      return stateValue.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final viewDef = widget.metadata.view;
    if (viewDef == null) {
      return const Scaffold(body: Center(child: Text('此扩展未定义界面 (Path C)')));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(widget.metadata.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeLogic,
          ),
        ],
      ),
      body: _buildWidget(context, viewDef),
    );
  }

  Widget _buildWidget(
    BuildContext context,
    Map<String, dynamic> def, {
    Map<String, dynamic>? eventData,
  }) {
    final type = def['type'] as String?;
    final props = def['props'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'container':
        return Container(
          padding: _parseEdgeInsets(props['padding']),
          margin: _parseEdgeInsets(props['margin']),
          alignment: _parseAlignment(props['alignment']),
          decoration: _parseDecoration(props),
          width: (props['width'] as num?)?.toDouble(),
          height: (props['height'] as num?)?.toDouble(),
          child: _buildChild(context, def['child'], eventData: eventData),
        );
      case 'center':
        return Center(
          child: _buildChild(context, def['child'], eventData: eventData),
        );
      case 'padding':
        return Padding(
          padding: _parseEdgeInsets(props['padding'] ?? 8),
          child: _buildChild(context, def['child'], eventData: eventData),
        );
      case 'expanded':
        final child = _buildChild(context, def['child'], eventData: eventData);
        return Expanded(child: child ?? const SizedBox());
      case 'flexible':
        final child = _buildChild(context, def['child'], eventData: eventData);
        return Flexible(child: child ?? const SizedBox());
      case 'column':
        return Column(
          mainAxisAlignment: _parseMainAxisAlignment(
            props['mainAxisAlignment'],
          ),
          crossAxisAlignment: _parseCrossAxisAlignment(
            props['crossAxisAlignment'],
          ),
          mainAxisSize: props['mainAxisSize'] == 'min'
              ? MainAxisSize.min
              : MainAxisSize.max,
          children: _buildChildren(
            context,
            def['children'],
            eventData: eventData,
          ),
        );
      case 'row':
        return Row(
          mainAxisAlignment: _parseMainAxisAlignment(
            props['mainAxisAlignment'],
          ),
          crossAxisAlignment: _parseCrossAxisAlignment(
            props['crossAxisAlignment'],
          ),
          mainAxisSize: props['mainAxisSize'] == 'min'
              ? MainAxisSize.min
              : MainAxisSize.max,
          children: _buildChildren(
            context,
            def['children'],
            eventData: eventData,
          ),
        );
      case 'text':
        final rawValue = props['value'] ?? '';
        final value = _resolveValue(rawValue, eventData: eventData).toString();
        return Text(
          value,
          textAlign: _parseTextAlign(props['textAlign']),
          style: TextStyle(
            fontSize: (props['fontSize'] as num?)?.toDouble(),
            fontWeight: props['bold'] == true ? FontWeight.bold : null,
            fontStyle: props['italic'] == true ? FontStyle.italic : null,
            color: _parseColor(props['color']),
          ),
        );
      case 'icon':
        return Icon(
          _parseIconData(props['icon']),
          size: (props['size'] as num?)?.toDouble(),
          color: _parseColor(props['color']),
        );
      case 'divider':
        return Divider(
          height: (props['height'] as num?)?.toDouble(),
          thickness: (props['thickness'] as num?)?.toDouble(),
          color: _parseColor(props['color']),
          indent: (props['indent'] as num?)?.toDouble(),
          endIndent: (props['endIndent'] as num?)?.toDouble(),
        );
      case 'spacer':
        return const Spacer();
      case 'sizedbox':
        return SizedBox(
          width: (props['width'] as num?)?.toDouble(),
          height: (props['height'] as num?)?.toDouble(),
          child: _buildChild(context, def['child'], eventData: eventData),
        );
      case 'button':
        return FilledButton(
          onPressed: props['onTap'] != null
              ? () => _executeAction(props['onTap'], eventData: eventData)
              : null,
          style: props['color'] != null
              ? FilledButton.styleFrom(
                  backgroundColor: _parseColor(props['color']),
                )
              : null,
          child:
              _buildChild(context, def['child'], eventData: eventData) ??
              const Text('Button'),
        );
      case 'card':
        return Card(
          elevation: (props['elevation'] as num?)?.toDouble(),
          margin: _parseEdgeInsets(props['margin']),
          color: _parseColor(props['color']),
          shape: props['borderRadius'] != null
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    (props['borderRadius'] as num).toDouble(),
                  ),
                )
              : null,
          child: Padding(
            padding: _parseEdgeInsets(props['padding'] ?? 16),
            child: _buildChild(context, def['child'], eventData: eventData),
          ),
        );
      case 'segmentedButton':
        final segments =
            (props['segments'] as List?)?.map((s) {
              final sMap = s as Map<String, dynamic>;
              return ButtonSegment<String>(
                value: sMap['value'].toString(),
                label: _buildWidget(
                  context,
                  sMap['label'] as Map<String, dynamic>,
                  eventData: eventData,
                ),
                icon: sMap['icon'] != null
                    ? Icon(_parseIconData(sMap['icon']))
                    : null,
              );
            }).toList() ??
            [];
        final selectedValue = _resolveValue(
          props['selected'],
          eventData: eventData,
        );
        return SegmentedButton<String>(
          segments: segments,
          selected: {selectedValue.toString()},
          onSelectionChanged: (newSelection) {
            if (props['onChanged'] != null) {
              _executeAction(
                props['onChanged'],
                eventData: {'value': newSelection.first},
              );
            }
          },
        );
      case 'switchListTile':
        final value =
            _resolveValue(props['value'], eventData: eventData) == true;
        return SwitchListTile(
          title: _buildChild(context, def['title'], eventData: eventData),
          subtitle: _buildChild(context, def['subtitle'], eventData: eventData),
          value: value,
          onChanged: (val) {
            if (props['onChanged'] != null) {
              _executeAction(props['onChanged'], eventData: {'value': val});
            }
          },
        );
      case 'listview':
        final items =
            _resolveValue(props['items'], eventData: eventData) as List?;
        if (items == null) return const SizedBox();
        final itemDef = def['itemTemplate'] as Map<String, dynamic>?;
        if (itemDef == null) return const Text('Missing itemTemplate');
        final varName = props['var'] as String? ?? 'item';

        return ListView.builder(
          shrinkWrap: props['shrinkWrap'] == true,
          physics: props['scrollable'] == false
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final localEventData = Map<String, dynamic>.from(eventData ?? {});
            localEventData[varName] = items[index];
            localEventData['index'] = index;
            return _buildWidget(context, itemDef, eventData: localEventData);
          },
        );
      case 'tag_panel':
        final allTags = ref.watch(tagsProvider).value ?? [];
        final selectedTags =
            (_resolveValue(props['selected'], eventData: eventData) as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final recommendSource = _resolveValue(
          props['recommendSource'],
          eventData: eventData,
        )?.toString();

        final recommendations = recommendSource != null
            ? allTags.where((tag) {
                return recommendSource.toLowerCase().contains(
                  tag.toLowerCase(),
                );
              }).toList()
            : <String>[];

        final sortedTags = List<String>.from(allTags);
        sortedTags.sort((a, b) {
          final aRec = recommendations.contains(a);
          final bRec = recommendations.contains(b);
          if (aRec && !bRec) return -1;
          if (!aRec && bRec) return 1;
          return a.compareTo(b);
        });

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sortedTags.map((tag) {
            final isSelected = selectedTags.contains(tag);
            final isRecommended = recommendations.contains(tag);
            return FilterChip(
              label: Text(tag, style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (selected) {
                if (props['onChanged'] != null) {
                  final newList = List<String>.from(selectedTags);
                  if (selected) {
                    newList.add(tag);
                  } else {
                    newList.remove(tag);
                  }
                  _executeAction(
                    props['onChanged'],
                    eventData: {'value': newList},
                  );
                }
              },
              avatar: isRecommended && !isSelected
                  ? const Icon(Icons.auto_awesome, size: 14)
                  : null,
            );
          }).toList(),
        );
      default:
        return Text('Unknown widget: $type');
    }
  }

  Widget? _buildChild(
    BuildContext context,
    dynamic def, {
    Map<String, dynamic>? eventData,
  }) {
    if (def == null) return null;
    if (def is Map<String, dynamic>) {
      return _buildWidget(context, def, eventData: eventData);
    }
    return Text(def.toString());
  }

  List<Widget> _buildChildren(
    BuildContext context,
    dynamic def, {
    Map<String, dynamic>? eventData,
  }) {
    if (def is! List) return [];
    return def
        .map((child) => _buildChild(context, child, eventData: eventData))
        .whereType<Widget>()
        .toList();
  }

  // Parsers
  EdgeInsets _parseEdgeInsets(dynamic val) {
    if (val is num) return EdgeInsets.all(val.toDouble());
    if (val is List && val.length == 4) {
      return EdgeInsets.fromLTRB(
        (val[0] as num).toDouble(),
        (val[1] as num).toDouble(),
        (val[2] as num).toDouble(),
        (val[3] as num).toDouble(),
      );
    }
    return EdgeInsets.zero;
  }

  Color? _parseColor(dynamic val) {
    if (val is String) {
      if (val.startsWith('#')) {
        return Color(int.parse(val.substring(1), radix: 16) + 0xFF000000);
      }
    }
    return null;
  }

  MainAxisAlignment _parseMainAxisAlignment(dynamic val) {
    switch (val) {
      case 'center':
        return MainAxisAlignment.center;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(dynamic val) {
    switch (val) {
      case 'center':
        return CrossAxisAlignment.center;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      default:
        return CrossAxisAlignment.start;
    }
  }

  TextAlign _parseTextAlign(dynamic val) {
    switch (val) {
      case 'center':
        return TextAlign.center;
      case 'right':
      case 'end':
        return TextAlign.end;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.start;
    }
  }

  Alignment _parseAlignment(dynamic val) {
    switch (val) {
      case 'center':
        return Alignment.center;
      case 'topLeft':
        return Alignment.topLeft;
      case 'topRight':
        return Alignment.topRight;
      case 'bottomLeft':
        return Alignment.bottomLeft;
      case 'bottomRight':
        return Alignment.bottomRight;
      default:
        return Alignment.center;
    }
  }

  IconData _parseIconData(dynamic val) {
    // 简单映射，实际项目中可以使用完整的 MaterialIcons 映射表
    switch (val) {
      case 'home':
        return Icons.home;
      case 'settings':
        return Icons.settings;
      case 'person':
        return Icons.person;
      case 'add':
        return Icons.add;
      case 'edit':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'refresh':
        return Icons.refresh;
      case 'check':
        return Icons.check;
      case 'close':
        return Icons.close;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'arrow_forward':
        return Icons.arrow_forward;
      case 'arrow_back':
        return Icons.arrow_back;
      case 'notifications':
        return Icons.notifications;
      case 'event':
        return Icons.event;
      case 'list':
        return Icons.list;
      case 'grid_view':
        return Icons.grid_view;
      case 'trending_up':
        return Icons.trending_up;
      case 'pie_chart':
        return Icons.pie_chart;
      default:
        return Icons.help_outline;
    }
  }

  BoxDecoration? _parseDecoration(Map<String, dynamic> props) {
    final color = _parseColor(props['color']);
    final radius = (props['borderRadius'] as num?)?.toDouble();
    final border = props['border'];

    if (color == null && radius == null && border == null) return null;

    return BoxDecoration(
      color: color,
      borderRadius: radius != null ? BorderRadius.circular(radius) : null,
      border: border == true ? Border.all(color: Colors.grey.shade300) : null,
    );
  }
}
