import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'logic_engine.dart';
import 'extension_console.dart';

/// 动态 UI 渲染器 (配合 ExtensionJsEngine 使用)
class DynamicEngine extends ConsumerStatefulWidget {
  final ExtensionJsEngine engine;

  const DynamicEngine({super.key, required this.engine});

  @override
  ConsumerState<DynamicEngine> createState() => _DynamicEngineState();
}

class _DynamicEngineState extends ConsumerState<DynamicEngine> {
  @override
  void initState() {
    super.initState();
    widget.engine.setOnStateChanged(() {
      if (mounted) setState(() {});
    });

    if (!widget.engine.isInitialized) {
      widget.engine.init().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (widget.engine.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                '${l10n.extensionError}:\n${widget.engine.error}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                  widget.engine.init();
                },
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (!widget.engine.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final viewDef = widget.engine.metadata.view;
    if (viewDef == null) {
      return Center(child: Text(l10n.extensionNoUI));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: ExtensionConsole(engine: widget.engine),
            ),
          );
        },
        child: const Icon(Icons.bug_report),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar.large(
              title: Text(widget.engine.metadata.name),
              centerTitle: false,
              pinned: true,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: theme.colorScheme.surfaceTint,
            ),
          ];
        },
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _buildWidget(viewDef),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWidget(Map<String, dynamic> def) {
    // 提取该组件引用的所有状态键
    final stateKeys = _extractStateKeys(def);

    if (stateKeys.isEmpty) {
      return _buildWidgetInternal(def);
    }

    // 如果组件引用了状态，则使用 ValueListenableBuilder 包装
    // 注意：这里简单起见，如果引用多个状态，目前仅绑定第一个发现的状态，或者绑定整体变化
    // 为了极致性能，后续可以改为监听多个 ValueNotifier
    return ValueListenableBuilder(
      valueListenable: widget.engine.getStateNotifier(stateKeys.first),
      builder: (context, value, child) {
        return _buildWidgetInternal(def);
      },
    );
  }

  /// 内部构建逻辑，不包含状态绑定
  Widget _buildWidgetInternal(Map<String, dynamic> def) {
    final type = def['type'] as String? ?? 'container';
    final children = def['children'] as List?;
    final props = def['props'] as Map<String, dynamic>? ?? {};

    // 处理布局属性
    final padding = _parsePadding(props['padding']);
    final margin = _parsePadding(props['margin']);
    final width = (props['width'] as num?)?.toDouble();
    final height = (props['height'] as num?)?.toDouble();
    final color = _parseColor(props['color'], context);

    // 处理点击事件，优先支持 top-level onTap，其次支持 props.action
    VoidCallback? onTap;
    final action = def['onTap'] ?? props['action'];
    if (action != null) {
      onTap = () {
        if (action is String) {
          widget.engine.callFunction(action, props['params']);
        } else if (action is Map && action.containsKey('call')) {
          widget.engine.callFunction(action['call'], action['params']);
        }
      };
    }

    Widget current;
    final theme = Theme.of(context);

    switch (type) {
      case 'column':
        final hasFlex = (children ?? []).any((c) {
          final childType = (c as Map)['type'];
          return childType == 'expanded' || childType == 'spacer';
        });
        current = Column(
          mainAxisSize: props['mainAxisSize'] == 'max' || hasFlex
              ? MainAxisSize.max
              : MainAxisSize.min,
          crossAxisAlignment: _parseCrossAxisAlignment(
            props['crossAxisAlignment'],
          ),
          mainAxisAlignment: _parseMainAxisAlignment(
            props['mainAxisAlignment'],
          ),
          children: (children ?? [])
              .map((c) => _buildWidget(c as Map<String, dynamic>))
              .toList(),
        );
        break;
      case 'row':
        final hasFlexRow = (children ?? []).any((c) {
          final childType = (c as Map)['type'];
          return childType == 'expanded' || childType == 'spacer';
        });
        current = Row(
          mainAxisSize: props['mainAxisSize'] == 'max' || hasFlexRow
              ? MainAxisSize.max
              : MainAxisSize.min,
          crossAxisAlignment: _parseCrossAxisAlignment(
            props['crossAxisAlignment'],
          ),
          mainAxisAlignment: _parseMainAxisAlignment(
            props['mainAxisAlignment'],
          ),
          children: (children ?? [])
              .map((c) => _buildWidget(c as Map<String, dynamic>))
              .toList(),
        );
        break;
      case 'text':
        TextStyle style;
        final textStyleName = props['textStyle']?.toString();
        if (textStyleName != null) {
          style = _getThemeTextStyle(textStyleName, theme);
        } else {
          style = theme.textTheme.bodyMedium!;
        }

        current = Text(
          _resolveValue(props['text'] ?? ''),
          textAlign: _parseTextAlign(props['textAlign']),
          style: style.copyWith(
            fontSize: (props['fontSize'] as num?)?.toDouble(),
            fontWeight: props['bold'] == true ? FontWeight.bold : null,
            color: _parseColor(props['textColor'], context),
          ),
        );
        break;
      case 'button':
        final label = Text(
          _resolveValue(props['label'] ?? l10n.extensionDefaultButtonLabel),
        );
        final variant = props['variant']?.toString().toLowerCase();
        final iconData = props['icon'] != null
            ? Icon(IconData(props['icon'], fontFamily: 'MaterialIcons'))
            : null;

        if (variant == 'filled') {
          current = iconData != null
              ? FilledButton.icon(
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : FilledButton(onPressed: onTap, child: label);
        } else if (variant == 'tonal') {
          current = iconData != null
              ? FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : FilledButton.tonal(onPressed: onTap, child: label);
        } else if (variant == 'outlined') {
          current = iconData != null
              ? OutlinedButton.icon(
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : OutlinedButton(onPressed: onTap, child: label);
        } else if (variant == 'text') {
          current = iconData != null
              ? TextButton.icon(onPressed: onTap, icon: iconData, label: label)
              : TextButton(onPressed: onTap, child: label);
        } else {
          current = iconData != null
              ? ElevatedButton.icon(
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : ElevatedButton(onPressed: onTap, child: label);
        }
        break;
      case 'card':
        final variant = props['variant']?.toString().toLowerCase();
        final elevation = (props['elevation'] as num?)?.toDouble();
        final color = _parseColor(props['color'], context);
        final borderRadius = (props['borderRadius'] as num?)?.toDouble() ?? 12;
        final child = children != null && children.isNotEmpty
            ? _buildWidget(children.first as Map<String, dynamic>)
            : const SizedBox.shrink();

        if (variant == 'outlined') {
          current = Card.outlined(
            elevation: elevation ?? 0,
            color: color,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          );
        } else if (variant == 'filled') {
          current = Card.filled(
            elevation: elevation ?? 0,
            color: color,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          );
        } else {
          current = Card(
            elevation: elevation,
            color: color,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          );
        }
        break;
      case 'settings_group':
        final items = props['items'] as List? ?? [];
        final title = props['title']?.toString();

        current = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                child: Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value as Map<String, dynamic>;
                  return Column(
                    children: [
                      _buildWidget(item),
                      if (index < items.length - 1)
                        Divider(
                          height: 1,
                          indent: 64,
                          endIndent: 16,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
        break;

      case 'list_tile':
        current = ListTile(
          title: Text(
            _resolveValue(props['title'] ?? ''),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: props['subtitle'] != null
              ? Text(
                  _resolveValue(props['subtitle']),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
          leading: props['icon'] != null
              ? Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        _parseColor(props['iconBgColor'], context) ??
                        theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    IconData(props['icon'], fontFamily: 'MaterialIcons'),
                    size: 20,
                    color:
                        _parseColor(props['iconColor'], context) ??
                        theme.colorScheme.onPrimaryContainer,
                  ),
                )
              : null,
          trailing: props['trailing'] != null
              ? _buildWidget(props['trailing'] as Map<String, dynamic>)
              : (props['trailingIcon'] != null
                    ? Icon(
                        IconData(
                          props['trailingIcon'],
                          fontFamily: 'MaterialIcons',
                        ),
                        size: 18,
                        color:
                            _parseColor(props['trailingIconColor'], context) ??
                            theme.colorScheme.outline,
                      )
                    : (props['showChevron'] == true
                          ? Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.7,
                              ),
                            )
                          : null)),
          contentPadding:
              _parsePadding(props['contentPadding']) ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          onTap: onTap,
        );
        break;
      case 'icon':
        current = Icon(
          IconData(props['icon'] ?? 0xe3af, fontFamily: 'MaterialIcons'),
          size: (props['size'] as num?)?.toDouble(),
          color: _parseColor(props['color'], context),
        );
        break;
      case 'divider':
        current = Divider(
          height: (props['height'] as num?)?.toDouble(),
          thickness: (props['thickness'] as num?)?.toDouble(),
          color: _parseColor(props['color'], context),
        );
        break;
      case 'switch':
        final stateKey = props['stateKey'] as String?;
        final value = stateKey != null
            ? (widget.engine.state[stateKey] == true)
            : (props['value'] == true);
        current = Switch(
          value: value,
          onChanged: (val) {
            if (stateKey != null) {
              widget.engine.updateState(stateKey, val);
            }
            if (onTap != null) onTap();
          },
        );
        break;
      case 'checkbox':
        final stateKey = props['stateKey'] as String?;
        final value = stateKey != null
            ? (widget.engine.state[stateKey] == true)
            : (props['value'] == true);
        current = Checkbox(
          value: value,
          onChanged: (val) {
            if (stateKey != null) {
              widget.engine.updateState(stateKey, val ?? false);
            }
            if (onTap != null) onTap();
          },
        );
        break;
      case 'radio':
        final stateKey = props['stateKey'] as String?;
        final value = stateKey != null
            ? widget.engine.state[stateKey]
            : props['value'];
        final groupValue = props['groupValue'];
        current = RadioGroup(
          groupValue: groupValue,
          onChanged: (val) {
            if (stateKey != null) {
              widget.engine.updateState(stateKey, val);
            }
            if (onTap != null) onTap();
          },
          child: Radio(value: value),
        );
        break;
      case 'slider':
        final stateKey = props['stateKey'] as String?;
        final value = stateKey != null
            ? (widget.engine.state[stateKey] as num?)?.toDouble() ?? 0.0
            : (props['value'] as num?)?.toDouble() ?? 0.0;
        current = Slider(
          value: value,
          min: (props['min'] as num?)?.toDouble() ?? 0.0,
          max: (props['max'] as num?)?.toDouble() ?? 1.0,
          divisions: props['divisions'] as int?,
          label: props['label']?.toString(),
          onChanged: (val) {
            if (stateKey != null) {
              widget.engine.updateState(stateKey, val);
            }
          },
          onChangeEnd: (val) {
            if (onTap != null) onTap();
          },
        );
        break;
      case 'chip':
        final label = Text(_resolveValue(props['label'] ?? ''));
        final avatar = props['icon'] != null
            ? Icon(
                IconData(props['icon'], fontFamily: 'MaterialIcons'),
                size: 18,
              )
            : null;
        final selected = props['selected'] == true;
        final variant = props['variant']?.toString().toLowerCase();

        if (variant == 'filter') {
          current = FilterChip(
            label: label,
            avatar: avatar,
            selected: selected,
            onSelected: (val) {
              final stateKey = props['stateKey'] as String?;
              if (stateKey != null) {
                widget.engine.updateState(stateKey, val);
              }
              if (onTap != null) onTap();
            },
          );
        } else if (variant == 'choice') {
          current = ChoiceChip(
            label: label,
            avatar: avatar,
            selected: selected,
            onSelected: (val) {
              final stateKey = props['stateKey'] as String?;
              if (stateKey != null) {
                widget.engine.updateState(stateKey, val);
              }
              if (onTap != null) onTap();
            },
          );
        } else {
          current = ActionChip(label: label, avatar: avatar, onPressed: onTap);
        }
        break;
      case 'badge':
        final label = props['label']?.toString();
        current = Badge(
          label: label != null ? Text(label) : null,
          backgroundColor: _parseColor(props['backgroundColor'], context),
          textColor: _parseColor(props['textColor'], context),
          child: children != null && children.isNotEmpty
              ? _buildWidget(children.first as Map<String, dynamic>)
              : null,
        );
        break;
      case 'segmented_button':
        final segments = (props['segments'] as List? ?? []).map((s) {
          final sMap = s as Map<String, dynamic>;
          return ButtonSegment(
            value: sMap['value'],
            label: Text(_resolveValue(sMap['label'] ?? '')),
            icon: sMap['icon'] != null
                ? Icon(IconData(sMap['icon'], fontFamily: 'MaterialIcons'))
                : null,
          );
        }).toList();

        final stateKey = props['stateKey'] as String?;
        final selected = stateKey != null
            ? {widget.engine.state[stateKey]}
            : {props['selected']};

        current = SegmentedButton(
          segments: segments,
          selected: selected,
          onSelectionChanged: (newSelection) {
            if (stateKey != null) {
              widget.engine.updateState(stateKey, newSelection.first);
            }
            if (onTap != null) onTap();
          },
        );
        break;
      case 'grid_view':
        final crossAxisCount = props['crossAxisCount'] as int? ?? 2;
        current = GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: padding,
          mainAxisSpacing: (props['mainAxisSpacing'] as num?)?.toDouble() ?? 0,
          crossAxisSpacing:
              (props['crossAxisSpacing'] as num?)?.toDouble() ?? 0,
          childAspectRatio:
              (props['childAspectRatio'] as num?)?.toDouble() ?? 1,
          children: (children ?? [])
              .map((c) => _buildWidget(c as Map<String, dynamic>))
              .toList(),
        );
        break;
      case 'textfield':
        final stateKey = props['stateKey'] as String?;
        final value = stateKey != null
            ? (widget.engine.state[stateKey]?.toString() ?? '')
            : (props['value']?.toString() ?? '');
        current = TextField(
          controller: TextEditingController(text: value)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: value.length),
            ),
          decoration: InputDecoration(
            labelText: _resolveValue(props['label'] ?? ''),
            hintText: _resolveValue(props['hint'] ?? ''),
            filled: props['filled'] ?? true,
            border: props['noBorder'] == true
                ? InputBorder.none
                : const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
          ),
          onChanged: (val) {
            if (stateKey != null) {
              widget.engine.updateState(stateKey, val);
            }
          },
        );
        break;
      case 'image':
        current = Image.network(
          _resolveValue(props['url'] ?? ''),
          width: width,
          height: height,
          fit: _parseBoxFit(props['fit']),
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
        );
        break;
      case 'spacer':
        current = const Spacer();
        break;
      case 'expanded':
        current = Expanded(
          flex: props['flex'] as int? ?? 1,
          child: children != null && children.isNotEmpty
              ? _buildWidget(children.first as Map<String, dynamic>)
              : const SizedBox.shrink(),
        );
        break;
      case 'circular_progress':
        current = CircularProgressIndicator(
          value: (props['value'] as num?)?.toDouble(),
          color: _parseColor(props['color'], context),
        );
        break;
      case 'linear_progress':
        current = LinearProgressIndicator(
          value: (props['value'] as num?)?.toDouble(),
          color: _parseColor(props['color'], context),
          backgroundColor: _parseColor(props['backgroundColor'], context),
        );
        break;
      case 'sized_box':
        current = SizedBox(
          width: (props['width'] as num?)?.toDouble(),
          height: (props['height'] as num?)?.toDouble(),
          child: children != null && children.isNotEmpty
              ? _buildWidget(children.first as Map<String, dynamic>)
              : null,
        );
        break;
      case 'wrap':
        current = Wrap(
          spacing: (props['spacing'] as num?)?.toDouble() ?? 0,
          runSpacing: (props['runSpacing'] as num?)?.toDouble() ?? 0,
          alignment: _parseWrapAlignment(props['alignment']),
          children: (children ?? [])
              .map((c) => _buildWidget(c as Map<String, dynamic>))
              .toList(),
        );
        break;
      case 'stack':
        current = Stack(
          alignment: _parseAlignment(props['alignment']) ?? Alignment.topLeft,
          children: (children ?? [])
              .map((c) => _buildWidget(c as Map<String, dynamic>))
              .toList(),
        );
        break;
      case 'positioned':
        current = Positioned(
          left: (props['left'] as num?)?.toDouble(),
          top: (props['top'] as num?)?.toDouble(),
          right: (props['right'] as num?)?.toDouble(),
          bottom: (props['bottom'] as num?)?.toDouble(),
          child: children != null && children.isNotEmpty
              ? _buildWidget(children.first as Map<String, dynamic>)
              : const SizedBox.shrink(),
        );
        break;
      case 'list_view':
        current = ListView(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          padding: padding,
          children: (children ?? [])
              .map((c) => _buildWidget(c as Map<String, dynamic>))
              .toList(),
        );
        break;
      case 'container':
        current = children != null && children.isNotEmpty
            ? _buildWidget(children.first as Map<String, dynamic>)
            : const SizedBox.shrink();
        break;
      default:
        current = const SizedBox.shrink();
    }

    // 应用通用的 Container 属性
    if (type != 'spacer' && type != 'expanded' && type != 'positioned') {
      if (onTap != null &&
          type != 'button' &&
          type != 'list_tile' &&
          type != 'switch') {
        current = GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: current,
        );
      }

      current = Container(
        padding: padding,
        margin: margin,
        width: width,
        height: height,
        alignment: _parseAlignment(props['alignment']),
        decoration: color != null
            ? BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(
                  (props['borderRadius'] as num?)?.toDouble() ?? 0,
                ),
              )
            : null,
        child: current,
      );
    }

    return current;
  }

  /// 提取组件中引用的状态键
  List<String> _extractStateKeys(Map<String, dynamic> def) {
    final Set<String> keys = {};
    final props = def['props'] as Map<String, dynamic>? ?? {};

    // 检查 stateKey
    if (props.containsKey('stateKey')) {
      keys.add(props['stateKey'].toString());
    }

    // 检查插值
    void checkString(dynamic value) {
      if (value is String) {
        final matches = RegExp(r'\$state\.([a-zA-Z0-9_]+)').allMatches(value);
        for (final match in matches) {
          keys.add(match.group(1)!);
        }
      } else if (value is Map) {
        value.values.forEach(checkString);
      } else if (value is List) {
        value.forEach(checkString);
      }
    }

    props.values.forEach(checkString);

    return keys.toList();
  }

  // --- 解析工具方法 ---

  EdgeInsets? _parsePadding(dynamic val) {
    if (val == null) return null;
    if (val is num) return EdgeInsets.all(val.toDouble());
    if (val is Map) {
      return EdgeInsets.only(
        left: (val['left'] as num?)?.toDouble() ?? 0,
        top: (val['top'] as num?)?.toDouble() ?? 0,
        right: (val['right'] as num?)?.toDouble() ?? 0,
        bottom: (val['bottom'] as num?)?.toDouble() ?? 0,
      );
    }
    return null;
  }

  Color? _parseColor(dynamic val, BuildContext context) {
    if (val == null) return null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (val is String) {
      // MD3 Theme Colors
      switch (val.toLowerCase()) {
        case 'primary':
          return colorScheme.primary;
        case 'onprimary':
          return colorScheme.onPrimary;
        case 'primarycontainer':
          return colorScheme.primaryContainer;
        case 'onprimarycontainer':
          return colorScheme.onPrimaryContainer;
        case 'secondary':
          return colorScheme.secondary;
        case 'onsecondary':
          return colorScheme.onSecondary;
        case 'secondarycontainer':
          return colorScheme.secondaryContainer;
        case 'onsecondarycontainer':
          return colorScheme.onSecondaryContainer;
        case 'tertiary':
          return colorScheme.tertiary;
        case 'ontertiary':
          return colorScheme.onTertiary;
        case 'tertiarycontainer':
          return colorScheme.tertiaryContainer;
        case 'ontertiarycontainer':
          return colorScheme.onTertiaryContainer;
        case 'error':
          return colorScheme.error;
        case 'onerror':
          return colorScheme.onError;
        case 'errorcontainer':
          return colorScheme.errorContainer;
        case 'onerrorcontainer':
          return colorScheme.onErrorContainer;
        case 'outline':
          return colorScheme.outline;
        case 'outlinevariant':
          return colorScheme.outlineVariant;
        case 'surface':
          return colorScheme.surface;
        case 'onsurface':
          return colorScheme.onSurface;
        case 'surfacevariant':
          return colorScheme.surfaceContainerHighest;
        case 'onsurfacevariant':
          return colorScheme.onSurfaceVariant;
        case 'inverseprimary':
          return colorScheme.inversePrimary;
        case 'inversesurface':
          return colorScheme.inverseSurface;
        case 'oninversesurface':
          return colorScheme.onInverseSurface;
        case 'scrim':
          return colorScheme.scrim;
        case 'shadow':
          return colorScheme.shadow;
      }

      if (val.startsWith('#')) {
        final hex = val.replaceFirst('#', '');
        return Color(int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16));
      }
      // 支持简单的颜色名称
      switch (val.toLowerCase()) {
        case 'red':
          return Colors.red;
        case 'blue':
          return Colors.blue;
        case 'green':
          return Colors.green;
        case 'grey':
          return Colors.grey;
        case 'white':
          return Colors.white;
        case 'black':
          return Colors.black;
        case 'transparent':
          return Colors.transparent;
      }
    }
    return null;
  }

  TextStyle _getThemeTextStyle(String name, ThemeData theme) {
    switch (name.toLowerCase()) {
      case 'displaylarge':
        return theme.textTheme.displayLarge!;
      case 'displaymedium':
        return theme.textTheme.displayMedium!;
      case 'displaysmall':
        return theme.textTheme.displaySmall!;
      case 'headlinelarge':
        return theme.textTheme.headlineLarge!;
      case 'headlinemedium':
        return theme.textTheme.headlineMedium!;
      case 'headlinesmall':
        return theme.textTheme.headlineSmall!;
      case 'titlelarge':
        return theme.textTheme.titleLarge!;
      case 'titlemedium':
        return theme.textTheme.titleMedium!;
      case 'titlesmall':
        return theme.textTheme.titleSmall!;
      case 'bodylarge':
        return theme.textTheme.bodyLarge!;
      case 'bodymedium':
        return theme.textTheme.bodyMedium!;
      case 'bodysmall':
        return theme.textTheme.bodySmall!;
      case 'labellarge':
        return theme.textTheme.labelLarge!;
      case 'labelmedium':
        return theme.textTheme.labelMedium!;
      case 'labelsmall':
        return theme.textTheme.labelSmall!;
      default:
        return theme.textTheme.bodyMedium!;
    }
  }

  Alignment? _parseAlignment(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'center':
        return Alignment.center;
      case 'topcenter':
        return Alignment.topCenter;
      case 'bottomcenter':
        return Alignment.bottomCenter;
      case 'centerleft':
        return Alignment.centerLeft;
      case 'centerright':
        return Alignment.centerRight;
      default:
        return null;
    }
  }

  MainAxisAlignment _parseMainAxisAlignment(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'center':
        return MainAxisAlignment.center;
      case 'end':
        return MainAxisAlignment.end;
      case 'spacebetween':
        return MainAxisAlignment.spaceBetween;
      case 'spacearound':
        return MainAxisAlignment.spaceAround;
      case 'spaceevenly':
        return MainAxisAlignment.spaceEvenly;
      default:
        return MainAxisAlignment.start;
    }
  }

  CrossAxisAlignment _parseCrossAxisAlignment(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'center':
        return CrossAxisAlignment.center;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      default:
        return CrossAxisAlignment.start;
    }
  }

  TextAlign _parseTextAlign(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  BoxFit? _parseBoxFit(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'cover':
        return BoxFit.cover;
      case 'contain':
        return BoxFit.contain;
      case 'fill':
        return BoxFit.fill;
      case 'fitwidth':
        return BoxFit.fitWidth;
      case 'fitheight':
        return BoxFit.fitHeight;
      default:
        return null;
    }
  }

  WrapAlignment _parseWrapAlignment(dynamic val) {
    switch (val?.toString().toLowerCase()) {
      case 'center':
        return WrapAlignment.center;
      case 'end':
        return WrapAlignment.end;
      case 'spacearound':
        return WrapAlignment.spaceAround;
      case 'spacebetween':
        return WrapAlignment.spaceBetween;
      case 'spaceevenly':
        return WrapAlignment.spaceEvenly;
      default:
        return WrapAlignment.start;
    }
  }

  String _resolveValue(dynamic value) {
    if (value is! String) return value.toString();

    // 支持全量替换 $state.key
    if (value.startsWith('\$state.')) {
      final key = value.substring(7);
      return widget.engine.state[key]?.toString() ?? '';
    }

    // 支持插值: "Count is $state.counter"
    return value.replaceAllMapped(RegExp(r'\$state\.([a-zA-Z0-9_]+)'), (match) {
      final key = match.group(1);
      return widget.engine.state[key]?.toString() ?? '';
    });
  }
}
