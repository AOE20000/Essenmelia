import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/base_extension.dart';
import '../core/extension_metadata.dart';
import '../core/extension_permission.dart';
import '../core/extension_api.dart';
import '../core/globals.dart';
import '../../models/event.dart';
import '../runtime/api/extension_api_impl.dart';
import '../runtime/proxy_extension.dart';
import '../security/extension_auth_notifier.dart';
import '../security/security_shield.dart';
import '../services/events_extension_service.dart';
import '../services/extension_store_service.dart';
import '../services/settings_extension_service.dart';
import '../services/system_extension_service.dart';
import '../services/tags_extension_service.dart';
import '../services/ui_extension_service.dart';

/// Extension Manager Provider
final extensionManagerProvider = ChangeNotifierProvider<ExtensionManager>((
  ref,
) {
  return ExtensionManager(ref);
});

class ExtensionManager extends ChangeNotifier
    implements SecurityShieldDelegate {
  final Ref _ref;
  late final SecurityShield _securityShield;

  /// Active extension instances (extensionId -> Instance)
  final Map<String, BaseExtension> _activeExtensions = {};

  /// Installed extensions blueprints (extensionId -> Instance/Proxy for metadata)
  final Map<String, BaseExtension> _installedExtensions = {};

  /// Event buffers for paused extensions
  final Map<String, List<dynamic>> _eventBuffers = {};

  /// Available updates (extensionId -> newVersion)
  final Map<String, String> _availableUpdates = {};

  /// Reserved Extension IDs that cannot be loaded from external sources
  static const List<String> _reservedIds = ['system_health_check'];

  // Public getters
  Map<String, BaseExtension> get installedExtensions => _installedExtensions;
  Map<String, String> get availableUpdates => _availableUpdates;
  Ref get ref => _ref;

  ExtensionManager(this._ref) {
    _securityShield = SecurityShield(_ref, this);

    _ensureServicesRegistered();
    if (kDebugMode) {
      _registerDebugServiceExtensions();
      _initDebugChannel();
    }
    Future.microtask(() => _init());
  }

  // --- Helper Accessors for State Mutation ---

  void addInstalledExtension(BaseExtension ext) {
    _installedExtensions[ext.metadata.id] = ext;
  }

  void removeInstalledExtension(String id) {
    _installedExtensions.remove(id);
  }

  void removeActiveExtension(String id) {
    _activeExtensions.remove(id);
  }

  void removeEventBuffer(String id) {
    _eventBuffers.remove(id);
  }

  void updateAvailableUpdate(String id, String version) {
    _availableUpdates[id] = version;
  }

  void removeAvailableUpdate(String id) {
    _availableUpdates.remove(id);
  }

  void notifyManagerListeners() {
    notifyListeners();
  }

  // --- SecurityShieldDelegate Implementation ---

  @override
  void resumeExtension(String extensionId) {
    _ref
        .read(extensionAuthStateProvider.notifier)
        .setPaused(extensionId, false);
    // Process buffered events if any (implementation TBD if needed)
  }

  @override
  void notifyPermissionGranted(
    String extensionId,
    ExtensionPermission permission,
  ) {
    final ext = _activeExtensions[extensionId];
    if (ext != null) {
      ext.onPermissionGranted(permission);
    }
  }

  // --- Initialization ---

  void _ensureServicesRegistered() {
    _ref.read(eventsExtensionServiceProvider);
    _ref.read(tagsExtensionServiceProvider);
    _ref.read(uiExtensionServiceProvider);
    _ref.read(systemExtensionServiceProvider);
    _ref.read(settingsExtensionServiceProvider);
  }

  Future<void> _init() async {
    await _ref.read(extensionStoreServiceProvider.notifier).init();

    _ref.listen(extensionStoreServiceProvider, (previous, next) {
      if (previous != null && !mapEquals(previous, next)) {
        _loadDynamicExtensions();
      }
    });

    _ref.listen(extensionAuthStateProvider, (previous, next) {
      if (previous != null) {
        // Check for newly granted permissions
        for (var extId in next.keys) {
          if (extId.startsWith('untrusted_') ||
              extId.startsWith('running_') ||
              extId.startsWith('next_run_')) {
            continue;
          }

          final prevPerms = previous[extId] ?? [];
          final nextPerms = next[extId] ?? [];

          if (nextPerms.length > prevPerms.length) {
            final addedNames = nextPerms
                .where((p) => !prevPerms.contains(p))
                .toList();
            for (var name in addedNames) {
              try {
                final perm = ExtensionPermission.values.firstWhere(
                  (p) => p.name == name,
                );
                notifyPermissionGranted(extId, perm);
              } catch (_) {}
            }
          }
        }

        bool runningChanged = false;
        final allIds = {...previous.keys, ...next.keys};
        for (var id in allIds) {
          if (id.startsWith('running_')) {
            if (!listEquals(previous[id], next[id])) {
              runningChanged = true;

              // If extension is enabled, trigger load
              final extId = id.substring('running_'.length);
              final isRunning = next[id]?.firstOrNull != 'false';
              if (isRunning) {
                // Fire and forget, notify when done
                _loadExtension(extId).whenComplete(() => notifyListeners());
              }
              break;
            }
          }
        }

        if (runningChanged) {
          Future.microtask(() => notifyListeners());
        }
      } else {
        Future.microtask(() => notifyListeners());
      }
    });

    await _loadDynamicExtensions();
  }

  // --- Dynamic Extensions Loading ---

  Future<void> _loadBuiltinExtensions() async {
    try {
      debugPrint('Loading built-in extensions...');
      // 1. External Call Gateway
      final readme = await rootBundle.loadString(
        'assets/extensions/builtin/external_call/README.md',
      );
      final mainJs = await rootBundle.loadString(
        'assets/extensions/builtin/external_call/main.js',
      );
      final viewYaml = await rootBundle.loadString(
        'assets/extensions/builtin/external_call/view.yaml',
      );

      // Extract JSON from README
      final jsonStart = readme.indexOf('<!-- ESSENMELIA_EXTEND');
      final jsonEnd = readme.indexOf('-->', jsonStart);
      if (jsonStart == -1 || jsonEnd == -1) {
        throw 'Invalid README format';
      }

      final jsonStr = readme.substring(jsonStart + 22, jsonEnd).trim();
      final json = jsonDecode(jsonStr);

      // Inject code
      json['script'] = mainJs;
      json['view'] = viewYaml; // ExtensionMetadata handles String or Map

      final metadata = ExtensionMetadata.fromJson(json);
      _installedExtensions[metadata.id] = ProxyExtension(metadata);

      // Auto-start system extension if not set
      final auth = _ref.read(extensionAuthStateProvider.notifier);
      // For built-in extensions, we force enable them if not explicitly disabled?
      // Or just ensure they are in the list.
      // Let's ensure it's running.
      if (!auth.isRunning(metadata.id)) {
        debugPrint('Auto-starting built-in extension: ${metadata.id}');
        await auth.setRunning(metadata.id, true);
        // System extension is trusted
        await auth.setUntrusted(metadata.id, false);

        // Grant all requested permissions
        final perms = metadata.requiredPermissions.map((e) => e.name).toSet();
        if (perms.isNotEmpty) {
          // We need to access sessionPermissionsProvider but it's not directly available here unless we read it.
          // We can use ref.read inside microtask or just let user approve?
          // System extension should be pre-approved.
          // But for now, let's rely on `setUntrusted(false)` which might bypass some checks if implemented that way.
          // Actually, `ExtensionApiImpl` checks permissions even if trusted.
          // So we should grant permissions.
        }
      }

      // Load it
      if (auth.isRunning(metadata.id)) {
        _loadExtension(metadata.id);
      }
      debugPrint('Built-in extension loaded: ${metadata.id}');
    } catch (e) {
      debugPrint('Failed to load built-in extension: $e');
    }
  }

  Future<void> _loadDynamicExtensions() async {
    // 1. Load Built-in Extensions first
    await _loadBuiltinExtensions();

    final installed = _ref.read(extensionStoreServiceProvider);

    // Keep built-in extensions
    _installedExtensions.removeWhere((id, ext) => id != 'system.external_call');

    for (var entry in installed.entries) {
      final json = entry.value;
      try {
        final metadata = ExtensionMetadata.fromJson(jsonDecode(json));
        final extId = metadata.id;

        if (_reservedIds.contains(extId)) {
          debugPrint(
            'Security Alert: Extension $extId is using a reserved system ID. Skipping.',
          );
          continue;
        }

        if (extId != entry.key) {
          debugPrint(
            'Security Alert: Extension ID mismatch for ${entry.key}. Manifest claims $extId. Skipping.',
          );
          continue;
        }

        await _verifyIntegrityAsync(extId, json);

        _installedExtensions[extId] = ProxyExtension(metadata);

        // Auto-load if running
        final auth = _ref.read(extensionAuthStateProvider.notifier);
        if (auth.isRunning(extId)) {
          // If extension is already active, force reload to apply updates
          if (_activeExtensions.containsKey(extId)) {
            debugPrint('Reloading updated extension: $extId');
            final oldExt = _activeExtensions.remove(extId);
            await oldExt?.onDispose();
          }

          // Fire and forget, but notify when done so UI updates
          _loadExtension(extId).whenComplete(() => notifyListeners());
        }
      } catch (e) {
        debugPrint('Failed to load extension ${entry.key}: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _verifyIntegrityAsync(String extId, String json) async {
    if (kDebugMode) return;
    try {
      final auth = _ref.read(extensionAuthStateProvider.notifier);
      final storedHash = auth.getManifestHash(extId);
      if (storedHash == null) return;

      await Future.delayed(Duration.zero);
      final currentHash = sha256.convert(utf8.encode(json)).toString();

      if (currentHash != storedHash) {
        debugPrint(
          'Security Alert: Extension $extId manifest integrity check failed! Hash mismatch.',
        );
        await auth.setUntrusted(extId, true);
        await auth.setRunning(extId, false);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Integrity verification error for $extId: $e');
    }
  }

  // --- Extension Lifecycle ---

  /// Get or create active extension instance
  Future<BaseExtension?> _loadExtension(String id) async {
    if (_activeExtensions.containsKey(id)) {
      return _activeExtensions[id];
    }

    final blueprint = _installedExtensions[id];
    if (blueprint == null) return null;

    final auth = _ref.read(extensionAuthStateProvider.notifier);
    debugPrint('Loading extension $id, running state: ${auth.isRunning(id)}');
    if (!auth.isRunning(id)) {
      debugPrint('Extension $id is not running, returning blueprint.');
      return blueprint; // Return blueprint (Proxy) if not running
    }

    try {
      debugPrint('Initializing extension $id...');
      // Create API implementation with SecurityShield
      final api = ExtensionApiImpl(_ref, blueprint.metadata, _securityShield);

      // Initialize extension (ProxyExtension will create JS engine)
      await blueprint.onInit(api);
      debugPrint('Extension $id initialized successfully.');

      _activeExtensions[id] = blueprint;
      return blueprint;
    } catch (e, stack) {
      debugPrint('Failed to initialize extension $id: $e\n$stack');
      // Fallback to blueprint
      return blueprint;
    }
  }

  /// Get extension for UI (ensures it is loaded)
  BaseExtension? getExtension(String id) {
    if (_activeExtensions.containsKey(id)) {
      return _activeExtensions[id];
    }
    // Trigger load if needed (async)
    if (_installedExtensions.containsKey(id)) {
      final auth = _ref.read(extensionAuthStateProvider.notifier);
      if (auth.isRunning(id)) {
        // Only trigger load if it is supposed to be running
        _loadExtension(id).whenComplete(() => notifyListeners());
      }
      return _installedExtensions[id];
    }
    return null;
  }

  // --- Extension Management Methods ---

  /// Get all installed extensions
  List<BaseExtension> get extensions => _installedExtensions.values.toList();

  /// Export extension as ZIP
  Future<void> exportExtensionAsZip(String id) async {
    // Implementation TBD - requires zipping logic
    // For now, show not implemented message
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导出功能暂未实现')));
    }
  }

  /// Copy GitHub Link
  Future<void> copyGitHubLink(String id) async {
    String? repoFullName;

    // Check installed extensions
    final installed = _installedExtensions[id];
    if (installed != null) {
      repoFullName = installed.metadata.repoFullName;
    }

    // Check active extensions if not found
    if (repoFullName == null) {
      final active = _activeExtensions[id];
      if (active != null) {
        repoFullName = active.metadata.repoFullName;
      }
    }

    if (repoFullName != null && repoFullName.isNotEmpty) {
      await Clipboard.setData(
        ClipboardData(text: 'https://github.com/$repoFullName'),
      );
    } else {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未找到 GitHub 仓库链接')));
      }
    }
  }

  /// Get API instance for an extension (used by UI to render extension widgets)
  ExtensionApi getApiFor(BaseExtension extension) {
    // Create a new API instance on the fly if needed, or reuse existing if active
    if (_activeExtensions.containsKey(extension.metadata.id)) {
      return ExtensionApiImpl(_ref, extension.metadata, _securityShield);
    }
    return ExtensionApiImpl(_ref, extension.metadata, _securityShield);
  }

  void _registerDebugServiceExtensions() {
    developer.registerExtension('ext.essenmelia.invokeApi', (
      method,
      parameters,
    ) async {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        'Debug API not fully migrated in refactor',
      );
    });
  }

  void _initDebugChannel() {
    // ...
  }

  /// Broadcast event to all extensions
  void broadcastEvent(
    String name,
    Map<String, dynamic> data, {
    String? senderId,
  }) {
    final senderGroup = senderId != null ? _getSandboxGroup(senderId) : null;

    for (var ext in _activeExtensions.values) {
      if (ext.metadata.id != senderId) {
        // Check sandbox group isolation
        if (senderGroup != null) {
          final targetGroup = _getSandboxGroup(ext.metadata.id);
          if (senderGroup != targetGroup) {
            continue;
          }
        }

        try {
          ext.onExtensionEvent(name, data);
        } catch (e) {
          debugPrint('Error broadcasting event to ${ext.metadata.id}: $e');
        }
      }
    }
  }

  String _getSandboxGroup(String extId) {
    return _ref.read(extensionAuthStateProvider.notifier).getSandboxId(extId);
  }

  /// Notify extensions about a new event
  void notifyEventAdded(Event event) {
    for (var ext in _activeExtensions.values) {
      try {
        ext.onEventAdded(event);
      } catch (e) {
        debugPrint(
          'Error notifying extension ${ext.metadata.id} about event: $e',
        );
      }
    }
  }

  /// Reset all extension data
  Future<void> resetAll() async {
    // 1. Stop all extensions
    _activeExtensions.clear();
    _installedExtensions.clear();
    _eventBuffers.clear();
    _availableUpdates.clear();

    // 2. Clear persistence
    await _ref.read(extensionStoreServiceProvider.notifier).clearAll();

    // 3. Clear auth state
    await _ref.read(extensionAuthStateProvider.notifier).resetAll();

    // 4. Reload built-in extensions (Removed)

    notifyListeners();
  }
}
