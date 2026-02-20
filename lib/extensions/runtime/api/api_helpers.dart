class ApiParams {
  final Map<String, dynamic> _params;

  ApiParams(this._params);

  /// Get a required parameter
  T get<T>(String key) {
    final value = _params[key];
    if (value == null) {
      throw ArgumentError('Missing required parameter: $key');
    }
    
    if (value is T) return value;
    
    // Type conversion attempts
    if (T == String) return value.toString() as T;
    if (T == int) {
      if (value is num) return value.toInt() as T;
      if (value is String) return int.parse(value) as T;
    }
    if (T == double) {
      if (value is num) return value.toDouble() as T;
      if (value is String) return double.parse(value) as T;
    }
    if (T == bool) {
      if (value is String) return (value.toLowerCase() == 'true') as T;
      if (value is num) return (value != 0) as T;
    }

    throw ArgumentError(
        'Parameter $key has invalid type: expected $T, got ${value.runtimeType}');
  }

  /// Get an optional parameter
  T? getOptional<T>(String key, [T? defaultValue]) {
    final value = _params[key];
    if (value == null) return defaultValue;
    
    if (value is T) return value;

    // Type conversion attempts for optional values
    try {
      if (T == String) return value.toString() as T;
      if (T == int) {
        if (value is num) return value.toInt() as T;
        if (value is String) return int.parse(value) as T;
      }
      if (T == double) {
        if (value is num) return value.toDouble() as T;
        if (value is String) return double.parse(value) as T;
      }
      if (T == bool) {
        if (value is String) return (value.toLowerCase() == 'true') as T;
        if (value is num) return (value != 0) as T;
      }
    } catch (e) {
      // If conversion fails, return default
      return defaultValue;
    }

    return defaultValue;
  }
  
  /// Get Map parameter safely
  Map<K, V>? getMap<K, V>(String key) {
    final value = _params[key];
    if (value == null) return null;
    if (value is Map) {
      try {
        return value.cast<K, V>();
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Get List parameter safely
  List<T>? getList<T>(String key) {
    final value = _params[key];
    if (value == null) return null;
    if (value is List) {
      try {
        return value.cast<T>();
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
