import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import 'base_extension.dart';

/// 扩展 JS 逻辑引擎
class ExtensionJsEngine {
  final ExtensionMetadata metadata;
  final ExtensionApi api;
  final Map<String, dynamic> state = {};
  final Map<String, ValueNotifier<dynamic>> stateNotifiers = {};
  final List<String> logs = [];
  final ValueNotifier<List<String>> logsNotifier = ValueNotifier([]);

  late JavascriptRuntime _jsRuntime;
  bool _isInitialized = false;
  String? _error;

  VoidCallback? _onStateChanged;

  ExtensionJsEngine({required this.metadata, required this.api});

  bool get isInitialized => _isInitialized;
  String? get error => _error;

  void setOnStateChanged(VoidCallback? callback) => _onStateChanged = callback;

  void _addLog(String log) {
    final timestamp = DateTime.now().toString().split(' ').last.substring(0, 8);
    final formattedLog = '[$timestamp] $log';
    logs.add(formattedLog);
    if (logs.length > 200) logs.removeAt(0);
    logsNotifier.value = List.from(logs);
  }

  /// 获取特定状态的监听器
  ValueNotifier<dynamic> getStateNotifier(String key) {
    return stateNotifiers.putIfAbsent(key, () => ValueNotifier(state[key]));
  }

  /// 手动更新状态（用于调试或 API 回调）
  void updateState(String? key, dynamic value) {
    if (key != null) {
      state[key] = value;
      stateNotifiers[key]?.value = value;
      _onStateChanged?.call();
      _addLog('State Updated: $key = $value');

      // 通知 JS 引擎状态已同步
      _jsRuntime.evaluate(
        'if (typeof state !== "undefined") { state["$key"] = ${jsonEncode(value)}; }',
      );
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _jsRuntime = getJavascriptRuntime();

      // 1. 注入 API 桥接
      _setupApiBridges();

      // 2. 注入日志监听
      _jsRuntime.onMessage('console_log', (dynamic message) {
        _addLog('JS: $message');
        debugPrint('JS Log: $message');
      });

      _jsRuntime.evaluate('''
        var originalLog = console.log;
        console.log = function() {
          var args = Array.prototype.slice.call(arguments);
          var message = args.map(a => {
            if (a === null) return "null";
            if (a === undefined) return "undefined";
            if (typeof a === 'object') {
              try { return JSON.stringify(a); } catch(e) { return "[Object]"; }
            }
            return String(a);
          }).join(' ');
          sendMessage('console_log', message);
          originalLog.apply(console, arguments);
        };
      ''');

      _addLog('Initializing Engine...');

      // 3. 加载扩展脚本
      if (metadata.script != null) {
        // 使用 evaluate 替代 evaluateAsync 以避免 Promise 挂起导致的初始化阻塞
        final result = _jsRuntime.evaluate(metadata.script!);
        if (result.isError) {
          _error = result.toString();
          _addLog('JS Init Error: $_error');
          debugPrint('JS Init Error: $_error');
        }
      }

      // 4. 执行 onLoad (如果存在)
      // onLoad 通常包含异步逻辑，我们在后台执行它，不阻塞 isInitialized 的标记
      _isInitialized = true;
      _addLog('Engine Logic Loaded');

      callFunction('onLoad')
          .then((_) {
            _addLog('onLoad completed');
          })
          .catchError((e) {
            _addLog('onLoad Error: $e');
          });
    } catch (e) {
      _error = e.toString();
      _addLog('Engine Setup Error: $e');
      debugPrint('JS Engine Setup Error: $e');
    }
  }

  void dispose() {
    _jsRuntime.dispose();
    logsNotifier.dispose();
    for (var v in stateNotifiers.values) {
      v.dispose();
    }
  }

  void _setupApiBridges() {
    _jsRuntime.onMessage('essenmelia_api', (dynamic args) async {
      // 如果 args 是 JSON 字符串，则解析它
      Map<String, dynamic> data;
      if (args is String) {
        try {
          data = jsonDecode(args);
        } catch (e) {
          debugPrint('essenmelia_api JSON parse error: $e');
          return null;
        }
      } else if (args is Map) {
        data = Map<String, dynamic>.from(args);
      } else {
        return null;
      }

      final String method = data['method'];
      final Map<String, dynamic> params = data['params'] ?? {};

      _addLog('API Call: $method');

      try {
        switch (method) {
          case 'getEvents':
            final events = await api.getEvents();
            return events.map((e) => e.toJson()).toList();
          case 'getTags':
            return await api.getTags();
          case 'showSnackBar':
            api.showSnackBar(params['message']?.toString() ?? '');
            return null;
          case 'showConfirmDialog':
            return await api.showConfirmDialog(
              title: params['title']?.toString() ?? '',
              message: params['message']?.toString() ?? '',
              confirmLabel: params['confirmLabel']?.toString() ?? '确定',
              cancelLabel: params['cancelLabel']?.toString() ?? '取消',
            );
          case 'navigateTo':
            api.navigateTo(params['route']?.toString() ?? '');
            return null;
          case 'addEvent':
            await api.addEvent(
              title: params['title']?.toString() ?? '未命名任务',
              description: params['description']?.toString(),
              tags: params['tags'] != null
                  ? List<String>.from(params['tags'])
                  : null,
            );
            return null;
          default:
            return await api.call(method, params);
        }
      } catch (e) {
        _addLog('API Error ($method): $e');
        debugPrint('JS Bridge Error ($method): $e');
        throw e.toString();
      }
    });

    // 状态更新桥接：essenmelia.updateState(key, value)
    _jsRuntime.onMessage('essenmelia_state', (dynamic args) {
      Map<String, dynamic> data;
      if (args is String) {
        try {
          data = jsonDecode(args);
        } catch (e) {
          debugPrint('essenmelia_state JSON parse error: $e');
          return;
        }
      } else if (args is Map) {
        data = Map<String, dynamic>.from(args);
      } else {
        return;
      }

      final key = data['key']?.toString();
      final value = data['value'];
      updateState(key, value);
    });

    // 注入全局对象和助手函数
    _jsRuntime.evaluate('''
      var state = {};
      var essenmelia = {
        call: async function(method, params) {
          var result = await sendMessage('essenmelia_api', JSON.stringify({ method: method, params: params || {} }));
          if (typeof result === 'string') {
            try { return JSON.parse(result); } catch(e) { return result; }
          }
          return result;
        },
        updateState: function(key, value) {
          state[key] = value;
          sendMessage('essenmelia_state', JSON.stringify({ key: key, value: value }));
        },
        getEvents: () => essenmelia.call('getEvents'),
        showSnackBar: (msg) => essenmelia.call('showSnackBar', { message: msg }),
        showConfirmDialog: (args) => {
          if (typeof args === 'string') {
            return essenmelia.call('showConfirmDialog', { title: arguments[0], message: arguments[1] });
          }
          return essenmelia.call('showConfirmDialog', args);
        }
      };
    ''');
  }

  Future<dynamic> callFunction(String name, [dynamic params]) async {
    try {
      final paramsJson = jsonEncode(params ?? {});
      final code = 'if (typeof $name === "function") { $name($paramsJson); }';
      final result = await _jsRuntime.evaluateAsync(code);
      if (result.isError) {
        debugPrint('JS Execution Error ($name): ${result.toString()}');
        return null;
      }
      return result.stringResult;
    } catch (e) {
      debugPrint('JS Execution Exception ($name): $e');
      return null;
    }
  }

  void handleEvent(String name, Map<String, dynamic> data) {
    callFunction('onEvent', {'name': name, 'data': data});
  }
}
