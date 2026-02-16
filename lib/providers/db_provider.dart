import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/ui_state_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/settings_provider.dart';
import '../extensions/manager/extension_manager.dart';
import '../models/event.dart';

// Meta box to store app-wide settings like list of DBs and active DB
const String kMetaBoxName = 'essenmelia_meta';
const String kActiveDbKey = 'active_db';
const String kDbListKey = 'db_list';
const String kDefaultDbName = 'main';

class DbState {
  final String activeDbPrefix;
  final List<String> availableDbs;

  const DbState({required this.activeDbPrefix, required this.availableDbs});
}

class DbController extends StateNotifier<AsyncValue<DbState>> {
  final Ref _ref;
  DbController(this._ref) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    try {
      if (!Hive.isBoxOpen(kMetaBoxName)) {
        await Hive.openBox(kMetaBoxName);
      }
      final metaBox = Hive.box(kMetaBoxName);

      // Also ensure settings box is open as many providers depend on it
      if (!Hive.isBoxOpen('settings')) {
        await Hive.openBox('settings');
      }

      // Load active DB
      String activeDb = metaBox.get(kActiveDbKey, defaultValue: kDefaultDbName);

      // Load DB list
      List<String> dbs = List<String>.from(
        metaBox.get(kDbListKey, defaultValue: [kDefaultDbName]),
      );

      // Ensure main exists
      if (!dbs.contains(kDefaultDbName)) {
        dbs.add(kDefaultDbName);
        await metaBox.put(kDbListKey, dbs);
      }

      await _openDbBoxes(activeDb);

      state = AsyncValue.data(
        DbState(activeDbPrefix: activeDb, availableDbs: dbs),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _openDbBoxes(String prefix) async {
    // Close currently open boxes if any (except meta and settings which are global)
    // Actually, Hive handles multiple open boxes fine, but we should be careful.
    // We will just open the new ones. Accessors should use the active prefix.

    await Hive.openBox<Event>('${prefix}_events');
    await Hive.openBox<StepTemplate>('${prefix}_templates');
    await Hive.openBox<StepSetTemplate>('${prefix}_set_templates');
    await Hive.openBox<String>('${prefix}_tags');
  }

  Future<void> switchDb(String dbName) async {
    final metaBox = Hive.box(kMetaBoxName);
    await metaBox.put(kActiveDbKey, dbName);
    await _openDbBoxes(dbName);

    // Refresh state
    final dbs = List<String>.from(metaBox.get(kDbListKey));
    state = AsyncValue.data(DbState(activeDbPrefix: dbName, availableDbs: dbs));
  }

  Future<void> createDb(String dbName) async {
    final metaBox = Hive.box(kMetaBoxName);
    final dbs = List<String>.from(
      metaBox.get(kDbListKey, defaultValue: [kDefaultDbName]),
    );

    if (!dbs.contains(dbName)) {
      dbs.add(dbName);
      await metaBox.put(kDbListKey, dbs);

      // Update state but don't switch yet (or should we? let's just update list)
      state = AsyncValue.data(
        DbState(activeDbPrefix: state.value!.activeDbPrefix, availableDbs: dbs),
      );
    }
  }

  Future<void> deleteDb(String dbName) async {
    if (dbName == kDefaultDbName) return; // Cannot delete main

    final metaBox = Hive.box(kMetaBoxName);
    final dbs = List<String>.from(metaBox.get(kDbListKey));

    if (dbs.contains(dbName)) {
      dbs.remove(dbName);
      await metaBox.put(kDbListKey, dbs);

      // Delete actual boxes
      await Hive.deleteBoxFromDisk('${dbName}_events');
      await Hive.deleteBoxFromDisk('${dbName}_templates');
      await Hive.deleteBoxFromDisk('${dbName}_set_templates');
      await Hive.deleteBoxFromDisk('${dbName}_tags');

      // If we deleted the active DB, switch to main
      if (state.value!.activeDbPrefix == dbName) {
        await switchDb(kDefaultDbName);
      } else {
        state = AsyncValue.data(
          DbState(
            activeDbPrefix: state.value!.activeDbPrefix,
            availableDbs: dbs,
          ),
        );
      }
    }
  }

  /// Reset all app data (Format)
  Future<void> resetAll() async {
    try {
      state = const AsyncValue.loading();

      // 1. Get all database list
      final metaBox = Hive.box(kMetaBoxName);
      final dbs = List<String>.from(
        metaBox.get(kDbListKey, defaultValue: [kDefaultDbName]),
      );

      // 2. Close and delete all related database boxes
      for (final dbName in dbs) {
        // Close boxes before deleting to ensure file handles are released
        if (Hive.isBoxOpen('${dbName}_events')) {
          await Hive.box<Event>('${dbName}_events').close();
        }
        if (Hive.isBoxOpen('${dbName}_templates')) {
          await Hive.box<StepTemplate>('${dbName}_templates').close();
        }
        if (Hive.isBoxOpen('${dbName}_set_templates')) {
          await Hive.box<StepSetTemplate>('${dbName}_set_templates').close();
        }
        if (Hive.isBoxOpen('${dbName}_tags')) {
          await Hive.box<String>('${dbName}_tags').close();
        }

        await Hive.deleteBoxFromDisk('${dbName}_events');
        await Hive.deleteBoxFromDisk('${dbName}_templates');
        await Hive.deleteBoxFromDisk('${dbName}_set_templates');
        await Hive.deleteBoxFromDisk('${dbName}_tags');
      }

      // 3. Reset extension framework
      await _ref.read(extensionManagerProvider.notifier).resetAll();

      // 4. Clear settings and metadata
      if (Hive.isBoxOpen('settings')) {
        await Hive.box('settings').clear();
      }
      await metaBox.clear();

      // 5. Re-initialize database controller state (this will set state to data, unblocking dbProvider.future)
      await _init();

      // 6. Refresh UI state providers that depend on the database
      // Note: Must be called after _init() because reinit() calls internally await ref.read(dbProvider.future)
      await _ref.read(uiStateProvider.notifier).reinit();
      await _ref.read(themeProvider.notifier).reinit();
      await _ref.read(localeProvider.notifier).reinit();
      await _ref.read(displaySettingsProvider.notifier).reinit();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final dbControllerProvider =
    StateNotifierProvider<DbController, AsyncValue<DbState>>((ref) {
      return DbController(ref);
    });

// Helper to get current box name
final activePrefixProvider = Provider<String>((ref) {
  final dbState = ref.watch(dbControllerProvider);
  return dbState.asData?.value.activeDbPrefix ?? kDefaultDbName;
});

// Re-export legacy provider for compatibility (now waits for controller)
final dbProvider = FutureProvider<void>((ref) async {
  final asyncState = ref.watch(dbControllerProvider);

  if (asyncState.isLoading) {
    // Wait for the stream to emit a non-loading state
    await ref
        .watch(dbControllerProvider.notifier)
        .stream
        .firstWhere((s) => !s.isLoading);
  } else if (asyncState.hasError) {
    throw asyncState.error!;
  }
});
