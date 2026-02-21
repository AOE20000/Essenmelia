import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../extensions/core/globals.dart'; // for navigatorKey
import '../extensions/runtime/api/extension_api_registry.dart';
import '../extensions/manager/extension_manager.dart';

final commandGatewayServiceProvider = Provider<CommandGatewayService>((ref) {
  return CommandGatewayService(ref);
});

class CommandGatewayService {
  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  CommandGatewayService(this._ref);

  void init() {
    _initDeepLinks();
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  Future<void> _initDeepLinks() async {
    // Handle the initial link if the app was started via a deep link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('CommandGateway: Failed to get initial link: $e');
    }

    // Listen for subsequent links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('CommandGateway: Link stream error: $err');
      },
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint('CommandGateway: Received link: $uri');

    // Expected format: essenmelia://command/{methodName}?param1=value1&param2=value2
    // or: essenmelia://gateway?method={methodName}&params={json_params}

    if (uri.scheme != 'essenmelia' && uri.scheme != 'esml') return;

    String? methodName;
    Map<String, dynamic> params = {};

    if (uri.host == 'command') {
      // Path based: essenmelia://command/addEvent
      if (uri.pathSegments.isNotEmpty) {
        methodName = uri.pathSegments.first;
        // Query parameters as params
        params = Map.from(uri.queryParameters);
      }
    } else if (uri.host == 'gateway') {
      // Query based: essenmelia://gateway?method=addEvent&params={...}
      methodName = uri.queryParameters['method'];
      final paramsStr = uri.queryParameters['params'];
      if (paramsStr != null) {
        try {
          params = jsonDecode(paramsStr);
        } catch (e) {
          debugPrint('CommandGateway: Failed to decode params: $e');
          _showErrorDialog('Invalid parameters format (JSON expected)');
          return;
        }
      } else {
        // Merge other query params if 'params' is not provided
        params = Map.from(uri.queryParameters);
        params.remove('method');
      }
    }

    if (methodName == null || methodName.isEmpty) {
      _showErrorDialog('Invalid command: Method name missing');
      return;
    }

    // Security Check: Ask user for permission
    final approved = await _showConfirmationDialog(methodName, params);
    if (!approved) {
      debugPrint('CommandGateway: User denied command $methodName');
      return;
    }

    _executeCommand(methodName, params);
  }

  Future<void> _executeCommand(
    String methodName,
    Map<String, dynamic> params,
  ) async {
    try {
      // Ensure ExtensionManager is initialized so services are registered
      _ref.read(extensionManagerProvider);

      final registry = _ref.read(extensionApiRegistryProvider);
      final handler = registry.getHandler(methodName);

      if (handler == null) {
        _showErrorDialog('Unknown command: $methodName');
        return;
      }

      // Execute with isUntrusted: false because the user explicitly approved it
      // We wrap it in a try-catch to show result
      final result = await handler(params, isUntrusted: false);

      _showSuccessDialog(methodName, result);
    } catch (e) {
      debugPrint('CommandGateway: Execution error: $e');
      _showErrorDialog('Execution failed: $e');
    }
  }

  Future<bool> _showConfirmationDialog(
    String method,
    Map<String, dynamic> params,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('External Command Request'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'An external application is requesting to execute:',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Method: $method',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Parameters:'),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(params),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Do you want to allow this action?',
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Deny'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Allow'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showErrorDialog(String message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Command Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String method, dynamic result) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Optional: Only show for interesting results or if requested
    // For now, let's show a snackbar instead of a dialog for success to be less intrusive
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Command "$method" executed successfully'),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Execution Result'),
                content: SingleChildScrollView(child: Text(result.toString())),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
