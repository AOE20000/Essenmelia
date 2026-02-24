import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../providers/db_provider.dart';
import '../extensions/manager/extension_manager.dart';

/// Service to handle app-wide initialization logic
/// Ensures extensions are loaded only after the database is ready
class AppInitializationService {
  final Ref _ref;
  bool _extensionsInitialized = false;

  AppInitializationService(this._ref) {
    _listenToDbState();
  }

  void _listenToDbState() {
    _ref.listen(dbControllerProvider, (previous, next) {
      if (next.hasValue && !next.isLoading && !next.hasError) {
        if (!_extensionsInitialized) {
          debugPrint(
            'AppInitializationService: Database Ready. Waiting for UI to settle...',
          );

          // 延迟初始化扩展，确保主 UI 渲染完成后再启动后台任务
          Future.delayed(const Duration(seconds: 2), () {
            if (!_extensionsInitialized) {
              debugPrint(
                'AppInitializationService: Initializing Extensions (Staggered)...',
              );
              _ref.read(extensionManagerProvider);
              _extensionsInitialized = true;
            }
          });
        }
      }
    });
  }
}

final appInitializationServiceProvider = Provider<AppInitializationService>((
  ref,
) {
  return AppInitializationService(ref);
});
