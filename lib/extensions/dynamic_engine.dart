import 'package:flutter/material.dart';
import 'base_extension.dart';

/// 动态 UI 渲染器与逻辑执行引擎 (Path B & C)
class DynamicEngine extends StatefulWidget {
  final ExtensionMetadata metadata;
  final ExtensionApi api;

  const DynamicEngine({super.key, required this.metadata, required this.api});

  @override
  State<DynamicEngine> createState() => _DynamicEngineState();
}

class _DynamicEngineState extends State<DynamicEngine> {
  final Map<String, dynamic> _state = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeLogic();
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

  Future<void> _executeAction(dynamic actionDef) async {
    debugPrint('Executing action: $actionDef');
    if (actionDef is String) {
      // Named action reference
      final actions =
          widget.metadata.logic?['actions'] as Map<String, dynamic>?;
      final sequence = actions?[actionDef] as List?;
      if (sequence != null) {
        for (var step in sequence) {
          await _executeAction(step);
        }
      }
      return;
    }

    if (actionDef is! Map<String, dynamic>) return;

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
        final msg = _resolveValue(params['message']);
        widget.api.showSnackBar(msg.toString());
        break;
      case 'api.navigateTo':
        widget.api.navigateTo(params['route']);
        break;
      case 'api.exportFile':
        final content = _resolveValue(params['content']).toString();
        final fileName = _resolveValue(params['fileName']).toString();
        result = await widget.api.exportFile(content, fileName);
        break;
      case 'state.set':
        result = _resolveValue(params['value']);
        break;
      case 'list.length':
        final list = _resolveValue(params['list']);
        result = (list is List) ? list.length : 0;
        debugPrint('List length: $result');
        break;
    }

    if (assignTo != null) {
      debugPrint('Assigning result to state.$assignTo: $result');
      setState(() {
        _state[assignTo] = result;
      });
    }
  }

  dynamic _resolveValue(dynamic val) {
    if (val is String) {
      // 匹配所有 ${state.xxx} 占位符并替换
      final regex = RegExp(r'\$\{state\.([^\}]+)\}');
      String result = val;

      final matches = regex.allMatches(val).toList();
      // 如果只有一个占位符且占位符就是整个字符串，返回原始对象类型（如 List 或 int）
      if (matches.length == 1 && matches.first.group(0) == val) {
        final key = matches.first.group(1)!;
        return _state[key];
      }

      // 否则进行字符串替换
      for (final match in matches) {
        final fullMatch = match.group(0)!;
        final key = match.group(1)!;
        final stateValue = _state[key] ?? '';
        result = result.replaceFirst(fullMatch, stateValue.toString());
      }
      return result;
    }
    return val;
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
      backgroundColor: Colors.white,
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

  Widget _buildWidget(BuildContext context, Map<String, dynamic> def) {
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
          child: _buildChild(context, def['child']),
        );
      case 'center':
        return Center(child: _buildChild(context, def['child']));
      case 'padding':
        return Padding(
          padding: _parseEdgeInsets(props['padding'] ?? 8),
          child: _buildChild(context, def['child']),
        );
      case 'expanded':
        return Expanded(child: _buildChild(context, def['child'])!);
      case 'flexible':
        return Flexible(child: _buildChild(context, def['child'])!);
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
          children: _buildChildren(context, def['children']),
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
          children: _buildChildren(context, def['children']),
        );
      case 'text':
        final rawValue = props['value'] ?? '';
        final value = _resolveValue(rawValue).toString();
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
          child: _buildChild(context, def['child']),
        );
      case 'button':
        return FilledButton(
          onPressed: props['onTap'] != null
              ? () => _executeAction(props['onTap'])
              : null,
          style: props['color'] != null
              ? FilledButton.styleFrom(
                  backgroundColor: _parseColor(props['color']),
                )
              : null,
          child: _buildChild(context, def['child']) ?? const Text('Button'),
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
            child: _buildChild(context, def['child']),
          ),
        );
      case 'listview':
        final items = _resolveValue(props['items']) as List?;
        if (items == null) return const SizedBox();
        final itemDef = def['itemTemplate'] as Map<String, dynamic>?;
        if (itemDef == null) return const Text('Missing itemTemplate');

        return ListView.builder(
          shrinkWrap: props['shrinkWrap'] == true,
          physics: props['scrollable'] == false
              ? const NeverScrollableScrollPhysics()
              : null,
          itemCount: items.length,
          itemBuilder: (context, index) {
            // Push item into local scope for rendering?
            // Simple approach: just pass the item data somehow
            return _buildWidget(context, itemDef);
          },
        );
      default:
        return Text('Unknown widget: $type');
    }
  }

  Widget? _buildChild(BuildContext context, dynamic childDef) {
    if (childDef == null) return null;
    return _buildWidget(context, childDef as Map<String, dynamic>);
  }

  List<Widget> _buildChildren(BuildContext context, dynamic childrenDef) {
    if (childrenDef is! List) return [];
    return childrenDef
        .map((c) => _buildWidget(context, c as Map<String, dynamic>))
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
