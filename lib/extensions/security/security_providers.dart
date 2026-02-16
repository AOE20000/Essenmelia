import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Records permissions granted in the current session (`Map<extensionId, Set<String>>`)
/// String can be "all" or specific Category name
final sessionPermissionsProvider = StateProvider<Map<String, Set<String>>>(
  (ref) => {},
);
