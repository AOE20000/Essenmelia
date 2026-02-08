// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Essenmelia';

  @override
  String get settings => 'Settings';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get collapseImages => 'Collapse Images';

  @override
  String get itemsPerRow => 'Items Per Row';

  @override
  String get databaseManager => 'Database Manager';

  @override
  String get manageTags => 'Manage Tags';

  @override
  String get exportData => 'Export Data (JSON)';

  @override
  String get importData => 'Import Data (JSON)';

  @override
  String get deleteAllData => 'Delete All Data';

  @override
  String get deleteAllDataConfirmTitle => 'Delete All Data?';

  @override
  String get deleteAllDataConfirmContent =>
      'This cannot be undone. All data will be permanently lost.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get create => 'Create';

  @override
  String get switchDb => 'Switch';

  @override
  String get availableDatabases => 'Available Databases';

  @override
  String get createNewDatabase => 'Create New Database';

  @override
  String get databaseName => 'Database Name';

  @override
  String get invalidName => 'Invalid name. Use letters, numbers, -, _';

  @override
  String get searchEvents => 'Search events...';

  @override
  String get noEventsFound => 'No events found';

  @override
  String get sort => 'Sort';

  @override
  String get newestFirst => 'Newest First';

  @override
  String get oldestFirst => 'Oldest First';

  @override
  String get titleAZ => 'Title (A-Z)';

  @override
  String get titleZA => 'Title (Z-A)';

  @override
  String get progressHighLow => 'Progress (High-Low)';

  @override
  String get progressLowHigh => 'Progress (Low-High)';

  @override
  String get selected => 'Selected';

  @override
  String get deleteSelected => 'Delete Selected?';

  @override
  String deleteSelectedCount(int count) {
    return 'Delete $count items?';
  }

  @override
  String get steps => 'steps';

  @override
  String stepsCount(int completed, int total) {
    return '$completed / $total steps';
  }

  @override
  String get language => 'Language';

  @override
  String get system => 'System';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';
}
