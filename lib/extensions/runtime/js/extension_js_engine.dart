import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_js/flutter_js.dart';
import '../../core/extension_api.dart';
import '../../core/extension_metadata.dart';

/// Extension JS Logic Engine
///
/// This engine provides a robust bridge between Dart and JS, supporting:
/// 1. Async function calls from JS to Dart (with Promise support)
/// 2. Async function calls from Dart to JS
/// 3. State synchronization (Reactive)
/// 4. Event handling
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

  /// Get listener for specific state
  ValueNotifier<dynamic> getStateNotifier(String key) {
    return stateNotifiers.putIfAbsent(key, () => ValueNotifier(state[key]));
  }

  /// Manually update state (for debugging or API callbacks)
  void updateState(String? key, dynamic value) {
    if (key != null) {
      state[key] = value;
      stateNotifiers[key]?.value = value;
      _onStateChanged?.call();
      _addLog('State Updated: $key = $value');

      // Notify JS engine state synced
      // Security Fix: Escape key with jsonEncode to prevent JS injection
      final safeKey = jsonEncode(key);
      _jsRuntime.evaluate(
        'if (typeof _state !== "undefined") { _state[$safeKey] = ${jsonEncode(value)}; }',
      );
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _jsRuntime = getJavascriptRuntime();

      // 1. Inject API bridges
      _setupApiBridges();

      // 2. Inject log listener
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

      // 3. Load extension script
      if (metadata.script != null) {
        // Use evaluate instead of evaluateAsync to avoid Promise hang blocking initialization
        final result = _jsRuntime.evaluate(metadata.script!);
        if (result.isError) {
          _error = result.toString();
          _addLog('JS Init Error: $_error');
          debugPrint('JS Init Error: $_error');
        }
      }

      // 4. Execute onLoad (if exists)
      // onLoad usually contains async logic, we run it in background, not blocking isInitialized flag
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
    _isInitialized = false;
    try {
      _jsRuntime.dispose();
    } catch (_) {}
    logsNotifier.dispose();
    for (var v in stateNotifiers.values) {
      v.dispose();
    }
  }

  void _setupApiBridges() {
    // Robust Async Bridge: JS -> Dart
    // JS calls `sendMessage('essenmelia_api_call', {id, method, params})`
    // Dart processes and calls `_resolveRequest(id, result)` or `_rejectRequest(id, error)`
    _jsRuntime.onMessage('essenmelia_api_call', (dynamic args) async {
      Map<String, dynamic> data;
      if (args is String) {
        try {
          data = jsonDecode(args);
        } catch (e) {
          debugPrint('essenmelia_api_call JSON parse error: $e');
          return;
        }
      } else if (args is Map) {
        data = Map<String, dynamic>.from(args);
      } else {
        return;
      }

      final String id = data['id'];
      final String method = data['method'];
      final Map<String, dynamic> params = data['params'] ?? {};

      _addLog('API Call ($id): $method');

      try {
        dynamic result;
        switch (method) {
          case 'getEvents':
            final events = await api.getEvents();
            result = events.map((e) => e.toJson()).toList();
            break;
          case 'getTags':
            result = await api.getTags();
            break;
          case 'showSnackBar':
            api.showSnackBar(params['message']?.toString() ?? '');
            result = null;
            break;
          case 'showConfirmDialog':
            result = await api.showConfirmDialog(
              title: params['title']?.toString() ?? '',
              message: params['message']?.toString() ?? '',
              confirmLabel: params['confirmLabel']?.toString() ?? '确定',
              cancelLabel: params['cancelLabel']?.toString() ?? '取消',
            );
            break;
          case 'navigateTo':
            api.navigateTo(params['route']?.toString() ?? '');
            result = null;
            break;
          case 'addEvent':
            await api.addEvent(
              title: params['title']?.toString() ?? '未命名任务',
              description: params['description']?.toString(),
              tags: params['tags'] != null
                  ? List<String>.from(params['tags'])
                  : null,
            );
            result = null;
            break;
          default:
            result = await api.call(method, params);
        }

        // Send success response to JS
        final safeId = jsonEncode(id);
        final safeResult = jsonEncode(result);
        _jsRuntime.evaluate('_resolveRequest($safeId, $safeResult);');
      } catch (e) {
        _addLog('API Error ($method): $e');
        debugPrint('JS Bridge Error ($method): $e');

        // Send error response to JS
        final safeId = jsonEncode(id);
        final safeError = jsonEncode(e.toString());
        _jsRuntime.evaluate('_rejectRequest($safeId, $safeError);');
      }
    });

    // State update bridge: essenmelia.updateState(key, value)
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

    // Inject global object and helpers
    _jsRuntime.evaluate('''
      var _pendingRequests = {};
      var _state = {};
      
      // Global helpers for Dart to call back
      function _resolveRequest(id, result) {
        if (_pendingRequests[id]) {
          _pendingRequests[id].resolve(result);
          delete _pendingRequests[id];
        }
      }
      
      function _rejectRequest(id, error) {
        if (_pendingRequests[id]) {
          _pendingRequests[id].reject(error);
          delete _pendingRequests[id];
        }
      }

      // State Proxy
      var state = new Proxy(_state, {
        set: function(target, prop, value) {
          target[prop] = value;
          essenmelia.updateState(prop, value);
          return true;
        }
      });

      // API Object
      var essenmelia = {
        call: function(method, params) {
          return new Promise((resolve, reject) => {
            var id = 'req_' + Math.random().toString(36).substr(2, 9);
            _pendingRequests[id] = { resolve: resolve, reject: reject };
            
            sendMessage('essenmelia_api_call', JSON.stringify({
              id: id,
              method: method,
              params: params || {}
            }));
            
            // Timeout safety (30s)
            setTimeout(() => {
              if (_pendingRequests[id]) {
                _pendingRequests[id].reject('Timeout');
                delete _pendingRequests[id];
              }
            }, 30000);
          });
        },
        
        updateState: function(key, value) {
          _state[key] = value;
          sendMessage('essenmelia_state', JSON.stringify({ key: key, value: value }));
        },
        
        // Convenience wrappers
        getEvents: () => essenmelia.call('getEvents'),
        showSnackBar: (msg) => essenmelia.call('showSnackBar', { message: msg }),
        showConfirmDialog: function(args) {
          if (typeof args === 'string') {
            return essenmelia.call('showConfirmDialog', { title: arguments[0], message: arguments[1] });
          }
          return essenmelia.call('showConfirmDialog', args);
        }
      };
    ''');
  }

  Future<dynamic> callFunction(String name, [dynamic params]) async {
    if (!_isInitialized) {
      debugPrint('JS Engine not initialized, skipping $name');
      return null;
    }
    try {
      final paramsJson = jsonEncode(params ?? {});
      // Use try-catch wrap JS call, and explicitly return JSON string or null
      // Security Fix: Use globalThis[name] form call, and verify name is safe string, prevent injection
      final safeName = jsonEncode(name);
      final code =
          '''
        (function() {
          var funcName = $safeName;
          var func = globalThis[funcName];
          if (typeof func === "function") {
            try {
              var result = func($paramsJson);
              if (result instanceof Promise) {
                return result.then(r => JSON.stringify(r)).catch(e => JSON.stringify({error: e.toString()}));
              }
              return JSON.stringify(result);
            } catch (e) {
              return JSON.stringify({error: e.toString()});
            }
          }
          return null;
        })()
      ''';

      final result = await _jsRuntime.evaluateAsync(code);
      if (result.isError) {
        debugPrint('JS Execution Error ($name): ${result.toString()}');
        return null;
      }

      final rawResult = result.stringResult;
      if (rawResult == 'null' || rawResult == 'undefined') {
        return null;
      }

      try {
        return jsonDecode(rawResult);
      } catch (e) {
        // If not JSON format, return raw string
        return rawResult;
      }
    } catch (e) {
      debugPrint('JS Execution Exception ($name): $e');
      return null;
    }
  }

  void handleEvent(String name, Map<String, dynamic> data) {
    callFunction('onEvent', {'name': name, 'data': data});
  }
}
