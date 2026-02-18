import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/extension_metadata.dart';
import '../core/extension_permission.dart';
import '../core/globals.dart';
import 'extension_auth_notifier.dart';
import '../widgets/permission_management_dialog.dart';
import 'security_providers.dart';

abstract class SecurityShieldDelegate {
  void resumeExtension(String extensionId);
  void notifyPermissionGranted(
    String extensionId,
    ExtensionPermission permission,
  );
}

class SecurityShield {
  final Ref _ref;
  final SecurityShieldDelegate _delegate;

  // Dialog cooldowns to prevent DoS
  final Map<String, DateTime> _dialogCooldowns = {};
  // Active privacy requests to prevent multiple dialogs for same request
  final Set<String> _activePrivacyRequests = {};

  // Dialog showing lock
  bool _isDialogShowing = false;
  Future<void>? _currentDialogFuture;

  SecurityShield(this._ref, this._delegate);

  /// Permission management interception logic (Non-blocking + Post-hoc authorization)
  Future<bool> intercept(
    ExtensionMetadata metadata,
    String operation,
    String category, {
    ExtensionPermission? permission,
  }) async {
    final notifier = _ref.read(extensionAuthStateProvider.notifier);
    final extId = metadata.id;

    // If extension is disabled, return false immediately (with fake delay)
    if (!notifier.isRunning(extId)) {
      await Future.delayed(
        Duration(milliseconds: 100 + (DateTime.now().millisecond % 300)),
      );
      return false;
    }

    // If untrusted mode is not enabled, allow access
    if (!notifier.isUntrusted(extId)) return true;

    // Check persistent permissions
    if (permission != null && notifier.hasPermission(extId, permission)) {
      return true;
    }

    // Check next run permissions
    final permKey = permission?.name ?? category;
    if (await notifier.consumeNextRunPermission(extId, permKey)) {
      return true;
    }

    // Check session permissions
    final sessionPerms = _ref.read(sessionPermissionsProvider)[extId] ?? {};
    if (sessionPerms.contains('all') || sessionPerms.contains(permKey)) {
      return true;
    }

    // --- Core change: Pause extension and return fake data instead of blocking ---

    // 1. Check dialog cooldown (DoS protection)
    final cooldownKey = '${extId}_${permission?.name ?? "general"}';
    final lastShow = _dialogCooldowns[cooldownKey];
    if (lastShow != null && DateTime.now().difference(lastShow).inMinutes < 5) {
      // 5 minutes cooldown, return fake data directly
      return false;
    }
    _dialogCooldowns[cooldownKey] = DateTime.now();

    // 2. Mark as paused to prevent event interference
    notifier.setPaused(extId, true);

    // 3. Show dialog asynchronously (do not await here)
    _showPrivacyDialogAsync(
      metadata,
      operation,
      category,
      permission: permission,
    );

    // 4. Simulate normal latency then return false (guide extension to use fake data)
    await Future.delayed(Duration(milliseconds: 150 + (extId.hashCode % 150)));
    return false;
  }

  void _showPrivacyDialogAsync(
    ExtensionMetadata metadata,
    String operation,
    String category, {
    ExtensionPermission? permission,
  }) {
    final requestId = '${metadata.id}_${permission?.name ?? category}';

    // 1. Ignore if request is already being processed
    if (_activePrivacyRequests.contains(requestId)) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) return;

    _activePrivacyRequests.add(requestId);

    Future.microtask(() async {
      try {
        // 2. Wait for previous dialog to close
        if (_isDialogShowing && _currentDialogFuture != null) {
          await _currentDialogFuture!.timeout(
            const Duration(seconds: 3),
            onTimeout: () => null,
          );
        }

        // 3. Check if still needed
        final authNotifier = _ref.read(extensionAuthStateProvider.notifier);
        if (!authNotifier.isPaused(metadata.id)) {
          return;
        }

        if (_isDialogShowing) return;

        if (!context.mounted) return;

        _isDialogShowing = true;
        final completer = Completer<void>();
        _currentDialogFuture = completer.future;

        try {
          final decision = await showDialog<PermissionManagementDecision>(
            context: context,
            barrierDismissible: false,
            builder: (context) => PermissionManagementDialog(
              extensionName: metadata.name,
              operationDescription: operation,
              categoryName: category,
              isPostHoc: true,
            ),
          );

          if (decision != null &&
              decision != PermissionManagementDecision.deny) {
            final authNotifier = _ref.read(extensionAuthStateProvider.notifier);
            final permKey = permission?.name ?? category;

            if (decision == PermissionManagementDecision.allowNextRun) {
              await authNotifier.setNextRunPermission(metadata.id, permKey);
            } else {
              _ref.read(sessionPermissionsProvider.notifier).update((state) {
                final newState = Map<String, Set<String>>.from(state);
                final extPerms = Set<String>.from(newState[metadata.id] ?? {});
                if (decision ==
                    PermissionManagementDecision.allowCategoryOnce) {
                  extPerms.add(permKey);
                } else if (decision ==
                    PermissionManagementDecision.allowAllOnce) {
                  extPerms.add('all');
                }
                newState[metadata.id] = extPerms;
                return newState;
              });

              if (permission != null) {
                _delegate.notifyPermissionGranted(metadata.id, permission);
              }
            }
          }
        } finally {
          _isDialogShowing = false;
          completer.complete();
        }
      } catch (e) {
        debugPrint('Shield: Error in privacy dialog microtask: $e');
      } finally {
        _activePrivacyRequests.remove(requestId);
        _delegate.resumeExtension(metadata.id);
      }
    });
  }
}
