import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../core/base_extension.dart';
import '../core/extension_metadata.dart';
import '../core/extension_permission.dart';
import '../core/extension_api.dart';
import '../core/globals.dart';
import '../models/repository_extension.dart';
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
import '../utils/extension_converter.dart';

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

  /// External call entry point extension
  // ProxyExtension? _externalCallExtension;

  /// Installed extensions blueprints (extensionId -> Instance/Proxy for metadata)
  final Map<String, BaseExtension> _installedExtensions = {};

  /// Event buffers for paused extensions
  final Map<String, List<dynamic>> _eventBuffers = {};

  /// Available updates (extensionId -> newVersion)
  final Map<String, String> _availableUpdates = {};

  /// Built-in extensions cache
  List<RepositoryExtension> _builtInExtensions = [];

  Map<String, String> get availableUpdates => _availableUpdates;

  /// Max safe size for extension content (1MB)
  static const _maxSafeSize = 1024 * 1024;

  // Dialog cooldowns (extensionId_permissionName -> lastShowTime) - managed by Shield but we can expose if needed
  // Since we moved to Shield, we don't need to expose them here unless Shield exposes.
  // We have access to Shield.

  ExtensionManager(this._ref) {
    _securityShield = SecurityShield(_ref, this);
    _ensureServicesRegistered();
    if (kDebugMode) {
      _registerDebugServiceExtensions();
      _initDebugChannel();
    }
    Future.microtask(() => _init());
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
    _loadBuiltInExtensions();
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

  // --- Built-in Extensions ---

  Future<void> _loadBuiltInExtensions() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      final extensionFiles = manifestMap.keys
          .where(
            (String key) =>
                key.startsWith('assets/extensions/') &&
                key.endsWith('/manifest.yaml'),
          )
          .toList();

      _builtInExtensions = [];

      for (final file in extensionFiles) {
        try {
          final content = await rootBundle.loadString(file);
          final metadata = ExtensionMetadata.fromYaml(content);
          _builtInExtensions.add(
            RepositoryExtension(
              id: metadata.id,
              name: metadata.name,
              description: metadata.description,
              author: metadata.author,
              version: metadata.version,
              // icon: metadata.icon, // RepositoryExtension uses iconUrl
              downloadUrl: 'builtin://${metadata.id}',
              repoFullName: metadata.repoFullName,
            ),
          );
        } catch (e) {
          debugPrint('Error loading built-in extension $file: $e');
        }
      }

      // Ensure "demo.counter" is loaded if not found (fallback)
      if (!_builtInExtensions.any((e) => e.id == 'demo.counter')) {
        // Fallback logic handled by auto-parsing now
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load built-in extensions: $e');
    }
  }

  List<RepositoryExtension> getBuiltInExtensions() => _builtInExtensions;

  Future<BaseExtension?> installBuiltInExtensionById(String id) async {
    try {
      // Find manifest path
      final manifestPath = 'assets/extensions/$id/manifest.yaml';
      final manifestContent = await rootBundle.loadString(manifestPath);
      final metadata = ExtensionMetadata.fromYaml(manifestContent);

      // Load view and logic if referenced
      Map<String, dynamic>? view;
      if (metadata.view != null) {
        view = metadata.view;
      } else {
        try {
          final viewContent = await rootBundle.loadString(
            'assets/extensions/$id/view.yaml',
          );
          view = ExtensionMetadata.yamlToMap(viewContent);
        } catch (_) {}
      }

      String? logic;
      try {
        // Try logic.js first then main.js
        logic = await rootBundle.loadString('assets/extensions/$id/logic.js');
      } catch (_) {
        try {
          logic = await rootBundle.loadString('assets/extensions/$id/main.js');
        } catch (_) {}
      }

      // Construct JSON for import
      final Map<String, dynamic> data = metadata.toJson();
      if (view != null) data['view'] = view;
      if (logic != null) data['script'] = logic;

      return await importFromContent(jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to install built-in extension $id: $e');
      return null;
    }
  }

  // --- Dynamic Extensions Loading ---

  Future<void> _loadDynamicExtensions() async {
    final installed = _ref.read(extensionStoreServiceProvider);

    _installedExtensions.removeWhere((id, ext) => id != 'external_call');

    for (var entry in installed.entries) {
      final json = entry.value;
      try {
        final metadata = ExtensionMetadata.fromJson(jsonDecode(json));
        final extId = metadata.id;

        if (extId != entry.key) {
          debugPrint(
            'Security Alert: Extension ID mismatch for ${entry.key}. Manifest claims $extId. Skipping.',
          );
          continue;
        }

        _verifyIntegrityAsync(extId, json);

        _installedExtensions[extId] = ProxyExtension(metadata);
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
    if (!auth.isRunning(id)) {
      return blueprint; // Return blueprint (Proxy) if not running
    }

    try {
      // Create API implementation with SecurityShield
      final api = ExtensionApiImpl(_ref, blueprint.metadata, _securityShield);

      // Initialize extension (ProxyExtension will create JS engine)
      await blueprint.onInit(api);

      _activeExtensions[id] = blueprint;
      return blueprint;
    } catch (e) {
      debugPrint('Failed to initialize extension $id: $e');
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
      _loadExtension(
        id,
      ); // Fire and forget load, UI will rebuild when notified?
      // Actually DynamicEngine calls engine.init() which is async.
      // ProxyExtension.build creates UI immediately.
      return _installedExtensions[id];
    }
    return null;
  }

  Map<String, BaseExtension> get installedExtensions => _installedExtensions;

  // --- Extension Management Methods ---

  /// Get all installed extensions
  List<BaseExtension> get extensions => _installedExtensions.values.toList();

  /// Remove an extension
  Future<void> removeExtension(String id) async {
    _activeExtensions.remove(id);
    _installedExtensions.remove(id);
    _eventBuffers.remove(id);
    _availableUpdates.remove(id);

    await _ref.read(extensionStoreServiceProvider.notifier).deleteExtension(id);
    // Optionally clear permissions/auth state if desired,
    // but sometimes keeping them is better for re-installation.
    // For now, let's keep auth state to avoid data loss on accidental removal.

    notifyListeners();
  }

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

    // Check built-in extensions if not found
    if (repoFullName == null) {
      try {
        final builtIn = _builtInExtensions.firstWhere((e) => e.id == id);
        repoFullName = builtIn.repoFullName;
      } catch (_) {}
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
    // Since UI might need an API to pass to build(), we construct one.
    // Ideally, we should reuse the one from _activeExtensions if available.

    if (_activeExtensions.containsKey(extension.metadata.id)) {
      // We don't store the API instance in BaseExtension, so we might need to recreate it
      // or change BaseExtension to hold it.
      // For now, let's create a new one as it's lightweight.
      return ExtensionApiImpl(_ref, extension.metadata, _securityShield);
    }

    // If not active, create one anyway (e.g. for preview)
    return ExtensionApiImpl(_ref, extension.metadata, _securityShield);
  }

  // --- Import / Export ---

  Future<void> importFromClipboard() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();

      if (text == null || text.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('剪贴板为空')));
        }
        return;
      }

      if (Uri.tryParse(text)?.hasAbsolutePath ?? false) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('检测到链接，正在下载...')));
        }
        await importFromUrl(text);
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未检测到有效的扩展下载链接（支持 ZIP/GitHub）')),
        );
      }
    } catch (e) {
      debugPrint('Import from clipboard failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('剪贴板解析失败: $e')));
      }
    }
  }

  Future<void> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      int successCount = 0;
      int totalCount = result.files.length;
      List<String> failedFiles = [];

      if (totalCount > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在准备安装 $totalCount 个扩展...'),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      for (var file in result.files) {
        if (file.path != null) {
          try {
            String? content;
            final extName = file.extension?.toLowerCase();
            if (extName == 'zip') {
              final bytes = await File(file.path!).readAsBytes();
              content = ExtensionConverter.extractContentFromZip(bytes);
            } else {
              final raw = await File(file.path!).readAsString();
              if (extName == 'yaml' ||
                  extName == 'yml' ||
                  (!raw.trim().startsWith('{') &&
                      !raw.trim().startsWith('['))) {
                try {
                  content = jsonEncode(
                    ExtensionMetadata.fromYaml(raw).toJson(),
                  );
                } catch (e) {
                  content = raw;
                }
              } else {
                content = raw;
              }
            }

            if (content != null) {
              final ext = await importFromContent(content);
              if (ext != null) {
                successCount++;
              } else {
                failedFiles.add(file.name);
              }
            } else {
              failedFiles.add('${file.name} (解析失败)');
            }
          } catch (e) {
            debugPrint('Error reading file ${file.name}: $e');
            failedFiles.add(file.name);
          }
        }
      }

      if (!context.mounted) return;

      if (totalCount > 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('批量导入完成'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('成功导入: $successCount / $totalCount'),
                if (failedFiles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '以下文件导入失败或已取消:',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  ...failedFiles
                      .take(5)
                      .map(
                        (f) => Text(
                          '• $f',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  if (failedFiles.length > 5)
                    Text(
                      '...等 ${failedFiles.length} 个文件',
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      } else if (successCount == 1) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('扩展安装成功')));
      }
    }
  }

  Future<BaseExtension?> importFromUrl(String url) async {
    return await _importFromUrlInternal(url);
  }

  Future<BaseExtension?> importFromZip(Uint8List zipBytes) async {
    final content = ExtensionConverter.extractContentFromZip(zipBytes);
    if (content == null) return null;
    return await importFromContent(content);
  }

  Future<BaseExtension?> _importFromUrlInternal(String url) async {
    try {
      if (url.startsWith('builtin://')) {
        final id = url.replaceFirst('builtin://', '');
        return await installBuiltInExtensionById(id);
      }

      var finalUrl = url;
      String? repoFullName;
      if (url.contains('github.com')) {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;

        if (url.contains('raw.githubusercontent.com')) {
          if (segments.length >= 2) {
            repoFullName = '${segments[0]}/${segments[1]}';
          }
        } else if (url.endsWith('.zip')) {
          if (segments.length >= 2) {
            repoFullName = '${segments[0]}/${segments[1]}';
          }
        } else {
          if (segments.length >= 2) {
            repoFullName = '${segments[0]}/${segments[1]}';
            if (segments.length == 2) {
              finalUrl =
                  'https://github.com/${segments[0]}/${segments[1]}/archive/refs/heads/main.zip';
            } else if (url.contains('/blob/')) {
              finalUrl = url
                  .replaceFirst('github.com', 'raw.githubusercontent.com')
                  .replaceFirst('/blob/', '/');
            }
          }
        }
      }

      debugPrint(
        'Downloading extension from: $finalUrl (Repo: ${repoFullName ?? 'Unknown'})',
      );

      final context = navigatorKey.currentContext;
      if (context == null) return null;

      final bytes = await _downloadWithProgress(context, finalUrl);
      if (bytes == null || !context.mounted) return null;

      final isZip = finalUrl.toLowerCase().contains('.zip');

      if (isZip) {
        return await importFromBytes(
          bytes,
          fileName: finalUrl.split('/').last,
          repoFullName: repoFullName,
        );
      } else {
        final content = utf8.decode(bytes);
        return await importFromContent(content, repoFullName: repoFullName);
      }
    } catch (e) {
      debugPrint('Import from URL failed: $e');
    }
    return null;
  }

  Future<BaseExtension?> importFromBytes(
    Uint8List bytes, {
    String? fileName,
    String? repoFullName,
  }) async {
    final content = ExtensionConverter.extractContentFromZip(bytes);
    if (content != null) {
      return await importFromContent(content, repoFullName: repoFullName);
    }
    debugPrint('Failed to extract content from ZIP bytes');
    return null;
  }

  Future<BaseExtension?> importFromContent(
    String content, {
    String? logicJs,
    Map<String, dynamic>? viewYaml,
    String? repoFullName,
  }) async {
    debugPrint('Processing imported content, length: ${content.length}');
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('Error: navigatorKey.currentContext is null');
      return null;
    }

    try {
      if (content.length > _maxSafeSize) {
        final proceed = await _showSecurityWarningDialog(
          context,
          '扩展文件过大 (${(content.length / 1024).toStringAsFixed(1)} KB)',
          '大型扩展可能会消耗更多内存或包含大量恶意代码。是否继续加载？',
        );
        if (proceed != true) return null;
      }

      final Map<String, dynamic> data = jsonDecode(content);

      if (logicJs != null) data['logic'] = logicJs;
      if (viewYaml != null) data['view'] = viewYaml;

      if (repoFullName != null) {
        data['repo_full_name'] = repoFullName;
      }

      final metadata = ExtensionMetadata.fromJson(data);
      debugPrint('Parsed metadata for extension: ${metadata.id}');

      final oldExtension = _installedExtensions[metadata.id];
      String? oldContent;
      if (oldExtension != null) {
        oldContent = _ref
            .read(extensionStoreServiceProvider.notifier)
            .getExtensionContent(metadata.id);
      }

      if (!context.mounted) return null;

      final installResult = await _showInstallationConfirmDialog(
        context,
        metadata,
        jsonEncode(data),
        oldExtension?.metadata,
        oldContent,
      );

      if (installResult == null || installResult['confirmed'] != true) {
        return null;
      }

      final isUntrustedFromDialog = installResult['isUntrusted'] == true;
      final finalContent = jsonEncode(data);

      await _ref
          .read(extensionStoreServiceProvider.notifier)
          .saveExtension(metadata.id, finalContent);

      if (!context.mounted) return null;

      final newExt = ProxyExtension(metadata);
      _installedExtensions[metadata.id] = newExt;

      if (_availableUpdates.containsKey(metadata.id)) {
        _availableUpdates.remove(metadata.id);
        notifyListeners();
      }

      final auth = _ref.read(extensionAuthStateProvider.notifier);
      await auth.setRunning(metadata.id, true);
      await auth.setUntrusted(metadata.id, isUntrustedFromDialog);

      final manifestHash = sha256.convert(utf8.encode(finalContent)).toString();
      await auth.setManifestHash(metadata.id, manifestHash);

      notifyListeners();

      return _activeExtensions[metadata.id];
    } catch (e) {
      debugPrint('Invalid extension format: $e');
      if (!context.mounted) return null;
      final retry = await _showErrorHandlingDialog(context, e.toString());
      if (retry) {
        // Retry logic
      }
      return null;
    }
  }

  // Helpers

  Future<Uint8List?> _downloadWithProgress(
    BuildContext context,
    String url,
  ) async {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'Essenmelia-App';

    try {
      final response = await client.send(request);
      if (response.statusCode != 200 || !context.mounted) {
        client.close();
        return null;
      }

      final contentLength = response.contentLength;
      final List<int> bytes = [];
      final progressNotifier = ValueNotifier<double>(0);

      if (!context.mounted) {
        client.close();
        return null;
      }

      BuildContext? dialogContext;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogContext = ctx;
          return AlertDialog(
            title: const Text('正在下载扩展'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, progress, child) {
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: contentLength != null ? progress : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          contentLength != null
                              ? '${(progress * 100).toStringAsFixed(0)}%'
                              : '正在接收数据...',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      );

      try {
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          if (contentLength != null && contentLength > 0) {
            progressNotifier.value = bytes.length / contentLength;
          }
        }

        if (bytes.length < 1024 * 100) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } finally {
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.of(dialogContext!).pop();
        } else if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        client.close();
        progressNotifier.dispose();
      }

      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Download error: $e');
      client.close();
      return null;
    }
  }

  Future<bool?> _showSecurityWarningDialog(
    BuildContext context,
    String title,
    String content,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showErrorHandlingDialog(
    BuildContext context,
    String error,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('导入失败'),
            content: SingleChildScrollView(
              child: Text('无法解析该扩展文件。\n错误信息: $error'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<Map<String, dynamic>?> _showInstallationConfirmDialog(
    BuildContext context,
    ExtensionMetadata metadata,
    String newContent,
    ExtensionMetadata? oldMetadata,
    String? oldContent,
  ) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _InstallationDialog(
        metadata: metadata,
        newContent: newContent,
        oldMetadata: oldMetadata,
        oldContent: oldContent,
      ),
    );
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

  Future<int> checkForUpdates() async {
    final extensions = _installedExtensions.values
        .where((ext) => ext.metadata.repoFullName != null)
        .toList();
    if (extensions.isEmpty) return 0;

    for (var ext in extensions) {
      final repoFullName = ext.metadata.repoFullName!;
      try {
        final url = 'https://api.github.com/repos/$repoFullName/readme';
        final response = await http
            .get(
              Uri.parse(url),
              headers: {
                'Accept': 'application/vnd.github.raw',
                'User-Agent': 'Essenmelia-App',
              },
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          processReadmeUpdate(response.body, repoFullName);
        }
      } catch (e) {
        debugPrint('Failed to check update for $repoFullName: $e');
      }
    }

    return _availableUpdates.length;
  }

  void processReadmeUpdate(String content, String repoFullName) {
    final data = ExtensionManager.parseReadmeMetadata(content);

    if (data != null) {
      final id = data['id'] as String?;
      final remoteVersion = data['version'] as String?;

      if (id != null && remoteVersion != null) {
        final installedExt = _installedExtensions[id];
        if (installedExt != null) {
          if (installedExt.metadata.repoFullName != repoFullName) {
            _updateExtensionRepoFullName(id, repoFullName);
          }

          if (remoteVersion != installedExt.metadata.version) {
            if (_availableUpdates[id] != remoteVersion) {
              _availableUpdates[id] = remoteVersion;
              notifyListeners();
            }
          } else {
            if (_availableUpdates.containsKey(id)) {
              _availableUpdates.remove(id);
              notifyListeners();
            }
          }
        }
      }
    }
  }

  Future<void> _updateExtensionRepoFullName(
    String id,
    String repoFullName,
  ) async {
    final content = _ref
        .read(extensionStoreServiceProvider.notifier)
        .getExtensionContent(id);
    if (content != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(content);
        data['repo_full_name'] = repoFullName;
        await _ref
            .read(extensionStoreServiceProvider.notifier)
            .saveExtension(id, jsonEncode(data));

        notifyListeners();
      } catch (e) {
        debugPrint('Failed to update repo full name for $id: $e');
      }
    }
  }

  static Map<String, dynamic>? parseReadmeMetadata(String content) {
    try {
      final metadataRegex = RegExp(
        r'<!--\s*ESSENMELIA_EXTEND[^\s]*\s*(\{[\s\S]*?\})\s*-->',
      );
      final match = metadataRegex.firstMatch(content);

      if (match != null) {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          try {
            return jsonDecode(jsonStr);
          } catch (e) {
            try {
              final fixedJson = jsonStr.replaceAllMapped(
                RegExp(r',\s*([\]}])'),
                (m) => m.group(1)!,
              );
              return jsonDecode(fixedJson);
            } catch (_) {
              debugPrint('Failed to parse README metadata JSON: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing README metadata: $e');
    }
    return null;
  }

  // --- Event Handling & Maintenance ---

  /// Broadcast event to all extensions
  void broadcastEvent(
    String name,
    Map<String, dynamic> data, {
    String? senderId,
  }) {
    for (var ext in _activeExtensions.values) {
      if (ext.metadata.id != senderId) {
        try {
          ext.onExtensionEvent(name, data);
        } catch (e) {
          debugPrint('Error broadcasting event to ${ext.metadata.id}: $e');
        }
      }
    }
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

    // 4. Reload built-in extensions
    await _loadBuiltInExtensions();

    notifyListeners();
  }
}

class _InstallationDialog extends StatefulWidget {
  final ExtensionMetadata metadata;
  final String newContent;
  final ExtensionMetadata? oldMetadata;
  final String? oldContent;

  const _InstallationDialog({
    required this.metadata,
    required this.newContent,
    this.oldMetadata,
    this.oldContent,
  });

  @override
  State<_InstallationDialog> createState() => _InstallationDialogState();
}

class _InstallationDialogState extends State<_InstallationDialog> {
  bool _isUntrusted = false;

  @override
  Widget build(BuildContext context) {
    final isUpdate = widget.oldMetadata != null;

    return AlertDialog(
      title: Text(isUpdate ? '更新扩展' : '安装扩展'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('是否${isUpdate ? '更新' : '安装'} "${widget.metadata.name}"?'),
          const SizedBox(height: 16),
          Text('版本: ${widget.metadata.version}'),
          Text('作者: ${widget.metadata.author}'),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _isUntrusted,
            onChanged: (v) => setState(() => _isUntrusted = v ?? false),
            title: const Text('启用受限访问模式'),
            subtitle: const Text('限制扩展只能访问经授权的数据'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'confirmed': true,
            'isUntrusted': _isUntrusted,
          }),
          child: Text(isUpdate ? '更新' : '安装'),
        ),
      ],
    );
  }
}
