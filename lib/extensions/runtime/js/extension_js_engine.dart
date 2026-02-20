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
  Future<void>? _initFuture;
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

  /// Update state without notifying Dart listeners (prevents UI rebuild loop)
  /// But syncs to JS engine.
  void updateStateSilent(String? key, dynamic value) {
    if (key != null) {
      state[key] = value;
      // Sync to JS
      final safeKey = jsonEncode(key);
      _jsRuntime.evaluate(
        'if (typeof _state !== "undefined") { _state[$safeKey] = ${jsonEncode(value)}; }',
      );
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _doInit();
    return _initFuture;
  }

  Future<void> _doInit() async {
    try {
      _jsRuntime = getJavascriptRuntime();

      // 1. Inject API bridges
      _setupApiBridges();

      // 2. Inject log listener
      _jsRuntime.onMessage('console_log', (dynamic message) {
        String logMessage;
        if (message is String) {
          logMessage = message;
        } else {
          try {
            logMessage = jsonEncode(message);
          } catch (e) {
            logMessage = message.toString();
          }
        }
        _addLog('JS: $logMessage');
        debugPrint('JS Log: $logMessage');
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
          sendMessage('console_log', JSON.stringify(message));
          originalLog.apply(console, arguments);
        };
      ''');

      _addLog('Initializing Engine...');

      // Inject initial state
      final initialStateJson = jsonEncode(state);
      _jsRuntime.evaluate('''
        var _rawState = $initialStateJson;
        var _pendingRender = {};
        var _renderTimer = null;

        function _flushRender() {
          // Clear timer flag immediately to allow new schedules if this one fails/finishes
          var currentTimer = _renderTimer;
          _renderTimer = null; 
          
          if (!currentTimer) return;
          
          try {
            var payload = _pendingRender;
            _pendingRender = {}; // Clear pending immediately
            
            var msg = JSON.stringify({
              type: 'render',
              payload: payload
            });
            if (typeof sendMessage === 'function') {
              sendMessage('essenmelia_bridge', msg);
            } else {
              console.log("Render Error: sendMessage not found");
            }
          } catch (e) {
            console.log("State Proxy Flush Error: " + e);
          }
        }

        var _state = new Proxy(_rawState, {
          set: function(obj, prop, value) {
            obj[prop] = value;
            try {
              _pendingRender[prop] = value;
              if (!_renderTimer) {
                // Debounce render updates to next microtask/tick
                _renderTimer = Promise.resolve().then(_flushRender);
              }
            } catch (e) {
              console.log("State Proxy Error: " + e);
            }
            return true;
          }
        });
      ''');

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
      _isInitialized = true;
      _addLog('Engine Logic Loaded');

      callFunction('onLoad')
          .then((_) {
            _addLog('onLoad completed');
          })
          .catchError((e) {
            _addLog('onLoad Error: $e');
          });
    } catch (e, stack) {
      _error = e.toString();
      _addLog('Init Error: $e');
      debugPrint('JS Engine Init Error: $e\n$stack');
      rethrow;
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
    // Unified Bridge: JS -> Dart
    // JS calls `sendMessage('essenmelia_bridge', {type, payload})`
    _jsRuntime.onMessage('essenmelia_bridge', (dynamic args) async {
      debugPrint(
        'ExtensionJsEngine: Received message on essenmelia_bridge: $args',
      );
      try {
        Map<String, dynamic> msg;
        if (args is String) {
          try {
            msg = jsonDecode(args);
          } catch (e) {
            debugPrint('ExtensionJsEngine: JSON Decode Error: $e');
            return;
          }
        } else if (args is Map) {
          msg = Map<String, dynamic>.from(args);
        } else {
          debugPrint(
            'Extension Bridge: Unknown message type: ${args.runtimeType}',
          );
          return;
        }

        final type = msg['type'];
        final payload = msg['payload'];
        debugPrint('ExtensionJsEngine: Processing message type: $type');

        if (type == 'api_call') {
          // Handle API Call
          final id = payload['id'];
          final method = payload['method'];
          final params = payload['params'] as Map<String, dynamic>? ?? {};

          _addLog('API Call ($id): $method');
          debugPrint('ExtensionJsEngine: Invoking API $method ($id)');

          try {
            dynamic result;
            // Automatically route all calls to ExtensionApiImpl
            result = await api.call(method, params);

            debugPrint('ExtensionJsEngine: API $method ($id) Success');
            // Send success response
            final safeId = jsonEncode(id);
            final safeResult = jsonEncode(result);
            
            // Use evaluateAsync to ensure microtasks are processed (essential for Promise resolution)
            final evalFuture = _jsRuntime.evaluateAsync(
              '_resolveRequest($safeId, $safeResult);',
            );
            final evalRes = await evalFuture;

            if (evalRes.isError) {
              debugPrint(
                'ExtensionJsEngine: Resolve JS Error: ${evalRes.toString()}',
              );
              _addLog('Resolve JS Error: ${evalRes.toString()}');
            } else {
              debugPrint('ExtensionJsEngine: Resolve JS Success');
              try {
                _jsRuntime.executePendingJob();
              } catch (e) {
                // Ignore if not supported by current runtime
              }
            }
          } catch (e) {
            debugPrint('ExtensionJsEngine: API $method ($id) Error: $e');
            _addLog('API Error ($id): $e');
            final safeId = jsonEncode(id);
            final safeError = jsonEncode(e.toString());
            _jsRuntime.evaluateAsync('_rejectRequest($safeId, $safeError);');
          }
        } else if (type == 'render') {
          // Handle Render
          if (payload != null) {
            try {
              // Ensure payload is Map<String, dynamic>
              Map<String, dynamic> stateMap;
              if (payload is String) {
                stateMap = jsonDecode(payload);
              } else {
                stateMap = Map<String, dynamic>.from(payload as Map);
              }

              stateMap.forEach((key, value) {
                state[key] = value;
                // Update notifier if exists
                if (stateNotifiers.containsKey(key)) {
                  stateNotifiers[key]!.value = value;
                }
              });

              _onStateChanged?.call();
            } catch (e) {
              _addLog('Render Error (Dart): $e');
            }
          }
        } else {
          debugPrint('Extension Bridge: Unknown message type: $type');
        }
      } catch (e) {
        debugPrint('Extension Bridge Error: $e');
      }
    });

    _jsRuntime.evaluate('''
      if (typeof essenmelia === 'undefined') {
        var essenmelia = {};
      }
      
      // Inject render function
      function render() {
        if (typeof _state !== 'undefined') {
          // Send shallow copy or full state? 
          // _state is the source of truth.
          try {
            var msg = JSON.stringify({
              type: 'render',
              payload: _state
            });
            sendMessage('essenmelia_bridge', msg);
          } catch(e) {
            console.log("Render Error: " + e);
          }
        }
      }

      essenmelia._requests = {};
      
      essenmelia.call = function(method, params) {
        return new Promise(function(resolve, reject) {
          var id = 'req_' + Math.random().toString(36).substr(2, 9);
          try {
            console.log("JS: Call " + method + " id=" + id);
            essenmelia._requests[id] = { resolve: resolve, reject: reject };
            var msg = JSON.stringify({
              type: 'api_call',
              payload: {
                id: id,
                method: method,
                params: params || {}
              }
            });
            
            if (typeof sendMessage === 'function') {
              sendMessage('essenmelia_bridge', msg);
              console.log("JS: Call Sent " + id);
            } else {
              console.log("JS: Critical Error - sendMessage not found");
              reject("Runtime Error: sendMessage not found");
            }
          } catch (e) {
            console.log("JS: Call Error " + e);
            if (essenmelia._requests[id]) {
              delete essenmelia._requests[id];
            }
            reject("Call Error: " + e);
          }
        });
      };
      
      essenmelia.httpGet = async function(url, headers) {
        var result = await essenmelia.call('httpGet', {url: url, headers: headers});
        if (typeof result === 'string') {
          // Try parse JSON automatically? Or let caller do it?
          // Bangumi API returns JSON.
          // But httpGet contract says String?
          // If we parse here, we break contract if caller expects string.
          // But main.js code does JSON.parse(resStr).
          // If result is already object, JSON.parse fails?
          // No, JSON.parse(object) => stringifies object then parses it?
          // No, JSON.parse("[object Object]") throws.
          // Let's keep it simple.
          return result;
        }
        return result;
      };
      
      // Helper to resolve request from Dart
      function _resolveRequest(id, result) {
        console.log("JS: _resolveRequest called for " + id);
        if (essenmelia._requests[id]) {
          try {
            // Need to parse if result is a JSON string of an object, 
            // but api results are often just values or strings.
            // If result was jsonEncoded in Dart, it's a string here.
            // But if the original result was a Map/List, it's a JSON string now.
            // The caller expects the raw object if it was JSON.
            // However, our bridge sends strings.
            // If the user expects an object, they should JSON.parse it?
            // Or should we auto-parse if it looks like JSON?
            // Currently, httpGet returns a String (the body).
            // So result is "<body>".
            // If we JSON.parse it, we get the body string.
            // If the body itself is JSON, the user must parse it again.
            // This seems correct for httpGet.
            
            essenmelia._requests[id].resolve(result);
            console.log("JS: Promise Resolved for " + id);
          } catch(e) {
            console.log("JS: Promise Resolve Error: " + e);
          }
          delete essenmelia._requests[id];
        } else {
          console.log("JS: Request not found " + id);
        }
      }
      
      // Helper to reject request from Dart
      function _rejectRequest(id, error) {
        console.log("JS: _rejectRequest called for " + id + " error: " + error);
        if (essenmelia._requests[id]) {
            try {
              essenmelia._requests[id].reject(error);
            } catch(e) {
            console.log("JS: Promise Reject Error: " + e);
          }
          delete essenmelia._requests[id];
        }
      }
      
      // State sync
      // _state is initialized in _doInit with Proxy
      
      essenmelia.getState = function(key) {
        return _state[key];
      };
      
      // Add more helpers as needed
      essenmelia.addEvent = function(event) {
        return essenmelia.call('addEvent', event);
      };
      
      essenmelia.httpGet = async function(url, headers) {
        return essenmelia.call('httpGet', {url: url, headers: headers});
      };
      
      essenmelia.showSnackBar = function(message) {
        return essenmelia.call('showSnackBar', {message: message});
      };
    ''');
  }

  /// Call a JS function from Dart
  Future<dynamic> callFunction(String name, [dynamic params]) async {
    if (!_isInitialized) return null;

    final safeName = name; // Basic validation could be added
    String code;

    if (params != null) {
      try {
        final safeParams = jsonEncode(params);
        code = '$safeName($safeParams)';
      } catch (e) {
        _addLog('JSON Encode Error ($name): $e');
        rethrow;
      }
    } else {
      code = '$safeName()';
    }

    try {
      // evaluateAsync is better for function calls that might return Promises
    // But FlutterJs evaluateAsync result handling is tricky.
    // For now, we use evaluateAsync if possible to ensure Promises don't hang.
    // This is crucial for functions that use await.
    
    // We don't await the result here because the JS function might be long-running or return a Promise.
    // If we await, we might block Dart if the JS promise never resolves (though evaluateAsync usually returns the Promise object immediately).
    // But if we want the actual result of the function, we should await.
    // However, for void functions or UI updates, fire-and-forget is okay.
    // But to ensure the JS event loop runs, evaluateAsync is preferred.
    
    final evalFuture = _jsRuntime.evaluateAsync(code);
    
    // We wait for the evaluation to complete (which means the function started and returned its initial result/promise)
    final result = await evalFuture;
    
    // Force microtask flush if needed
    try {
      _jsRuntime.executePendingJob();
    } catch (e) {
      // Ignore
    }

    if (result.isError) {
        String errorMsg;
        try {
          errorMsg = result.toString();
        } catch (e) {
          errorMsg = 'Unknown JS Error';
        }
        _addLog('JS Error ($name): $errorMsg');
        throw errorMsg;
      }

      // If the result is a Promise (in JS), we can't easily await it from here
      // unless we use the callback mechanism.
      // For simple sync functions or fire-and-forget, this is fine.
      return result.rawResult;
    } catch (e) {
      String errorMsg;
      try {
        errorMsg = e.toString();
      } catch (_) {
        errorMsg = 'Unknown Call Error';
      }
      _addLog('Call Error ($name): $errorMsg');
      rethrow;
    }
  }

  void handleEvent(String name, Map<String, dynamic> data) {
    if (!_isInitialized) return;

    // Call onEvent(name, data) in JS if it exists
    final safeName = jsonEncode(name);
    final safeData = jsonEncode(data);

    _jsRuntime.evaluate('''
      if (typeof onEvent === 'function') {
        onEvent($safeName, $safeData);
      }
    ''');
  }
}
