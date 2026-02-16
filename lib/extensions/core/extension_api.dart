import '../../models/event.dart';

/// Extension controlled API interface
abstract class ExtensionApi {
  /// Get all events (permission controlled)
  Future<List<Event>> getEvents();

  /// Get all tags
  Future<List<String>> getTags();

  /// Add new tag
  Future<void> addTag(String tag);

  /// Navigate to a specific route in the main app
  void navigateTo(String route);

  /// Show snackbar message
  void showSnackBar(String message);

  /// Show system notification
  Future<void> showNotification({
    required String title,
    required String body,
    int? id,
    String? payload,
  });

  /// Show confirmation dialog
  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String? confirmLabel,
    String? cancelLabel,
  });

  /// Export data to file
  Future<bool> exportFile(String content, String fileName);

  /// Select file and read content
  Future<String?> pickFile({List<String>? allowedExtensions});

  /// HTTP GET request
  Future<String?> httpGet(String url, {Map<String, String>? headers});

  /// HTTP POST request
  Future<String?> httpPost(
    String url, {
    Map<String, String>? headers,
    Object? body,
  });

  /// HTTP PUT request
  Future<String?> httpPut(
    String url, {
    Map<String, String>? headers,
    Object? body,
  });

  /// HTTP DELETE request
  Future<String?> httpDelete(String url, {Map<String, String>? headers});

  /// Open URL in system browser
  Future<void> openUrl(String url);

  /// Set homepage search query filter
  void setSearchQuery(String query);

  /// Create new event
  Future<void> addEvent({
    required String title,
    String? description,
    List<String>? tags,
    String? imageUrl,
    String? stepDisplayMode,
    String? stepSuffix,
    DateTime? reminderTime,
    String? reminderRecurrence,
    String? reminderScheme,
  });

  /// Delete event
  Future<void> deleteEvent(String id);

  /// Update existing event
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
  });

  /// Add step to event
  Future<void> addStep(String eventId, String description);

  /// Get database size of the current extension (bytes)
  Future<int> getDbSize();

  /// Get current theme mode (light/dark)
  String getThemeMode();

  /// Get current locale (zh/en)
  String getLocale();

  /// Get/Save extension specific settings
  Future<T?> getSetting<T>(String key);
  Future<void> saveSetting<T>(String key, T value);

  /// General API call method (routed by logic engine)
  Future<dynamic> call(String method, Map<String, dynamic> params);

  /// Publish cross-extension event
  void publishEvent(String name, Map<String, dynamic> data);
}
