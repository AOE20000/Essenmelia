import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../widgets/installation_confirm_dialog.dart';
import '../core/base_extension.dart';
import '../core/extension_metadata.dart';
import '../runtime/proxy_extension.dart';
import '../security/extension_auth_notifier.dart';
import '../services/extension_store_service.dart';
import '../utils/extension_converter.dart';
import '../manager/extension_manager.dart';

final extensionLifecycleServiceProvider = Provider<ExtensionLifecycleService>((
  ref,
) {
  return ExtensionLifecycleService(ref);
});

/// Centralized service for extension lifecycle management:
/// Installation, Uninstallation, and Updates.
class ExtensionLifecycleService {
  final Ref _ref;
  static const _maxSafeSize = 1024 * 1024;

  ExtensionLifecycleService(this._ref);

  ExtensionManager get _manager => _ref.read(extensionManagerProvider);

  // --- Installation ---

  Future<void> installFromClipboard(BuildContext context) async {
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
        if (context.mounted) {
          await installFromUrl(context, text);
        }
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

  Future<void> installFromFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      if (!context.mounted) return;

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
            String? readme;
            final extName = file.extension?.toLowerCase();
            if (extName == 'zip') {
              final bytes = await File(file.path!).readAsBytes();
              content = ExtensionConverter.extractContentFromZip(bytes);
              readme = ExtensionConverter.extractReadmeFromZip(bytes);
            } else {
              final raw = await File(file.path!).readAsString();
              final metadata = ExtensionMetadata.fromReadme(raw);
              if (metadata != null) {
                content = jsonEncode(metadata.toJson());
                readme = raw;
              }
            }

            if (content != null) {
              if (context.mounted) {
                final ext = await _installFromContent(
                  context,
                  content,
                  readmeContent: readme,
                );
                if (ext != null) {
                  successCount++;
                } else {
                  failedFiles.add(file.name);
                }
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
        _showBatchResultDialog(context, successCount, totalCount, failedFiles);
      } else if (successCount == 1) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('扩展安装成功')));
      }
    }
  }

  Future<BaseExtension?> installFromUrl(
    BuildContext context,
    String url, {
    bool skipConfirmation = false,
    bool? isUntrusted,
    void Function(double progress, String message)? onProgress,
  }) async {
    try {
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

      if (!context.mounted) {
        return null;
      }
      onProgress?.call(0.0, 'Starting download...');
      final bytes = await _downloadWithProgress(
        context,
        finalUrl,
        onProgress: onProgress,
      );
      if (bytes == null || !context.mounted) {
        return null;
      }

      onProgress?.call(1.0, 'Processing...');
      final isZip = finalUrl.toLowerCase().contains('.zip');

      if (isZip) {
        return await installFromZip(
          context,
          bytes,
          fileName: finalUrl.split('/').last,
          repoFullName: repoFullName,
          skipConfirmation: skipConfirmation,
          isUntrusted: isUntrusted,
          onProgress: onProgress,
        );
      } else {
        final content = utf8.decode(bytes);
        final metadata = ExtensionMetadata.fromReadme(content);

        if (metadata != null) {
          final baseUrl = finalUrl.substring(0, finalUrl.lastIndexOf('/') + 1);
          return await _importFromReadmeAndNeighbors(
            context,
            content,
            (filename) async {
              try {
                final neighborUrl = '$baseUrl$filename';
                final resp = await http.get(Uri.parse(neighborUrl));
                if (resp.statusCode == 200) {
                  return resp.body;
                }
              } catch (_) {}
              return null;
            },
            repoFullName: repoFullName,
            skipConfirmation: skipConfirmation,
            isUntrusted: isUntrusted,
            onProgress: onProgress,
          );
        }

        return await _installFromContent(
          context,
          content,
          repoFullName: repoFullName,
          skipConfirmation: skipConfirmation,
          isUntrusted: isUntrusted,
          onProgress: onProgress,
        );
      }
    } catch (e) {
      debugPrint('Import from URL failed: $e');
      if (context.mounted && onProgress == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
      } else if (onProgress != null) {
        throw Exception('下载失败: $e');
      }
    }
    return null;
  }

  Future<BaseExtension?> installFromZip(
    BuildContext context,
    Uint8List zipBytes, {
    String? fileName,
    String? repoFullName,
    bool skipConfirmation = false,
    bool? isUntrusted,
    void Function(double progress, String message)? onProgress,
  }) async {
    onProgress?.call(1.0, 'Extracting ZIP...');
    final content = ExtensionConverter.extractContentFromZip(zipBytes);
    final readme = ExtensionConverter.extractReadmeFromZip(zipBytes);
    if (content != null) {
      return await _installFromContent(
        context,
        content,
        repoFullName: repoFullName,
        readmeContent: readme,
        skipConfirmation: skipConfirmation,
        isUntrusted: isUntrusted,
        onProgress: onProgress,
      );
    }
    debugPrint('Failed to extract content from ZIP bytes');
    if (context.mounted && onProgress == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ZIP 文件解析失败')));
    } else if (onProgress != null) {
      throw Exception('ZIP 文件解析失败');
    }
    return null;
  }

  // --- Uninstallation ---

  Future<void> uninstall(String id) async {
    _manager.removeActiveExtension(id);
    _manager.removeInstalledExtension(id);
    _manager.removeEventBuffer(id);
    _manager.removeAvailableUpdate(id);

    await _ref.read(extensionStoreServiceProvider.notifier).deleteExtension(id);

    _manager.notifyManagerListeners();
  }

  // --- Updates ---

  Future<int> checkForUpdates() async {
    final extensions = _manager.installedExtensions.values
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
          _processReadmeUpdate(response.body, repoFullName);
        }
      } catch (e) {
        debugPrint('Failed to check update for $repoFullName: $e');
      }
    }

    return _manager.availableUpdates.length;
  }

  // --- Private Helpers ---

  Future<BaseExtension?> _importFromReadmeAndNeighbors(
    BuildContext context,
    String readmeContent,
    Future<String?> Function(String filename) loadFile, {
    String? repoFullName,
    bool skipConfirmation = false,
    bool? isUntrusted,
    void Function(double progress, String message)? onProgress,
  }) async {
    onProgress?.call(1.0, 'Analyzing metadata...');
    final metadata = ExtensionMetadata.fromReadme(readmeContent);
    if (metadata == null) return null;

    // Pre-load content for preview and size calculation
    Map<String, dynamic>? view;
    if (metadata.view != null) {
      view = metadata.view;
    } else {
      final viewContent = await loadFile('view.yaml');
      if (viewContent != null) {
        view = ExtensionMetadata.yamlToMap(viewContent);
      }
    }

    String? scriptContent = metadata.script;
    scriptContent ??= await loadFile('main.js');

    final Map<String, dynamic> data = metadata.toJson();
    if (view != null) data['view'] = view;
    if (scriptContent != null) data['script'] = scriptContent;

    final finalContent = jsonEncode(data);

    if (!context.mounted) return null;

    return await _processInstall(
      context,
      metadata,
      () async => finalContent,
      repoFullName: repoFullName,
      previewContent: finalContent,
      readmeContent: readmeContent,
      skipConfirmation: skipConfirmation,
      isUntrusted: isUntrusted,
      onProgress: onProgress,
    );
  }

  Future<BaseExtension?> _installFromContent(
    BuildContext context,
    String content, {
    String? repoFullName,
    String? readmeContent,
    bool skipConfirmation = false,
    bool? isUntrusted,
    void Function(double progress, String message)? onProgress,
  }) async {
    onProgress?.call(1.0, 'Parsing content...');
    if (content.length > _maxSafeSize) {
      if (context.mounted) {
        final proceed = await _showSecurityWarningDialog(
          context,
          '扩展文件过大 (${(content.length / 1024).toStringAsFixed(1)} KB)',
          '大型扩展可能会消耗更多内存或包含大量恶意代码。是否继续加载？',
        );
        if (proceed != true) return null;
      } else {
        return null;
      }
    }

    Map<String, dynamic> data;
    String? effectiveReadme = readmeContent;
    try {
      data = jsonDecode(content);
    } catch (_) {
      final metadata = ExtensionMetadata.fromReadme(content);
      if (metadata != null) {
        data = metadata.toJson();
        effectiveReadme ??= content;
      } else {
        if (context.mounted) {
          await _showErrorHandlingDialog(context, '无法解析扩展内容');
        }
        return null;
      }
    }

    if (repoFullName != null) {
      data['repo_full_name'] = repoFullName;
    }

    final metadata = ExtensionMetadata.fromJson(data);
    // Re-encode to ensure consistent formatting if needed, or just use content
    // If we modified data (added repo_full_name), we must re-encode
    final finalContent = jsonEncode(data);

    if (context.mounted) {
      return await _processInstall(
        context,
        metadata,
        () async => finalContent,
        repoFullName: repoFullName,
        previewContent: finalContent,
        readmeContent: effectiveReadme,
        skipConfirmation: skipConfirmation,
        isUntrusted: isUntrusted,
        onProgress: onProgress,
      );
    }
    return null;
  }

  Future<BaseExtension?> _processInstall(
    BuildContext context,
    ExtensionMetadata metadata,
    Future<String> Function() contentLoader, {
    String? repoFullName,
    String? previewContent,
    String? readmeContent,
    bool skipConfirmation = false,
    bool? isUntrusted,
    void Function(double progress, String message)? onProgress,
  }) async {
    Future<BaseExtension?> performInstall({
      required bool isUntrustedOverride,
      void Function(double, String)? internalProgress,
    }) async {
      internalProgress?.call(0.2, 'Loading content...');
      final finalContent = await contentLoader();

      if (!context.mounted) {
        throw Exception('Context unmounted during load');
      }

      if (finalContent.length > _maxSafeSize) {
        final proceed = await _showSecurityWarningDialog(
          context,
          '扩展文件过大 (${(finalContent.length / 1024).toStringAsFixed(1)} KB)',
          '生成的扩展文件过大，可能会影响性能。是否继续？',
        );
        if (proceed != true) {
          throw Exception('Cancelled by user (size warning)');
        }
      }

      internalProgress?.call(0.4, 'Saving extension...');
      await _ref
          .read(extensionStoreServiceProvider.notifier)
          .saveExtension(metadata.id, finalContent);

      if (!context.mounted) {
        throw Exception('Context unmounted during save');
      }

      internalProgress?.call(0.6, 'Registering extension...');
      final newExt = ProxyExtension(metadata);
      _manager.addInstalledExtension(newExt);

      if (_manager.availableUpdates.containsKey(metadata.id)) {
        _manager.removeAvailableUpdate(metadata.id);
        _manager.notifyManagerListeners();
      }

      internalProgress?.call(0.8, 'Updating permissions...');
      final auth = _ref.read(extensionAuthStateProvider.notifier);
      await auth.setRunning(metadata.id, true);
      await auth.setUntrusted(metadata.id, isUntrustedOverride);

      final manifestHash = sha256.convert(utf8.encode(finalContent)).toString();
      await auth.setManifestHash(metadata.id, manifestHash);

      _manager.notifyManagerListeners();

      internalProgress?.call(1.0, 'Installation complete');
      return _manager.extensions.firstWhere(
        (e) => e.metadata.id == metadata.id,
      );
    }

    try {
      final oldExtension = _manager.installedExtensions[metadata.id];
      String? oldContent;
      if (oldExtension != null) {
        oldContent = _ref
            .read(extensionStoreServiceProvider.notifier)
            .getExtensionContent(metadata.id);
      }

      String displayContent = previewContent ?? '';
      if (displayContent.isEmpty && skipConfirmation == false) {
        // If we don't have preview content, we might want to load it now
      }

      if (!skipConfirmation) {
        final Completer<BaseExtension?> completer = Completer();

        await InstallationConfirmDialog.show(
          context,
          newMeta: metadata,
          newContent: displayContent,
          oldMeta: oldExtension?.metadata,
          oldContent: oldContent,
          readme: readmeContent,
          onConfirm:
              (
                bool isUntrustedConfirmed,
                void Function(double, String)? dialogProgress,
              ) async {
                try {
                  final ext = await performInstall(
                    isUntrustedOverride: isUntrustedConfirmed,
                    internalProgress: dialogProgress ?? onProgress,
                  );
                  completer.complete(ext);
                } catch (e) {
                  // Do not complete with error, let the dialog handle it and allow retry
                  // completer.completeError(e);
                  rethrow;
                }
              },
        );

        if (completer.isCompleted) {
          return await completer.future;
        } else {
          return null;
        }
      }

      return await performInstall(
        isUntrustedOverride: isUntrusted ?? false,
        internalProgress: onProgress,
      );
    } catch (e) {
      debugPrint('Installation error: $e');
      if (context.mounted && onProgress == null) {
        await _showErrorHandlingDialog(context, e.toString());
      } else if (onProgress != null) {
        rethrow;
      }
      return null;
    }
  }

  void _processReadmeUpdate(String content, String repoFullName) {
    final metadata = ExtensionMetadata.fromReadme(content);

    if (metadata != null) {
      final id = metadata.id;
      final remoteVersion = metadata.version;

      final installedExt = _manager.installedExtensions[id];
      if (installedExt != null) {
        if (installedExt.metadata.repoFullName != repoFullName) {
          _updateExtensionRepoFullName(id, repoFullName);
        }

        if (remoteVersion != installedExt.metadata.version) {
          if (_manager.availableUpdates[id] != remoteVersion) {
            _manager.updateAvailableUpdate(id, remoteVersion);
            _manager.notifyManagerListeners();
          }
        } else {
          if (_manager.availableUpdates.containsKey(id)) {
            _manager.removeAvailableUpdate(id);
            _manager.notifyManagerListeners();
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

        _manager.notifyManagerListeners();
      } catch (e) {
        debugPrint('Failed to update repo full name for $id: $e');
      }
    }
  }

  // --- UI Helpers (Private) ---

  Future<Uint8List?> _downloadWithProgress(
    BuildContext context,
    String url, {
    void Function(double progress, String message)? onProgress,
  }) async {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    request.headers['User-Agent'] = 'Essenmelia-App';

    BuildContext? dialogContext;
    bool isDialogShowing = false;

    try {
      final response = await client.send(request);
      if (response.statusCode != 200 || !context.mounted) {
        client.close();
        if (onProgress != null) {
          throw Exception(
            'Download failed with status: ${response.statusCode}',
          );
        }
        return null;
      }

      final contentLength = response.contentLength;
      final List<int> bytes = [];
      final progressNotifier = ValueNotifier<double>(0);

      if (!context.mounted) {
        client.close();
        return null;
      }

      if (onProgress == null) {
        isDialogShowing = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            dialogContext = ctx;
            final theme = Theme.of(ctx);
            return PopScope(
              canPop: false,
              child: AlertDialog(
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                title: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text('正在下载扩展', style: theme.textTheme.titleLarge),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: progressNotifier,
                      builder: (context, progress, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: contentLength != null ? progress : null,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                contentLength != null
                                    ? '${(progress * 100).toStringAsFixed(0)}%'
                                    : '正在接收数据...',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFeatures: [
                                    const ui.FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      try {
        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          if (contentLength != null && contentLength > 0) {
            final progress = bytes.length / contentLength;
            progressNotifier.value = progress;
            onProgress?.call(
              progress,
              'Downloading... ${(progress * 100).toStringAsFixed(0)}%',
            );
          } else {
            onProgress?.call(
              0.0,
              'Downloading... ${(bytes.length / 1024).toStringAsFixed(0)}KB',
            );
          }
        }

        // Small delay for UX if too fast
        if (bytes.length < 1024 * 100) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } finally {
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.of(dialogContext!).pop();
        } else if (onProgress == null && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        client.close();
        progressNotifier.dispose();
      }

      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('Download error: $e');
      client.close();
      if (onProgress == null && isDialogShowing) {
        if (dialogContext != null && dialogContext!.mounted) {
          Navigator.of(dialogContext!).pop();
        } else if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      } else if (onProgress != null) {
        rethrow;
      }
      return null;
    }
  }

  Future<bool?> _showSecurityWarningDialog(
    BuildContext context,
    String title,
    String content,
  ) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_rounded,
          size: 32,
          color: theme.colorScheme.error,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(content, textAlign: TextAlign.center),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  Future<void> _showErrorHandlingDialog(BuildContext context, String error) {
    final theme = Theme.of(context);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error_rounded,
          size: 32,
          color: theme.colorScheme.error,
        ),
        title: const Text('安装失败', textAlign: TextAlign.center),
        content: Text(error, textAlign: TextAlign.center),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showBatchResultDialog(
    BuildContext context,
    int successCount,
    int totalCount,
    List<String> failedFiles,
  ) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          failedFiles.isEmpty ? Icons.check_circle_rounded : Icons.info_rounded,
          size: 32,
          color: failedFiles.isEmpty
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
        title: Text(
          failedFiles.isEmpty ? '批量安装成功' : '安装完成 (有失败)',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('成功安装: $successCount / $totalCount'),
            if (failedFiles.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '失败列表:',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: failedFiles.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        failedFiles[index],
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
