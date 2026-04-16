import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'notification_service.dart';
import '../l10n/l10n_provider.dart';

/// Service to check for app updates from GitHub repository description
class UpdateCheckService {
  final Ref _ref;
  static const String _repoUrl = 'https://github.com/AOE20000/Essenmelia';
  static const String _apiUrl =
      'https://api.github.com/repos/AOE20000/Essenmelia';

  UpdateCheckService(this._ref);

  /// Initialize the service
  Future<void> init() async {
    // Listen to notification taps
    NotificationService().onResponse.listen((response) {
      if (response.payload == 'app_update_available') {
        _openRepo();
      }
    });
  }

  /// Perform the update check
  Future<bool> checkForUpdates({bool manual = false}) async {
    try {
      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'Essenmelia-App',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Look for pattern like "-3.2.0" or similar in description
        // The user mentioned "-3.2.0" field in description
        final regExp = RegExp(r'-(\d+\.\d+\.\d+)');
        final match = regExp.firstMatch(response.body);

        if (match != null) {
          final remoteVersion = match.group(1);
          final currentVersion = await _getCurrentVersion();

          debugPrint(
            'UpdateCheckService: Current: $currentVersion, Remote: $remoteVersion',
          );

          if (remoteVersion != null &&
              _isNewer(remoteVersion, currentVersion)) {
            _showUpdateNotification(remoteVersion);
            return true;
          } else if (manual) {
            debugPrint('UpdateCheckService: Already up to date');
          }
        }
      }
    } catch (e) {
      debugPrint('UpdateCheckService Error: $e');
    }
    return false;
  }

  Future<String> _getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  bool _isNewer(String remote, String current) {
    final remoteParts = remote.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (var i = 0; i < remoteParts.length; i++) {
      if (remoteParts[i] > currentParts[i]) return true;
      if (remoteParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  void _showUpdateNotification(String version) {
    final l10n = _ref.read(l10nProvider);
    NotificationService().showNotification(
      id: 999, // Unique ID for update notification
      title: l10n.newVersionAvailable(version),
      body: l10n.clickToDownload,
      payload: 'app_update_available',
      channelName: l10n.updateChannelName,
      channelDescription: l10n.updateChannelDescription,
    );
  }

  Future<void> _openRepo() async {
    final url = Uri.parse(_repoUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  return UpdateCheckService(ref);
});
