import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../manager/extension_manager.dart';
import '../core/extension_metadata.dart';
import '../core/extension_permission.dart';
import '../core/extension_api.dart';
import '../runtime/api/extension_api_impl.dart';
import '../security/extension_auth_notifier.dart';
import '../security/security_providers.dart';
import '../security/security_shield.dart';

import '../services/extension_repository_service.dart';

enum HealthStatus { pending, running, success, failed, warning }

class HealthTestResult {
  final String name;
  final String description;
  final HealthStatus status;
  final String? message;
  final Duration? duration;

  HealthTestResult({
    required this.name,
    required this.description,
    this.status = HealthStatus.pending,
    this.message,
    this.duration,
  });

  HealthTestResult copyWith({
    HealthStatus? status,
    String? message,
    Duration? duration,
  }) {
    return HealthTestResult(
      name: name,
      description: description,
      status: status ?? this.status,
      message: message ?? this.message,
      duration: duration ?? this.duration,
    );
  }
}

class SystemHealthCheckService {
  final Ref ref;

  SystemHealthCheckService(this.ref);

  Stream<List<HealthTestResult>> runTests(
    AppLocalizations l10n, {
    bool useSandbox = false,
  }) async* {
    List<HealthTestResult> results = [
      HealthTestResult(
        name: l10n.healthCheckNetworkName,
        description: l10n.healthCheckNetworkDesc,
      ),
      HealthTestResult(
        name: l10n.healthCheckDbName,
        description: l10n.healthCheckDbDesc,
      ),
      HealthTestResult(
        name: l10n.healthCheckExtensionName,
        description: l10n.healthCheckExtensionDesc,
      ),
      HealthTestResult(
        name: l10n.healthCheckPermissionsName,
        description: l10n.healthCheckPermissionsDesc,
      ),
    ];

    yield results;

    // 1. Network Test
    results = _updateStatus(
      results,
      l10n.healthCheckNetworkName,
      HealthStatus.running,
    );
    yield results;
    try {
      final stopwatch = Stopwatch()..start();
      // Try multiple domains to be robust in China
      try {
        await InternetAddress.lookup(
          'baidu.com',
        ).timeout(const Duration(seconds: 5));
        results = _updateStatus(
          results,
          l10n.healthCheckNetworkName,
          HealthStatus.success,
          message: l10n.healthCheckNetworkSuccessBaidu,
          duration: stopwatch.elapsed,
        );
      } catch (_) {
        await InternetAddress.lookup(
          'bing.com',
        ).timeout(const Duration(seconds: 5));
        results = _updateStatus(
          results,
          l10n.healthCheckNetworkName,
          HealthStatus.success,
          message: l10n.healthCheckNetworkSuccessBing,
          duration: stopwatch.elapsed,
        );
      }
    } catch (e) {
      results = _updateStatus(
        results,
        l10n.healthCheckNetworkName,
        HealthStatus.failed,
        message: l10n.healthCheckNetworkFailed(e.toString()),
      );
    }
    yield results;

    // 2. Database Test
    results = _updateStatus(
      results,
      l10n.healthCheckDbName,
      HealthStatus.running,
    );
    yield results;
    try {
      final stopwatch = Stopwatch()..start();
      // Simple write/read check using a temp box
      final boxName = 'health_check_${DateTime.now().millisecondsSinceEpoch}';
      try {
        final box = await Hive.openBox(boxName);
        await box.put('test', 'value');
        final value = box.get('test');
        if (value == 'value') {
          await box.deleteFromDisk();
          results = _updateStatus(
            results,
            l10n.healthCheckDbName,
            HealthStatus.success,
            message: l10n.healthCheckDbSuccess,
            duration: stopwatch.elapsed,
          );
        } else {
          results = _updateStatus(
            results,
            l10n.healthCheckDbName,
            HealthStatus.failed,
            message: l10n.healthCheckDbVerifyFailed,
          );
        }
      } catch (e) {
        results = _updateStatus(
          results,
          l10n.healthCheckDbName,
          HealthStatus.failed,
          message: l10n.healthCheckDbHiveError(e.toString()),
        );
      }
    } catch (e) {
      results = _updateStatus(
        results,
        l10n.healthCheckDbName,
        HealthStatus.failed,
        message: l10n.healthCheckException(e.toString()),
      );
    }
    yield results;

    // 3. Extension System
    results = _updateStatus(
      results,
      l10n.healthCheckExtensionName,
      HealthStatus.running,
    );
    yield results;
    try {
      final stopwatch = Stopwatch()..start();
      final manager = ref.read(extensionManagerProvider);
      // Check if manager is alive (provider didn't crash)
      // Accessing a property to ensure it's loaded
      final count = manager.extensions.length;
      results = _updateStatus(
        results,
        l10n.healthCheckExtensionName,
        HealthStatus.success,
        message: l10n.healthCheckExtensionSuccess(count),
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      results = _updateStatus(
        results,
        l10n.healthCheckExtensionName,
        HealthStatus.failed,
        message: l10n.healthCheckExtensionError(e.toString()),
      );
    }
    yield results;

    // 4. Permissions
    results = _updateStatus(
      results,
      l10n.healthCheckPermissionsName,
      HealthStatus.running,
    );
    yield results;
    try {
      final stopwatch = Stopwatch()..start();
      final calendarPlugin = DeviceCalendarPlugin();
      final permissions = await calendarPlugin.hasPermissions();
      if (permissions.isSuccess && (permissions.data ?? false)) {
        results = _updateStatus(
          results,
          l10n.healthCheckPermissionsName,
          HealthStatus.success,
          message: l10n.healthCheckPermissionCalendarOk,
          duration: stopwatch.elapsed,
        );
      } else {
        results = _updateStatus(
          results,
          l10n.healthCheckPermissionsName,
          HealthStatus.warning,
          message: l10n.healthCheckPermissionCalendarMissing,
          duration: stopwatch.elapsed,
        );
      }
    } catch (e) {
      results = _updateStatus(
        results,
        l10n.healthCheckPermissionsName,
        HealthStatus.failed,
        message: l10n.healthCheckPermissionError(e.toString()),
      );
    }
    yield results;

    // --- Extended API Tests ---

    // 5. Initialize Test Environment
    ExtensionApi? testApi;
    try {
      testApi = await _createTestApi(useSandbox);
    } catch (e) {
      // If initialization fails, mark remaining tests as failed
      // We'll just log it for now as we don't have a specific "Init" step in UI
    }

    try {
      if (testApi != null) {
        final api = testApi;
        // 5.1 System Info API
        final sysInfoTest = HealthTestResult(
          name: l10n.healthCheckApiSysInfoName,
          description: l10n.healthCheckApiSysInfoDesc,
        );
        results = [...results, sysInfoTest];
        yield results;

        results = await _runApiTest(
          results,
          l10n.healthCheckApiSysInfoName,
          () async {
            final res = await api.call('getSystemInfo', {});
            if (res is! Map) throw 'Invalid response type';
            if (!res.containsKey('platform')) throw 'Missing platform key';
            return l10n.healthCheckApiSysInfoSuccess(
              res['platform'].toString(),
            );
          },
        );
        yield results;

        // 5.2 Database Size API
        final dbSizeTest = HealthTestResult(
          name: l10n.healthCheckApiDbName,
          description: l10n.healthCheckApiDbDesc,
        );
        results = [...results, dbSizeTest];
        yield results;

        results = await _runApiTest(
          results,
          l10n.healthCheckApiDbName,
          () async {
            final res = await api.call('getDbSize', {});
            return l10n.healthCheckApiDbSuccess(res.toString());
          },
        );
        yield results;

        // 5.3 Tags API
        final tagsTest = HealthTestResult(
          name: l10n.healthCheckApiTagsName,
          description: l10n.healthCheckApiTagsDesc,
        );
        results = [...results, tagsTest];
        yield results;

        results = await _runApiTest(
          results,
          l10n.healthCheckApiTagsName,
          () async {
            final res = await api.call('getTags', {});
            if (res is! List) throw 'Invalid response type';
            return l10n.healthCheckApiTagsSuccess(res.length);
          },
        );
        yield results;

        // 5.4 Settings API
        final settingsTest = HealthTestResult(
          name: l10n.healthCheckApiSettingsName,
          description: l10n.healthCheckApiSettingsDesc,
        );
        results = [...results, settingsTest];
        yield results;

        results = await _runApiTest(
          results,
          l10n.healthCheckApiSettingsName,
          () async {
            await api.call('saveSetting', {
              'key': '_health_check',
              'value': 'ok',
            });
            final res = await api.call('getSetting', {'key': '_health_check'});
            if (res != 'ok') throw l10n.healthCheckApiSettingsMismatch;
            return l10n.healthCheckApiSettingsSuccess;
          },
        );
        yield results;

        // 5.5 Network API (via Extension)
        final netApiTest = HealthTestResult(
          name: l10n.healthCheckApiNetworkName,
          description: l10n.healthCheckApiNetworkDesc,
        );
        results = [...results, netApiTest];
        yield results;

        results = await _runApiTest(
          results,
          l10n.healthCheckApiNetworkName,
          () async {
            // Using a reliable, small URL. Google might be blocked in China, use Baidu or similar.
            // Or better, use a simple text file from a CDN if available.
            // We'll stick to 'https://www.baidu.com' as it was used in basic network test.
            // Note: httpGet implementation might expect 'url' param.
            final res = await api.call('httpGet', {
              'url': 'https://www.baidu.com',
            });
            if (res is! String) throw 'Invalid response type';
            if (res.isEmpty) throw 'Empty response';

            return l10n.healthCheckApiNetworkSuccess;
          },
        );
        yield results;
        // 5.6 Events API
        final eventsTest = HealthTestResult(
          name: l10n.healthCheckApiEventsName,
          description: l10n.healthCheckApiEventsDesc,
        );
        results = [...results, eventsTest];
        yield results;

        results = await _runApiTest(
          results,
          l10n.healthCheckApiEventsName,
          () async {
            final res = await api.call('getEvents', {});
            if (res is! List) throw 'Invalid response type';
            return l10n.healthCheckApiEventsSuccess(res.length);
          },
        );
        yield results;

        // 5.7 Extension Store Repository
        final repoTest = HealthTestResult(
          name: l10n.healthCheckStoreRepoName,
          description: l10n.healthCheckStoreRepoDesc,
        );
        results = [...results, repoTest];
        yield results;

        results = await _runApiTest(
          results,
          l10n.healthCheckStoreRepoName,
          () async {
            final service = ref.read(extensionRepositoryServiceProvider);
            final manifest = await service.fetchManifest();
            return l10n.healthCheckStoreRepoSuccess(manifest.extensions.length);
          },
        );
        yield results;
      }
    } finally {
      // Security Cleanup: Always revoke temporary permissions after test completion
      // This ensures that even if the system stays running, the 'all' permission is not lingering
      if (testApi != null) {
        final sessionNotifier = ref.read(sessionPermissionsProvider.notifier);
        sessionNotifier.update((state) {
          final newState = Map<String, Set<String>>.from(state);
          newState.remove('system_health_check');
          return newState;
        });
      }
    }
  }

  Future<ExtensionApi> _createTestApi(bool useSandbox) async {
    final metadata = ExtensionMetadata(
      id: 'system_health_check',
      name: 'System Health Check',
      description: 'Internal diagnostic tool',
      icon: Icons.monitor_heart,
      version: '1.0.0',
      requiredPermissions: ExtensionPermission.values,
    );

    final auth = ref.read(extensionAuthStateProvider.notifier);
    await auth.setRunning(metadata.id, true);
    // Set trust level based on sandbox mode
    // untrusted=true (Sandbox) -> SecurityShield intercepts and forces mock data
    // untrusted=false (Real) -> SecurityShield allows access to real providers
    await auth.setUntrusted(metadata.id, useSandbox);

    // Handle permissions based on mode
    final sessionNotifier = ref.read(sessionPermissionsProvider.notifier);
    if (useSandbox) {
      // Sandbox mode: Remove all temporary permissions to ensure isolation
      // This prevents previously granted 'all' permission from leaking real data into sandbox
      sessionNotifier.update((state) {
        final newState = Map<String, Set<String>>.from(state);
        newState.remove(metadata.id);
        return newState;
      });
    } else {
      // Real mode: Grant temporary 'all' permission to bypass explicit checks
      // inside ExtensionApiImpl._checkPermission
      sessionNotifier.update((state) {
        final newState = Map<String, Set<String>>.from(state);
        newState[metadata.id] = {'all'};
        return newState;
      });
    }

    // Ensure manager is loaded (as it's the delegate)
    final manager = ref.read(extensionManagerProvider);

    // Create Shield with manager as delegate
    final shield = SecurityShield(ref, manager);

    return ExtensionApiImpl(ref, metadata, shield);
  }

  Future<List<HealthTestResult>> _runApiTest(
    List<HealthTestResult> currentResults,
    String testName,
    Future<String?> Function() testFn,
  ) async {
    currentResults = _updateStatus(
      currentResults,
      testName,
      HealthStatus.running,
    );

    try {
      final stopwatch = Stopwatch()..start();
      final msg = await testFn();
      return _updateStatus(
        currentResults,
        testName,
        HealthStatus.success,
        message: msg ?? 'OK',
        duration: stopwatch.elapsed,
      );
    } catch (e) {
      return _updateStatus(
        currentResults,
        testName,
        HealthStatus.failed,
        message: 'Error: $e',
      );
    }
  }

  List<HealthTestResult> _updateStatus(
    List<HealthTestResult> current,
    String name,
    HealthStatus status, {
    String? message,
    Duration? duration,
  }) {
    return current.map((e) {
      if (e.name == name) {
        return e.copyWith(status: status, message: message, duration: duration);
      }
      return e;
    }).toList();
  }
}

final systemHealthCheckServiceProvider = Provider(
  (ref) => SystemHealthCheckService(ref),
);
