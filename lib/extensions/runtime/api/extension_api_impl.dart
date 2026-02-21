// ignore_for_file: avoid_print

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extension_api.dart';
import '../../core/extension_metadata.dart';
import '../../core/extension_permission.dart';
import '../../core/globals.dart';
import '../../security/extension_auth_notifier.dart';
import '../../security/security_providers.dart';
import '../../security/security_shield.dart';
import '../../utils/extension_logger.dart';
import 'extension_api_registry.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_provider.dart';
import '../../../models/event.dart';
import '../../../providers/theme_provider.dart';
import '../../../providers/locale_provider.dart';

/// Extension API implementation
class ExtensionApiImpl implements ExtensionApi {
  final Ref _ref;
  final ExtensionMetadata _metadata;
  final SecurityShield _shield;

  ExtensionApiImpl(this._ref, this._metadata, this._shield);

  bool _checkPermission(ExtensionPermission permission) {
    final extId = _metadata.id;

    // 1. Check persistent permission
    final hasPersistent = _ref
        .read(extensionAuthStateProvider.notifier)
        .hasPermission(extId, permission);
    if (hasPersistent) return true;

    // 2. Check session permission (granted via restricted access dialog)
    final sessionPerms = _ref.read(sessionPermissionsProvider)[extId] ?? {};
    if (sessionPerms.contains('all')) return true;

    // Check specific permission name
    if (sessionPerms.contains(permission.name)) return true;

    return false;
  }

  String _getSandboxId() {
    return _ref
        .read(extensionAuthStateProvider.notifier)
        .getSandboxId(_metadata.id);
  }

  /// Generic API call dispatcher
  Future<dynamic> _invokeApi(
    String methodName, {
    Map<String, dynamic> params = const {},
    ExtensionPermission? permission,
    String? operation,
    String? category,
  }) async {
    final extId = _metadata.id;

    // Log state variables
    bool success = true;
    String? error;
    bool isUntrusted = false;
    dynamic result;

    try {
      final notifier = _ref.read(extensionAuthStateProvider.notifier);
      // debugPrint('ExtensionApi: Waiting for notifier ready for $methodName');
      await notifier.ready;
      // debugPrint('ExtensionApi: Notifier ready');

      final registry = _ref.read(extensionApiRegistryProvider);

      // Force print to debug console
      print('ExtensionApi: Invoking $methodName for $extId');

      if (!notifier.isRunning(extId)) {
        print('ExtensionApi: Extension $extId is not running');
        success = false;
        error = 'Extension not running';
        return null;
      }

      // 1. Get registry metadata
      final metadata = registry.getMetadata(methodName);

      // Security Check: Rate Limiting
      if (!_shield.checkRateLimit(extId, methodName)) {
        print('ExtensionApi: Rate limit exceeded for $methodName');
        success = false;
        error = 'Rate limit exceeded';
        return null;
      }

      // 2. Prefer explicit params, otherwise use metadata definition (Fail-Closed basis)
      final effectivePermission = permission ?? metadata?.permission;
      final effectiveOperation = operation ?? metadata?.operation;
      final effectiveCategory = category ?? metadata?.category;

      // 3. Privacy Shield Intercept logic (for restricted access mode)
      if (effectiveOperation != null) {
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          final l10n = AppLocalizations.of(context)!;
          final operation = metadata?.getOperation(l10n) ?? effectiveOperation;
          final category =
              metadata?.getCategory(l10n) ??
              effectiveCategory ??
              l10n.extensionCategoryGeneral;

          // Use SecurityShield to intercept
          isUntrusted = !await _shield.intercept(
            _metadata,
            operation,
            category,
            permission: effectivePermission,
          );
        }
      }

      // 4. Explicit permission check (for persistent permissions)
      // If API defines permission but check fails, force "untrusted" mode (return mock data)
      if (!isUntrusted &&
          effectivePermission != null &&
          !_checkPermission(effectivePermission)) {
        isUntrusted = true;
      }

      print(
        'ExtensionApi: Calling registry invoke for $methodName (untrusted=$isUntrusted)',
      );

      // Inject extension meta info and sandbox ID
      final fullParams = {
        ...params,
        'extensionId': _metadata.id,
        'sandboxId': _getSandboxId(),
      };

      final handler = registry.getHandler(methodName);

      if (handler != null) {
        result = await handler(fullParams, isUntrusted: isUntrusted);
      } else {
        print('ExtensionApi: No handler registered for $methodName');
        success = false;
        error = 'No handler registered';
      }

      return result;
    } catch (e) {
      print('ExtensionApi: Handler execution error: $e');
      success = false;
      error = e.toString();
      rethrow;
    } finally {
      // Record global log
      try {
        _ref
            .read(extensionLogProvider.notifier)
            .addLog(
              ExtensionLogEntry(
                extensionId: _metadata.id,
                extensionName: _metadata.name,
                method: methodName,
                params: params,
                timestamp: DateTime.now(),
                success: success,
                error: error,
                isUntrusted: isUntrusted,
              ),
            );
      } catch (logError) {
        print('ExtensionApi: Failed to record log: $logError');
      }
    }
  }

  @override
  Future<List<Event>> getEvents() async {
    final result = await _invokeApi('getEvents');
    return (result as List?)?.cast<Event>() ?? [];
  }

  @override
  Future<List<String>> getTags() async {
    final result = await _invokeApi('getTags');
    return (result as List?)?.cast<String>() ?? [];
  }

  @override
  Future<void> addTag(String tag) async {
    await _invokeApi('addTag', params: {'tag': tag});
  }

  @override
  void navigateTo(String route) {
    _invokeApi('navigateTo', params: {'route': route});
  }

  @override
  void showSnackBar(String message) {
    _invokeApi('showSnackBar', params: {'message': message});
  }

  @override
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    await _invokeApi(
      'showNotification',
      params: {'title': title, 'body': body, 'id': id, 'payload': payload},
    );
  }

  @override
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
  }) async {
    final l10n = _ref.read(l10nProvider);
    final result = await _invokeApi(
      'showConfirmDialog',
      params: {
        'title': title,
        'message': message,
        'confirmLabel': confirmLabel ?? l10n.confirm,
        'cancelLabel': cancelLabel ?? l10n.cancel,
      },
    );
    return result ?? false;
  }

  @override
  Future<bool> exportFile(String content, String fileName) async {
    final result = await _invokeApi(
      'exportFile',
      params: {'content': content, 'fileName': fileName},
    );
    return result ?? false;
  }

  @override
  Future<String?> pickFile({List<String>? allowedExtensions}) async {
    final result = await _invokeApi(
      'pickFile',
      params: {'allowedExtensions': allowedExtensions},
    );
    return result as String?;
  }

  @override
  Future<String?> httpGet(String url, {Map<String, String>? headers}) async {
    final result = await _invokeApi(
      'httpGet',
      params: {'url': url, 'headers': headers},
    );
    return result as String?;
  }

  @override
  Future<String?> httpPost(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final result = await _invokeApi(
      'httpPost',
      params: {'url': url, 'headers': headers, 'body': body},
    );
    return result as String?;
  }

  @override
  Future<String?> httpPut(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final result = await _invokeApi(
      'httpPut',
      params: {'url': url, 'headers': headers, 'body': body},
    );
    return result as String?;
  }

  @override
  Future<String?> httpDelete(String url, {Map<String, String>? headers}) async {
    final result = await _invokeApi(
      'httpDelete',
      params: {'url': url, 'headers': headers},
    );
    return result as String?;
  }

  @override
  Future<void> openUrl(String url) async {
    await _invokeApi('openUrl', params: {'url': url});
  }

  @override
  Future<dynamic> call(String method, Map<String, dynamic> params) async {
    // Automatically route based on registry metadata, removing hardcoded switch
    return await _invokeApi(method, params: params);
  }

  @override
  void publishEvent(String name, Map<String, dynamic> data) {
    _invokeApi('publishEvent', params: {'name': name, 'data': data});
  }

  @override
  void setSearchQuery(String query) {
    _invokeApi('setSearchQuery', params: {'query': query});
  }

  @override
  Future<String> addEvent({
    required String title,
    String? description,
    List<String>? tags,
    String? imageUrl,
    String? stepDisplayMode,
    String? stepSuffix,
    DateTime? reminderTime,
    String? reminderRecurrence,
    String? reminderScheme,
    List<Map<String, dynamic>>? steps,
  }) async {
    final result = await _invokeApi(
      'addEvent',
      params: {
        'title': title,
        'description': description,
        'tags': tags,
        'imageUrl': imageUrl,
        'stepDisplayMode': stepDisplayMode,
        'stepSuffix': stepSuffix,
        'reminderTime': reminderTime?.toIso8601String(),
        'reminderRecurrence': reminderRecurrence,
        'reminderScheme': reminderScheme,
        'steps': steps,
      },
    );
    return result as String;
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _invokeApi('deleteEvent', params: {'id': id});
  }

  @override
  Future<void> updateEvent({
    required String id,
    String? title,
    String? description,
    List<String>? tags,
    String? imageUrl,
    String? stepDisplayMode,
    String? stepSuffix,
    DateTime? reminderTime,
    String? reminderRecurrence,
    String? reminderScheme,
    List<Map<String, dynamic>>? steps,
  }) async {
    // Construct a temporary Event object for serialization or pass params directly
    // In updateEvent handler, we can extract from params['event'] or direct params
    await _invokeApi(
      'updateEvent',
      params: {
        'event': {
          'id': id,
          'title': title,
          'description': description,
          'tags': tags,
          'imageUrl': imageUrl,
          'stepDisplayMode': stepDisplayMode,
          'stepSuffix': stepSuffix,
          'reminderTime': reminderTime?.toIso8601String(),
          'reminderRecurrence': reminderRecurrence,
          'reminderScheme': reminderScheme,
          'steps': steps,
        },
      },
    );
  }

  @override
  Future<void> addStep(String eventId, String description) async {
    await _invokeApi(
      'addStep',
      params: {'eventId': eventId, 'description': description},
    );
  }

  @override
  Future<int> getDbSize() async {
    final result = await _invokeApi('getDbSize');
    return result ?? 0;
  }

  @override
  String getThemeMode() {
    _invokeApi('getThemeMode');
    // Asynchronous API forwarding to synchronous interface workaround:
    // In ExtensionApi, getThemeMode and getLocale are synchronous,
    // but our forwarding mechanism is asynchronous. To maintain compatibility,
    // we can read directly in implementation, or change these APIs to async.
    // Given these values are relatively stable at runtime, reading Ref directly is simplest.

    final themeOption = _ref.read(themeProvider);
    final context = navigatorKey.currentContext;

    bool isDark = false;
    if (themeOption == ThemeModeOption.system && context != null) {
      isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    } else {
      isDark = themeOption == ThemeModeOption.dark;
    }

    return isDark ? 'dark' : 'light';
  }

  @override
  String getLocale() {
    _invokeApi('getLocale');
    final locale = _ref.read(localeProvider);
    return locale?.languageCode ?? 'zh';
  }

  @override
  Future<T?> getSetting<T>(String key) async {
    final result = await _invokeApi('getSetting', params: {'key': key});
    return result as T?;
  }

  @override
  Future<void> saveSetting<T>(String key, T value) async {
    await _invokeApi('saveSetting', params: {'key': key, 'value': value});
  }
}
