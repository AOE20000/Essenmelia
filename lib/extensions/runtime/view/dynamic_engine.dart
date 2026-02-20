import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animations/animations.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../../l10n/app_localizations.dart';
import '../js/extension_js_engine.dart';
import 'extension_console.dart';

/// Dynamic UI Renderer (works with ExtensionJsEngine)
class DynamicEngine extends ConsumerStatefulWidget {
  final ExtensionJsEngine engine;

  const DynamicEngine({super.key, required this.engine});

  @override
  ConsumerState<DynamicEngine> createState() => _DynamicEngineState();
}

class _DynamicEngineState extends ConsumerState<DynamicEngine> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.engine.setOnStateChanged(() {
      if (mounted) {
        setState(() {});
      }
    });

    if (!widget.engine.isInitialized) {
      widget.engine
          .init()
          .then((_) {
            if (mounted) {
              setState(() {});
            }
          })
          .catchError((e) {
            if (mounted) {
              setState(() {});
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

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
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
        child: _buildMainContent(theme, l10n),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme, AppLocalizations l10n) {
    if (widget.engine.error != null) {
      return Center(
        key: const ValueKey('error'),
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
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(),
      );
    }

    final viewDef = widget.engine.metadata.view;
    if (viewDef == null) {
      return Center(
        key: const ValueKey('no_ui'),
        child: Text(l10n.extensionNoUI),
      );
    }

    // Special case: HTML content as the entire view
    if (viewDef is String) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.engine.metadata.name),
          centerTitle: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: HtmlWidget(
            viewDef,
            textStyle: theme.textTheme.bodyMedium,
            onTapUrl: (url) {
              if (url.startsWith('js:')) {
                // Parse js:funcName?param=value
                // Remove 'js:' prefix to get the rest
                final raw = url.substring(3);
                final queryIndex = raw.indexOf('?');

                String funcName;
                Map<String, dynamic> params = {};

                if (queryIndex != -1) {
                  funcName = raw.substring(0, queryIndex);
                  final query = raw.substring(queryIndex + 1);
                  final uri = Uri(query: query);
                  params = uri.queryParameters;
                } else {
                  funcName = raw;
                }

                widget.engine.callFunction(funcName, params);
                return true;
              }
              // Allow default handling (url_launcher)
              return false;
            },
          ),
        ),
      );
    }

    return NestedScrollView(
      key: const ValueKey('content'),
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
              child: _buildWidget(viewDef as Map<String, dynamic>),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(dynamic e) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Render Error: $e',
              style: const TextStyle(color: Colors.red, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidget(Map<String, dynamic> def) {
    try {
      // Extract state keys referenced by this widget
      final stateKeys = _extractStateKeys(def);

      if (stateKeys.isEmpty) {
        try {
          return _buildWidgetInternal(def);
        } catch (e) {
          return _buildErrorWidget(e);
        }
      }

      // If widget references state, wrap with ValueListenableBuilder
      // Note: Only supporting single state key for now for simplicity, or we'd need MultiValueListenableBuilder
      return ValueListenableBuilder(
        valueListenable: widget.engine.getStateNotifier(stateKeys.first),
        builder: (context, value, child) {
          try {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Easing.emphasizedDecelerate,
              switchOutCurve: Easing.emphasizedAccelerate,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeThroughTransition(
                  animation: animation,
                  secondaryAnimation: ReverseAnimation(animation),
                  fillColor: Colors.transparent,
                  child: child,
                );
              },
              child: _buildWidgetInternal(def, key: ValueKey(value)),
            );
          } catch (e) {
            return _buildErrorWidget(e);
          }
        },
      );
    } catch (e) {
      return _buildErrorWidget(e);
    }
  }

  /// Internal build logic without state binding
  Widget _buildWidgetInternal(Map<String, dynamic> def, {Key? key}) {
    final type = def['type'] as String? ?? 'container';
    final props = def['props'] as Map<String, dynamic>? ?? {};

    // Layout props
    final padding = _parsePadding(props['padding']);
    final margin = _parsePadding(props['margin']);
    final width = (props['width'] as num?)?.toDouble();
    final height = (props['height'] as num?)?.toDouble();
    final color = _parseColor(props['color'], context);

    // Resolve children
    List<dynamic> resolvedChildren = [];
    final rawChildren = def['children'];
    if (rawChildren is List) {
      resolvedChildren = rawChildren;
    } else if (rawChildren is String && rawChildren.startsWith('\$')) {
      final key = rawChildren.substring(1);
      final val = widget.engine.state[key];
      if (val is List) {
        resolvedChildren = val;
      }
    }

    // Tap handling
    VoidCallback? onTap;
    // Compatibility: Support onTap, action, onPress in root or props
    final action =
        def['onTap'] ??
        def['action'] ??
        props['action'] ??
        props['onTap'] ??
        props['onPress'];

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
    final l10n = AppLocalizations.of(context)!;

    switch (type) {
      case 'column':
        final hasFlex = resolvedChildren.any((c) {
          final childType = (c as Map)['type'];
          return childType == 'expanded' || childType == 'spacer';
        });
        current = Column(
          key: key,
          mainAxisSize: props['mainAxisSize'] == 'max' || hasFlex
              ? MainAxisSize.max
              : MainAxisSize.min,
          crossAxisAlignment: _parseCrossAxisAlignment(
            props['crossAxisAlignment'],
          ),
          mainAxisAlignment: _parseMainAxisAlignment(
            props['mainAxisAlignment'],
          ),
          children: resolvedChildren
              .map((c) => _buildWidget(c as Map<String, dynamic>))
              .toList(),
        );
        break;
      case 'row':
        final hasFlexRow = resolvedChildren.any((c) {
          final childType = (c as Map)['type'];
          return childType == 'expanded' || childType == 'spacer';
        });
        current = Row(
          key: key,
          mainAxisSize: props['mainAxisSize'] == 'max' || hasFlexRow
              ? MainAxisSize.max
              : MainAxisSize.min,
          crossAxisAlignment: _parseCrossAxisAlignment(
            props['crossAxisAlignment'],
          ),
          mainAxisAlignment: _parseMainAxisAlignment(
            props['mainAxisAlignment'],
          ),
          children: resolvedChildren
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
          _resolveValue(props['text'] ?? '').toString(),
          key: key,
          textAlign: _parseTextAlign(props['textAlign']),
          style: style.copyWith(
            fontSize: (props['fontSize'] as num?)?.toDouble(),
            fontWeight: props['bold'] == true ? FontWeight.bold : null,
            color: _parseColor(props['textColor'], context),
          ),
        );
        break;
      case 'html':
        final content = _resolveValue(props['content'] ?? '').toString();
        current = HtmlWidget(
          content,
          key: key,
          textStyle: theme.textTheme.bodyMedium,
          onTapUrl: (url) {
            final action = def['onTapUrl'];
            if (action != null) {
              if (action is String) {
                widget.engine.callFunction(action, {'url': url});
              } else if (action is Map && action.containsKey('call')) {
                widget.engine.callFunction(action['call'], {
                  'url': url,
                  ...?action['params'],
                });
              }
              return true;
            }
            // If user explicitly wants to open in browser via extension API
            if (url.startsWith('http')) {
              // Default handling by widget is fine, but maybe we want to use our internal browser or launchUrl
              // The widget uses url_launcher by default.
            }
            return false;
          },
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
                  key: key,
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : FilledButton(key: key, onPressed: onTap, child: label);
        } else if (variant == 'tonal') {
          current = iconData != null
              ? FilledButton.tonalIcon(
                  key: key,
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : FilledButton.tonal(key: key, onPressed: onTap, child: label);
        } else if (variant == 'outlined') {
          current = iconData != null
              ? OutlinedButton.icon(
                  key: key,
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : OutlinedButton(key: key, onPressed: onTap, child: label);
        } else if (variant == 'text') {
          current = iconData != null
              ? TextButton.icon(
                  key: key,
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : TextButton(key: key, onPressed: onTap, child: label);
        } else {
          current = iconData != null
              ? ElevatedButton.icon(
                  key: key,
                  onPressed: onTap,
                  icon: iconData,
                  label: label,
                )
              : ElevatedButton(key: key, onPressed: onTap, child: label);
        }
        break;
      case 'card':
        final variant = props['variant']?.toString().toLowerCase();
        final elevation = (props['elevation'] as num?)?.toDouble();
        final color = _parseColor(props['color'], context);
        final borderRadius = (props['borderRadius'] as num?)?.toDouble() ?? 12;
        final child = resolvedChildren.isNotEmpty
            ? _buildWidget(resolvedChildren.first as Map<String, dynamic>)
            : const SizedBox.shrink();

        if (variant == 'outlined') {
          current = Card.outlined(
            key: key,
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
            key: key,
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
            key: key,
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
          key: key,
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
          key: key,
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
                    : null),
          onTap: onTap,
        );
        break;

      case 'switch':
        final val = _resolveValue(props['value']);
        final isTrue = val == true || val.toString().toLowerCase() == 'true';
        current = Switch(
          key: key,
          value: isTrue,
          onChanged: (val) {
            final onChange =
                def['onChanged'] ?? props['onChange'] ?? props['onChanged'];
            if (onChange != null) {
              if (onChange is String) {
                widget.engine.callFunction(onChange, {'value': val});
              } else if (onChange is Map && onChange.containsKey('call')) {
                widget.engine.callFunction(onChange['call'], {
                  'value': val,
                  ...?onChange['params'],
                });
              }
            }
          },
        );
        break;

      case 'expanded':
        current = Expanded(
          key: key,
          flex: (props['flex'] as num?)?.toInt() ?? 1,
          child: resolvedChildren.isNotEmpty
              ? _buildWidget(resolvedChildren.first as Map<String, dynamic>)
              : const SizedBox.shrink(),
        );
        break;

      case 'spacer':
        current = Spacer(key: key, flex: (props['flex'] as num?)?.toInt() ?? 1);
        break;

      case 'image':
        final url = _resolveValue(props['url'] ?? '').toString();
        final fitVal = props['fit']?.toString();
        BoxFit fit = BoxFit.cover;
        if (fitVal == 'contain') {
          fit = BoxFit.contain;
        } else if (fitVal == 'fill') {
          fit = BoxFit.fill;
        } else if (fitVal == 'fitWidth') {
          fit = BoxFit.fitWidth;
        } else if (fitVal == 'fitHeight') {
          fit = BoxFit.fitHeight;
        }

        Widget img;
        if (url.startsWith('http')) {
          img = Image.network(
            url,
            key: key,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (ctx, err, stack) => Container(
              width: width,
              height: height,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(Icons.broken_image, color: theme.colorScheme.error),
            ),
          );
        } else {
          img = Container(
            width: width,
            height: height,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Icons.image_not_supported,
              color: theme.colorScheme.outline,
            ),
          );
        }

        final radius = (props['borderRadius'] as num?)?.toDouble();
        if (radius != null && radius > 0) {
          img = ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: img,
          );
        }
        current = img;
        break;

      case 'text_field':
        final label = props['label']?.toString();
        final hintText = props['hintText']?.toString();
        final stateKey = props['stateKey']?.toString();

        TextEditingController? controller;
        if (stateKey != null) {
          controller = _controllers.putIfAbsent(stateKey, () {
            return TextEditingController(
              text: widget.engine.state[stateKey]?.toString(),
            );
          });

          // Sync controller if state changed externally
          final currentState = widget.engine.state[stateKey]?.toString() ?? '';
          if (controller.text != currentState) {
            // Only update if the difference is significant to avoid cursor jumps during typing
            // if we were using a reactive stream.
            // Since we use silent update for self-typing, this likely means external update.
            controller.text = currentState;
          }
        }

        current = TextField(
          key: key,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          controller: controller,
          onChanged: (val) {
            if (stateKey != null) {
              // Silent update to avoid rebuilding this widget and losing focus/cursor
              widget.engine.updateStateSilent(stateKey, val);
            }

            final onChange = def['onChanged'] ?? props['onChange'];
            if (onChange != null) {
              if (onChange is String) {
                widget.engine.callFunction(onChange, {'value': val});
              }
            }
          },
        );
        break;

      case 'container':
      default:
        current = Container(
          key: key,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(
              (props['borderRadius'] as num?)?.toDouble() ?? 0,
            ),
            border: props['borderColor'] != null
                ? Border.all(
                    color: _parseColor(props['borderColor'], context)!,
                    width: (props['borderWidth'] as num?)?.toDouble() ?? 1,
                  )
                : null,
          ),
          child: resolvedChildren.isNotEmpty
              ? _buildWidget(resolvedChildren.first as Map<String, dynamic>)
              : null,
        );
        if (onTap != null) {
          current = GestureDetector(onTap: onTap, child: current);
        }
        break;
    }

    if (padding != null) {
      current = Padding(padding: padding, child: current);
    }
    if (margin != null) {
      current = Padding(padding: margin, child: current);
    }

    return current;
  }

  // --- Helpers ---

  EdgeInsets? _parsePadding(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return EdgeInsets.all(value.toDouble());
    }
    if (value is List) {
      if (value.length == 2) {
        return EdgeInsets.symmetric(
          vertical: (value[0] as num).toDouble(),
          horizontal: (value[1] as num).toDouble(),
        );
      }
      if (value.length == 4) {
        return EdgeInsets.fromLTRB(
          (value[0] as num).toDouble(),
          (value[1] as num).toDouble(),
          (value[2] as num).toDouble(),
          (value[3] as num).toDouble(),
        );
      }
    }
    return null;
  }

  Color? _parseColor(dynamic value, BuildContext context) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return Color(value);
    }
    if (value is String) {
      // Theme color reference
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      switch (value) {
        case 'primary':
          return scheme.primary;
        case 'onPrimary':
          return scheme.onPrimary;
        case 'primaryContainer':
          return scheme.primaryContainer;
        case 'onPrimaryContainer':
          return scheme.onPrimaryContainer;
        case 'secondary':
          return scheme.secondary;
        case 'onSecondary':
          return scheme.onSecondary;
        case 'secondaryContainer':
          return scheme.secondaryContainer;
        case 'onSecondaryContainer':
          return scheme.onSecondaryContainer;
        case 'tertiary':
          return scheme.tertiary;
        case 'surface':
          return scheme.surface;
        case 'onSurface':
          return scheme.onSurface;
        case 'error':
          return scheme.error;
        case 'transparent':
          return Colors.transparent;
        default:
          if (value.startsWith('#')) {
            return Color(int.parse(value.substring(1), radix: 16) + 0xFF000000);
          }
      }
    }
    return null;
  }

  CrossAxisAlignment _parseCrossAxisAlignment(String? value) {
    switch (value) {
      case 'start':
        return CrossAxisAlignment.start;
      case 'end':
        return CrossAxisAlignment.end;
      case 'stretch':
        return CrossAxisAlignment.stretch;
      case 'center':
      default:
        return CrossAxisAlignment.center;
    }
  }

  MainAxisAlignment _parseMainAxisAlignment(String? value) {
    switch (value) {
      case 'start':
        return MainAxisAlignment.start;
      case 'end':
        return MainAxisAlignment.end;
      case 'spaceBetween':
        return MainAxisAlignment.spaceBetween;
      case 'spaceAround':
        return MainAxisAlignment.spaceAround;
      case 'spaceEvenly':
        return MainAxisAlignment.spaceEvenly;
      case 'center':
      default:
        return MainAxisAlignment.center;
    }
  }

  TextAlign _parseTextAlign(String? value) {
    switch (value) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
        return TextAlign.center;
      case 'justify':
        return TextAlign.justify;
      case 'start':
      default:
        return TextAlign.start;
    }
  }

  TextStyle _getThemeTextStyle(String name, ThemeData theme) {
    switch (name) {
      case 'displayLarge':
        return theme.textTheme.displayLarge!;
      case 'displayMedium':
        return theme.textTheme.displayMedium!;
      case 'displaySmall':
        return theme.textTheme.displaySmall!;
      case 'headlineLarge':
        return theme.textTheme.headlineLarge!;
      case 'headlineMedium':
        return theme.textTheme.headlineMedium!;
      case 'headlineSmall':
        return theme.textTheme.headlineSmall!;
      case 'titleLarge':
        return theme.textTheme.titleLarge!;
      case 'titleMedium':
        return theme.textTheme.titleMedium!;
      case 'titleSmall':
        return theme.textTheme.titleSmall!;
      case 'bodyLarge':
        return theme.textTheme.bodyLarge!;
      case 'bodyMedium':
        return theme.textTheme.bodyMedium!;
      case 'bodySmall':
        return theme.textTheme.bodySmall!;
      case 'labelLarge':
        return theme.textTheme.labelLarge!;
      case 'labelMedium':
        return theme.textTheme.labelMedium!;
      case 'labelSmall':
        return theme.textTheme.labelSmall!;
      default:
        return theme.textTheme.bodyMedium!;
    }
  }

  /// Resolve value, supporting state reference ($key)
  dynamic _resolveValue(dynamic value) {
    if (value is String && value.startsWith('\$')) {
      final key = value.substring(1);
      return widget.engine.state[key] ?? value;
    }
    return value;
  }

  /// Extract state keys referenced in widget definition
  List<String> _extractStateKeys(Map<String, dynamic> def) {
    final keys = <String>{};

    void scan(dynamic node) {
      if (node is String && node.startsWith('\$')) {
        keys.add(node.substring(1));
      } else if (node is Map) {
        for (var v in node.values) {
          scan(v);
        }
      } else if (node is List) {
        for (var v in node) {
          scan(v);
        }
      }
    }

    scan(def['props']);
    // Also scan switch value etc
    if (def['type'] == 'switch') {
      scan(def['value']); // Usually prop but just in case
    }

    // Scan children if it's a dynamic binding
    final children = def['children'];
    if (children is String && children.startsWith('\$')) {
      keys.add(children.substring(1));
    }

    return keys.toList();
  }
}
