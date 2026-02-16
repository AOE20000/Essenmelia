import 'package:flutter/material.dart';
import '../../models/event.dart';
import 'extension_metadata.dart';
import 'extension_api.dart';
import 'extension_permission.dart';

/// Extension base class
abstract class BaseExtension {
  final ExtensionMetadata metadata;

  BaseExtension(this.metadata);

  /// Extension initialization logic
  Future<void> onInit(ExtensionApi api) async {}

  /// Extension disposal logic
  Future<void> onDispose() async {}

  /// Triggered when permission is granted at runtime
  void onPermissionGranted(ExtensionPermission permission) {}

  /// Triggered when a new event is produced (distributed by Manager)
  void onEventAdded(Event event) {}

  /// Callback for receiving cross-extension events
  void onExtensionEvent(String name, Map<String, dynamic> data) {}

  /// Main UI build method for the extension
  Widget build(BuildContext context, ExtensionApi api);
}
