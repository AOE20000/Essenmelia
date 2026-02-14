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
  String get searchPlaceholder => 'Search events...';

  @override
  String get select => 'Select';

  @override
  String get cancel => 'Cancel';

  @override
  String get newTag => 'New Tag';

  @override
  String get tagNameHint => 'e.g., Work, Personal';

  @override
  String get add => 'Add';

  @override
  String get renameTag => 'Rename Tag';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get edit => 'Edit';

  @override
  String get create => 'Create';

  @override
  String get settings => 'Settings';

  @override
  String get manageTags => 'Manage Tags';

  @override
  String get databaseManager => 'Database Manager';

  @override
  String get importExport => 'Import / Export';

  @override
  String get appearance => 'Appearance';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get useSystemTheme => 'Use System Theme';

  @override
  String get language => 'Language';

  @override
  String get systemLanguage => 'System';

  @override
  String get cardDensity => 'Card Density';

  @override
  String get compact => 'Compact';

  @override
  String get comfortable => 'Comfortable';

  @override
  String get collapseImages => 'Collapse Images';

  @override
  String get activeDatabase => 'Active Database';

  @override
  String get availableDatabases => 'Available Databases';

  @override
  String get createNewDatabase => 'Create New Database';

  @override
  String get enterDatabaseName => 'Enter database name';

  @override
  String get switchDbConfirmation => 'Switch Database';

  @override
  String switchDbMessage(String name) {
    return 'Are you sure you want to switch to database \"$name\"?';
  }

  @override
  String get deleteDbConfirmation => 'Delete Database';

  @override
  String deleteDbMessage(String name) {
    return 'Are you sure you want to delete database \"$name\"? This action cannot be undone.';
  }

  @override
  String get dbCreated => 'Database created';

  @override
  String get dbDeleted => 'Database deleted';

  @override
  String dbSwitched(String name) {
    return 'Switched to database: $name';
  }

  @override
  String get allTags => 'All Tags';

  @override
  String get noTags => 'No tags available';

  @override
  String get tagName => 'Tag Name';

  @override
  String get tagColor => 'Tag Color';

  @override
  String get deleteTagMessage =>
      'Delete this tag? It will be removed from all events.';

  @override
  String get importData => 'Import Data';

  @override
  String get exportData => 'Export Data';

  @override
  String get exportSuccess => 'Export successful';

  @override
  String get importSuccess => 'Import successful';

  @override
  String get importError => 'Import failed';

  @override
  String get sortNewest => 'Newest First';

  @override
  String get sortOldest => 'Oldest First';

  @override
  String get sortTitleAZ => 'Title (A-Z)';

  @override
  String get sortTitleZA => 'Title (Z-A)';

  @override
  String get sortProgressHigh => 'Progress (High-Low)';

  @override
  String get sortProgressLow => 'Progress (Low-High)';

  @override
  String get sortStepCountHigh => 'Steps (More-Less)';

  @override
  String get sortStepCountLow => 'Steps (Less-More)';

  @override
  String get sortTagCountHigh => 'Tags (More-Less)';

  @override
  String get sortTagCountLow => 'Tags (Less-More)';

  @override
  String get sortLastUpdated => 'Recently Updated';

  @override
  String get sortLastUpdatedOldest => 'Least Recently Updated';

  @override
  String get statusAll => 'All';

  @override
  String get statusNotStarted => 'Not Started';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get selected => 'Selected';

  @override
  String get deleteSelectedConfirmation => 'Delete Selected?';

  @override
  String deleteSelectedMessage(int count) {
    return 'Delete $count items?';
  }

  @override
  String get editEvent => 'Edit Event';

  @override
  String get newEvent => 'New Event';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get imageUrl => 'Image URL';

  @override
  String get imageUrlPlaceholder => 'http://... or data:image...';

  @override
  String get pickImage => 'Pick Image';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get createEvent => 'Create Event';

  @override
  String get noTagsYet => 'No tags yet';

  @override
  String tagsSelected(int count) {
    return '$count tags selected';
  }

  @override
  String get clearAllTags => 'Clear Selection';

  @override
  String get deleteTagConfirmation => 'Delete Tag?';

  @override
  String deleteTagWarning(String tag) {
    return 'This will remove \"$tag\" from all events.';
  }

  @override
  String get eventNotFound => 'Event not found';

  @override
  String get eventDetails => 'Event Details';

  @override
  String createdOn(String date) {
    return 'Created on $date';
  }

  @override
  String get steps => 'Steps';

  @override
  String get manageSteps => 'Manage Steps';

  @override
  String get noStepsYet => 'No steps yet.';

  @override
  String get addStep => 'Add Step';

  @override
  String get newStepPlaceholder => 'New step...';

  @override
  String get editSteps => 'Edit Steps';

  @override
  String get archive => 'Archive';

  @override
  String get sets => 'Sets';

  @override
  String get addNewStepPlaceholder => 'Add new step...';

  @override
  String get addToArchivePlaceholder => 'Add to archive...';

  @override
  String get addedToSteps => 'Added to steps';

  @override
  String get saveCurrentStepsAsSet => 'Save current steps as Template Set';

  @override
  String get addAllToSteps => 'Add All to Steps';

  @override
  String addedStepsCount(int count) {
    return 'Added $count steps';
  }

  @override
  String stepsCount(int count) {
    return '$count steps';
  }

  @override
  String get dbNameHint => 'e.g., project-x, archive-2023';

  @override
  String get invalidDbName => 'Invalid name. Use letters, numbers, -, _';

  @override
  String get defaultDbName => 'Main Archive (Default)';

  @override
  String get currentlyActive => 'Currently Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get switchDb => 'Switch';

  @override
  String switchedToDb(String name) {
    return 'Switched to $name';
  }

  @override
  String deleteDbTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteDbWarning =>
      'This action cannot be undone. All data in this database will be lost.';

  @override
  String get saveTemplateSet => 'Save Template Set';

  @override
  String get templateName => 'Template Name';

  @override
  String get templateSetSaved => 'Template Set Saved';

  @override
  String get noEventsFound => 'No events found';

  @override
  String get sort => 'Sort';

  @override
  String get welcomeTitle => 'Welcome to Essenmelia';

  @override
  String get welcomeMessage =>
      'Manage your events, track steps, and organize your life with tags. Tap the + button to get started.';

  @override
  String selectedItemsCount(int count) {
    return '$count items selected';
  }

  @override
  String get batchArchive => 'Batch Archive';

  @override
  String get batchAdd => 'Batch Add';

  @override
  String get saveAsSet => 'Save as Set';

  @override
  String movedToArchive(int count) {
    return 'Moved $count items to archive';
  }

  @override
  String get noArchiveSteps => 'No archived steps';

  @override
  String get noStepSets => 'No step sets';

  @override
  String get saveCurrentAsSetHint =>
      'You can save current steps as a set for quick reuse later';

  @override
  String get setName => 'Set Name';

  @override
  String get setSaved => 'Set saved';

  @override
  String get tags => 'Tags';

  @override
  String get tagsPlaceholder => 'Type to search or create...';

  @override
  String createTag(String tag) {
    return 'Create \"$tag\"';
  }

  @override
  String failedToPickImage(String error) {
    return 'Failed to pick image: $error';
  }

  @override
  String get titleRequired => 'Title is required';

  @override
  String error(String error) {
    return 'Error: $error';
  }

  @override
  String get deleteAllDataTitle => 'Delete All Data?';

  @override
  String get deleteAllDataMessage => 'This cannot be undone.';

  @override
  String get deleteAllDataSuccess => 'All data deleted';

  @override
  String importFailedDetailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String exportFailedDetailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get navEvents => 'Events';

  @override
  String get navExtensions => 'Extensions';

  @override
  String get addExtension => 'Add Extension';

  @override
  String get importFromLocalFile => 'Import from local file';

  @override
  String get selectJsonExtension => 'Select .json or .zip extension package';

  @override
  String get enterUrlOrGithubLink => 'Enter URL or GitHub link';

  @override
  String get downloadAndInstallFromLink => 'Download and install from link';

  @override
  String get confirmUninstall => 'Confirm Uninstall';

  @override
  String uninstallExtensionWarning(String name) {
    return 'Are you sure you want to uninstall extension \"$name\"? All related settings will be cleared.';
  }

  @override
  String get uninstall => 'Uninstall';

  @override
  String get extensionUninstalled => 'Extension uninstalled';

  @override
  String get extensionRepository => 'Extension Repository';

  @override
  String get browseAndInstallFromGithub => 'Browse and install from GitHub';

  @override
  String get noExtensionsInstalled => 'No extensions installed';

  @override
  String get deactivated => 'Deactivated';

  @override
  String get downloadFailedCheckLink =>
      'Download failed, please check the link';

  @override
  String get manageAndPermissions => 'Manage & Permissions';

  @override
  String get exportExtensionPackage => 'Export Extension Package';

  @override
  String get expandTags => 'Expand Tags';

  @override
  String get noEventSelected => 'No event selected';

  @override
  String get noMatchingEvents => 'No matching events found';

  @override
  String get noEventsYet => 'No events yet';

  @override
  String get createFirstEvent =>
      'Click the + button to create your first event';

  @override
  String get tryAdjustingFilters =>
      'Try adjusting your filters or search query';

  @override
  String get batchEditTags => 'Batch Edit Tags';

  @override
  String batchEditTagsTitle(int count) {
    return 'Edit Tags for $count items';
  }

  @override
  String get help => 'Help';

  @override
  String get welcomeAndHelp => 'Welcome & Help';

  @override
  String get helpTitle => 'Help Center';

  @override
  String get helpMessage =>
      'Learn how to use Essenmelia here. Manage your events, steps, and extensions.';

  @override
  String get backToWelcome => 'Back to Welcome';

  @override
  String get switchToHelp => 'View Help';

  @override
  String get getStarted => 'Get Started';

  @override
  String get font => 'Font';

  @override
  String get systemFont => 'System';

  @override
  String get builtInFont => 'Built-in';

  @override
  String get dataMaintenance => 'Data Maintenance';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get formatApp => 'Format Application';

  @override
  String get formatAppWarning =>
      'This will physically delete all databases, clear all extension sandboxes, and reset all app settings. This action is IRREVERSIBLE!';

  @override
  String get formatAppConfirm => 'TYPE \'DELETE\' TO CONFIRM';

  @override
  String get formatAppPlaceholder => 'Type DELETE here';

  @override
  String get currentDbActions => 'Current Database Actions';

  @override
  String get filter => 'Filter';

  @override
  String get status => 'Status';
}
