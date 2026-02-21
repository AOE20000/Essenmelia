import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../manager/extension_manager.dart';

final gatewayServiceProvider = Provider<GatewayService>((ref) {
  return GatewayService(ref);
});

class GatewayService {
  final Ref _ref;
  final _appLinks = AppLinks();
  StreamSubscription? _sub;

  GatewayService(this._ref);

  Future<void> init() async {
    if (_sub != null) return;

    // Check initial link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('GatewayService: Initial Link Error: $e');
    }

    // Listen to link stream
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('GatewayService: Deep Link Error: $err');
      },
    );
  }

  void dispose() {
    _sub?.cancel();
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('GatewayService: Received Deep Link: $uri');
    if (uri.scheme != 'essenmelia') return;

    // Broadcast event to extensions
    // Event name: 'system.gateway.request'

    _ref
        .read(extensionManagerProvider)
        .broadcastEvent('system.gateway.request', {
          'url': uri.toString(),
          'path': uri.path,
          'params': uri.queryParameters,
          'source': 'deep_link',
        }, senderId: 'system');
  }
}
