import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局扩展日志项
class ExtensionLogEntry {
  final String extensionId;
  final String extensionName;
  final String method;
  final Map<String, dynamic> params;
  final DateTime timestamp;
  final bool success;
  final String? error;
  final bool isUntrusted;

  ExtensionLogEntry({
    required this.extensionId,
    required this.extensionName,
    required this.method,
    required this.params,
    required this.timestamp,
    this.success = true,
    this.error,
    this.isUntrusted = false,
  });
}

/// 全局扩展日志管理器
class ExtensionLogNotifier extends StateNotifier<List<ExtensionLogEntry>> {
  ExtensionLogNotifier() : super([]);

  static const int maxLogs = 200;

  void addLog(ExtensionLogEntry entry) {
    state = [entry, ...state];
    if (state.length > maxLogs) {
      state = state.sublist(0, maxLogs);
    }
  }

  void clearLogs() {
    state = [];
  }
}

final extensionLogProvider =
    StateNotifierProvider<ExtensionLogNotifier, List<ExtensionLogEntry>>((ref) {
      return ExtensionLogNotifier();
    });
