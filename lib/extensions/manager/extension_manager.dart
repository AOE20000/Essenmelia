import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

          // Detect permission changes
          if (nextPerms.length != prevPerms.length) {
             // 1. Granted
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
             // 2. Revoked - Force notify listeners to update UI/API checks
             // The API implementation checks permission on every call, so simple UI refresh is enough
             Future.microtask(() => notifyListeners());
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
                _loadExtension(extId).then((_) {
                  // After reloading, we might need to re-register UI components if they were cleared
                  // or if the extension relies on init to register them.
                  // For now, _loadExtension calls onInit which should handle registration.
                  notifyListeners();
                });
              } else {
                // Extension stopped, notify listeners immediately to update UI
                // Optionally unload/dispose resources if needed (currently we keep installed blueprint)
                
                // Clear UI registrations for this extension
                _ref.read(eventDetailContentProvider.notifier).update((state) {
                  final newState = <String, List<Map<String, dynamic>>>{};
                  state.forEach((key, list) {
                    newState[key] = list.where((item) => item['extensionId'] != extId).toList();
                  });
                  return newState;
                });
                
                notifyListeners();
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

  Future<void> _loadDynamicExtensions() async {
    final installed = _ref.read(extensionStoreServiceProvider);

    _installedExtensions.removeWhere((id, ext) => id != 'external_call');

    // 收集需要加载的扩展 ID
    final List<String> toLoad = [];

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

        final auth = _ref.read(extensionAuthStateProvider.notifier);
        if (auth.isRunning(extId)) {
          toLoad.add(extId);
        }
      } catch (e) {
        debugPrint('Failed to parse extension ${entry.key}: $e');
      }
    }

    notifyListeners();

    // 分批次异步加载，避免阻塞主线程
    _sequentialLoad(toLoad);
  }

  Future<void> _sequentialLoad(List<String> ids) async {
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];

      // 每加载 2 个扩展或在每个扩展之间插入一个微小的延迟，给 UI 渲染留出空间
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      try {
        if (_activeExtensions.containsKey(id)) {
          final oldExt = _activeExtensions.remove(id);
          await oldExt?.onDispose();
        }
        await _loadExtension(id);
        notifyListeners();
      } catch (e) {
        debugPrint('Sequential load failed for $id: $e');
      }
    }
  }

  Future<void> _verifyIntegrityAsync(String extId, String json) async {
    // 强制执行完整性检查，移除 debug 模式的例外
    // if (kDebugMode) return; 
    try {
      final auth = _ref.read(extensionAuthStateProvider.notifier);
      final storedHash = auth.getManifestHash(extId);
      
      // 如果没有存储的哈希值（首次安装或升级前），则跳过比对，但会记录当前哈希
      // 注意：安装流程中应确保存储哈希，此处仅作为运行时检查
      if (storedHash == null) return;

      await Future.delayed(Duration.zero);
      final currentHash = sha256.convert(utf8.encode(json)).toString();

      if (currentHash != storedHash) {
        // 允许更新操作（通常更新后哈希会变，但安装流程会更新存储的哈希）
        // 这里主要检测的是安装后的静默篡改
        // 如果是在更新流程中，storedHash 应该已经被 InstallationConfirmDialog 更新了
        // 所以这里的不匹配确实意味着文件被意外修改
        
        debugPrint(
          'Security Alert: Extension $extId manifest integrity check failed! Hash mismatch.',
        );
        debugPrint('Expected: $storedHash');
        debugPrint('Actual:   $currentHash');
        
        // 立即停用并标记为不可信
        await auth.setUntrusted(extId, true);
        await auth.setRunning(extId, false);
        
        // 通知 UI 刷新（通过 ExtensionManager 的监听器）
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

      // Force cleanup of old engine if it exists (e.g. from previous run or partial init)
      // This is crucial for re-enabling an extension to ensure a fresh JS environment
      await blueprint.onDispose();

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
    final context = navigatorKey.currentContext;
    final ext = _installedExtensions[id];

    if (ext == null) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Extension not found')));
      }
      return;
    }

    try {
      final metadata = ext.metadata;
      final archive = Archive();

      // 1. view.yaml
      String viewContent;
      if (metadata.view is String) {
        viewContent = metadata.view;
      } else {
        // Fallback: JSON is valid YAML
        viewContent = const JsonEncoder.withIndent('  ').convert(metadata.view);
      }
      archive.addFile(
        ArchiveFile(
          'view.yaml',
          utf8.encode(viewContent).length,
          utf8.encode(viewContent),
        ),
      );

      // 2. main.js
      if (metadata.script != null) {
        archive.addFile(
          ArchiveFile(
            'main.js',
            utf8.encode(metadata.script!).length,
            utf8.encode(metadata.script!),
          ),
        );
      }

      // 3. README.md
      final readmeContent = _generateReadme(metadata);
      archive.addFile(
        ArchiveFile(
          'README.md',
          utf8.encode(readmeContent).length,
          utf8.encode(readmeContent),
        ),
      );

      // Encode ZIP
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);

      // Save or Share
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final fileName =
            '${metadata.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')}_v${metadata.version}.zip';
        final result = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Extension Source',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (result != null) {
          final file = File(result);
          await file.writeAsBytes(zipData);
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Exported to $result')));
          }
        }
      } else {
        // Mobile: Share
        final tempDir = await getTemporaryDirectory();
        final fileName = '${metadata.id}.zip';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(zipData);

        await Share.shareXFiles([
          XFile(file.path),
        ], subject: 'Extension Source: ${metadata.name}');
      }
    } catch (e) {
      debugPrint('Export failed: $e');
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  String _generateReadme(ExtensionMetadata metadata) {
    final metaJson = const JsonEncoder.withIndent('  ').convert({
      'id': metadata.id,
      'name': metadata.name,
      'description': metadata.description,
      'author': metadata.author,
      'version': metadata.version,
      'icon_code': metadata.icon.codePoint,
      'tags': metadata.tags,
      'permissions': metadata.requiredPermissions.map((e) => e.name).toList(),
    });

    return '''
# ${metadata.name}

${metadata.description}

---

## Metadata
<!-- ESSENMELIA_EXTEND $metaJson -->

---
Generated by Essenmelia
''';
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
