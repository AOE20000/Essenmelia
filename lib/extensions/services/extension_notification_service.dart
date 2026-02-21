import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/notification_service.dart';

final extensionNotificationServiceProvider =
    Provider<ExtensionNotificationService>((ref) {
      final service = ExtensionNotificationService();
      ref.onDispose(() => service.dispose());
      return service;
    });

class ExtensionNotificationService {
  final NotificationService _notificationService = NotificationService();
  final Map<String, VoidCallback> _blockCallbacks = {};
  StreamSubscription? _subscription;

  // Track last progress to avoid spamming updates
  final Map<String, DateTime> _lastUpdate = {};

  ExtensionNotificationService() {
    _initListener();
  }

  void _initListener() {
    _subscription = _notificationService.onResponse.listen((response) {
      final payload = response.payload;
      if (payload != null && payload.startsWith('block:')) {
        final extensionId = payload.substring(6);
        final callback = _blockCallbacks[extensionId];
        if (callback != null) {
          debugPrint(
            'ExtensionNotificationService: Blocking $extensionId via notification action',
          );
          callback();
          _blockCallbacks.remove(extensionId);

          // Dismiss the warning notification
          _notificationService.cancel(extensionId.hashCode);
        } else {
          debugPrint(
            'ExtensionNotificationService: Block callback not found for $extensionId',
          );
        }
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  void showProgress(String extensionId, double progress, String message) {
    final now = DateTime.now();
    final last = _lastUpdate[extensionId];

    // Throttle updates: Max 2 per second unless complete or started
    if (progress < 1.0 &&
        progress > 0.0 &&
        last != null &&
        now.difference(last).inMilliseconds < 500) {
      return;
    }
    _lastUpdate[extensionId] = now;

    int progressInt = (progress * 100).toInt();
    if (progress < 0) progressInt = -1; // Indeterminate

    // On Windows/iOS, we might want to append percentage to body if progress bar isn't supported
    String displayBody = message;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      if (progress >= 0) {
        displayBody = '${(progress * 100).toInt()}% - $message';
      }
    }

    _notificationService.showProgress(
      id: extensionId.hashCode,
      title: '扩展运行中: $extensionId',
      body: displayBody,
      progress: progressInt,
      maxProgress: 100,
      channelName: 'Extension Tasks',
      channelDescription: 'Shows progress of running extensions',
    );

    // Auto dismiss if complete
    if (progress >= 1.0) {
      // Delay slightly to let user see 100%
      Future.delayed(const Duration(seconds: 1), () {
        _notificationService.cancel(extensionId.hashCode);
      });
      _lastUpdate.remove(extensionId);
    }
  }

  void showWarning(String extensionId, String message, VoidCallback onBlock) {
    _blockCallbacks[extensionId] = onBlock;

    _notificationService.showWarning(
      id: extensionId.hashCode,
      title: '扩展异常警告: $extensionId',
      body: message,
      payload: 'block:$extensionId',
      actionId: 'block_extension',
      actionLabel: '阻止运行',
      channelName: 'Extension Warnings',
      channelDescription: 'Alerts when extensions behave abnormally',
    );
  }
}
