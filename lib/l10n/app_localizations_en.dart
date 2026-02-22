// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get extensionManagement => 'Extension Management';

  @override
  String get videoLoadError => 'Failed to load video';

  @override
  String get novelContentEmpty => 'No content available';

  @override
  String get extensionRetry => 'Retry';

  @override
  String get extensionLoading => 'Loading...';

  @override
  String get searchExtensions => 'Search extensions';

  @override
  String get installedExtensions => 'Installed';

  @override
  String get availableExtensions => 'Available';

  @override
  String get extensionPermissions => 'Permissions';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get uninstallExtension => 'Uninstall Extension';

  @override
  String uninstallConfirmation(String name) {
    return 'Are you sure you want to uninstall \"$name\"?';
  }

  @override
  String pasteFailed(String error) {
    return 'Paste failed: $error';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

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
  String get extensionLoadFailed => 'Extension Load Failed';

  @override
  String get extensionNotRunning => 'Extension Not Running';

  @override
  String get enableExtensionHint =>
      'Please enable this extension in details page';

  @override
  String extensionVersion(String version) {
    return 'Version $version';
  }

  @override
  String get extensionInfo => 'Extension Info';

  @override
  String storageUsage(String size) {
    return 'Storage: $size';
  }

  @override
  String get functionDescription => 'Description';

  @override
  String get developer => 'Developer';

  @override
  String get uniqueId => 'Unique ID';

  @override
  String get developerSandbox => 'Pure Shell (Dev)';

  @override
  String get sandboxPureModeHint =>
      'This extension is running in \"Pure Shell\" mode. You can test its permissions below.';

  @override
  String get getEvents => 'Get Events';

  @override
  String getEventsSuccess(int count) {
    return 'Successfully fetched $count events';
  }

  @override
  String getEventsFailed(String error) {
    return 'Fetch failed: $error';
  }

  @override
  String get sendNotification => 'Send Notification';

  @override
  String get testNotification => 'Test notification from sandbox';

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
  String get createRecord => 'Create Record';

  @override
  String get settings => 'Settings';

  @override
  String get manageTags => 'Manage Tags';

  @override
  String get databaseManager => 'Database Manager';

  @override
  String get loading => 'Loading...';

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
  String get english => 'English';

  @override
  String get chinese => 'Chinese';

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
  String get recommendedTags => 'Recommended Tags';

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
  String get sortTime => 'Time';

  @override
  String get sortOldest => 'Oldest First';

  @override
  String get sortTitleAZ => 'Title (A-Z)';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortTitleZA => 'Title (Z-A)';

  @override
  String get sortProgressHigh => 'Progress (High-Low)';

  @override
  String get sortProgress => 'Progress';

  @override
  String get sortProgressLow => 'Progress (Low-High)';

  @override
  String get sortStepCountHigh => 'Steps (More-Less)';

  @override
  String get sortSteps => 'Steps';

  @override
  String get sortStepCountLow => 'Steps (Less-More)';

  @override
  String get sortTagCountHigh => 'Tags (More-Less)';

  @override
  String get sortTags => 'Tags';

  @override
  String get sortTagCountLow => 'Tags (Less-More)';

  @override
  String get sortLastUpdated => 'Recently Updated';

  @override
  String get sortUpdated => 'Updated';

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
  String get addNewStepPlaceholder => 'Add new step...';

  @override
  String get addedToSteps => 'Added to steps';

  @override
  String get newStepPlaceholder => 'New step...';

  @override
  String get editSteps => 'Edit Steps';

  @override
  String get extensions => 'Extensions';

  @override
  String get extensionDetails => 'Extension Details';

  @override
  String get extensionOpen => 'Open Extension';

  @override
  String get extensionLinkSubtitle => 'Supports URL or GitHub links';

  @override
  String get installFromClipboard => 'Install Link from Clipboard';

  @override
  String get installFromClipboardSubtitle => 'Supports ZIP / GitHub links';

  @override
  String get invalidInput => 'Invalid input';

  @override
  String resetFailedDetailed(String error) {
    return 'Reset failed: $error';
  }

  @override
  String dbStats(int events, int templates) {
    return '$events events, $templates templates';
  }

  @override
  String get noAvailableExtensions => 'No extensions available in the store';

  @override
  String get failedToLoadStore => 'Failed to load store';

  @override
  String get extensionDefaultButtonLabel => 'Button';

  @override
  String get retry => 'Retry';

  @override
  String get useCustomStoreLink => 'Use custom store link';

  @override
  String get customStore => 'Custom Store';

  @override
  String get load => 'Load';

  @override
  String authorLabel(String author) {
    return 'Author: $author';
  }

  @override
  String versionAuthorLabel(String version, String author) {
    return 'Version $version • Author $author';
  }

  @override
  String get aboutExtension => 'About this extension';

  @override
  String get installExtension => 'Install Extension';

  @override
  String installingExtension(String name) {
    return 'Downloading and installing $name...';
  }

  @override
  String installSuccess(String name) {
    return '$name installed successfully';
  }

  @override
  String get installFailed =>
      'Installation failed, please check the link or network';

  @override
  String installError(String error) {
    return 'Installation error: $error';
  }

  @override
  String get extensionInstallError => 'Installation error';

  @override
  String get eventReminder => 'Event Reminder';

  @override
  String get eventReminderChannelDesc => 'Used for scheduled event reminders';

  @override
  String get systemNotification => 'System Notification';

  @override
  String get systemNotificationChannelDesc =>
      'Instant notifications from the app or extensions';

  @override
  String get extensionCategoryNotifications => 'Notifications';

  @override
  String get extensionUninstall => 'Uninstall';

  @override
  String get extensionUninstallConfirm => 'Confirm Uninstall';

  @override
  String extensionUninstallMessage(String name) {
    return 'Are you sure you want to uninstall \"$name\"? This will delete all associated data and cannot be undone.';
  }

  @override
  String get extensionExport => 'Export Extension';

  @override
  String get extensionCopyGitHubLink => 'Copy GitHub Link';

  @override
  String get extensionCopyGitHubLinkSubtitle => 'Easy to share with others';

  @override
  String get extensionExportZip => 'Export ZIP Source';

  @override
  String get extensionExportZipSubtitle => 'Complete source code archive';

  @override
  String get manualImport => 'Manual Import';

  @override
  String get manualImportTitle => 'Import Extension';

  @override
  String get manualImportUrlHint => 'Enter GitHub URL or ZIP link';

  @override
  String get manualImportDescription =>
      'Supports GitHub repositories, Raw links, or direct ZIP URLs.';

  @override
  String get import => 'Import';

  @override
  String get extensionPermissionReadEvents => 'Read Events';

  @override
  String get extensionPermissionReadEventsDesc =>
      'Allows the extension to view all your events and tasks.';

  @override
  String get extensionPermissionAddEvents => 'Add Events';

  @override
  String get extensionPermissionAddEventsDesc =>
      'Allows the extension to create new tasks.';

  @override
  String get extensionPermissionUpdateEvents => 'Update Events';

  @override
  String get extensionPermissionUpdateEventsDesc =>
      'Allows the extension to modify existing tasks.';

  @override
  String get extensionPermissionDeleteEvents => 'Delete Events';

  @override
  String get extensionPermissionDeleteEventsDesc =>
      'Allows the extension to delete your tasks.';

  @override
  String get extensionPermissionReadTags => 'Read Tags';

  @override
  String get extensionPermissionReadTagsDesc =>
      'Allows the extension to view your tag list.';

  @override
  String get extensionPermissionManageTags => 'Manage Tags';

  @override
  String get extensionPermissionManageTagsDesc =>
      'Allows the extension to add or remove global tags.';

  @override
  String get extensionPermissionManageDb => 'Manage Database';

  @override
  String get extensionPermissionManageDbDesc =>
      'Allows the extension to perform database export, backup, or switching.';

  @override
  String get extensionPermissionFileSystem => 'File System';

  @override
  String get extensionPermissionFileSystemDesc =>
      'Allows the extension to save files to your device or read files.';

  @override
  String get extensionPermissionNotifications => 'Notifications';

  @override
  String get extensionPermissionNotificationsDesc =>
      'Allows the extension to send you desktop or system notifications.';

  @override
  String get extensionPermissionReadCalendar => 'Read Calendar';

  @override
  String get extensionPermissionReadCalendarDesc =>
      'Allows the extension to read your system calendar events.';

  @override
  String get extensionPermissionWriteCalendar => 'Write Calendar';

  @override
  String get extensionPermissionWriteCalendarDesc =>
      'Allows the extension to add or modify events in your system calendar.';

  @override
  String get extensionPermissionNetwork => 'Network Access';

  @override
  String get extensionPermissionNetworkDesc =>
      'Allows the extension to access the network.';

  @override
  String get extensionPermissionSystemInfo => 'System Info';

  @override
  String get extensionPermissionSystemInfoDesc =>
      'Allows the extension to access system status like themes, language, and snackbars.';

  @override
  String get extensionPermissionNavigation => 'Navigation';

  @override
  String get extensionPermissionNavigationDesc =>
      'Allows the extension to navigate to specific pages or filter searches.';

  @override
  String get extensionPermissionUIInteraction => 'UI Interaction';

  @override
  String get extensionPermissionUIInteractionDesc =>
      'Allows the extension to show dialogs, snackbars, or custom UI elements.';

  @override
  String get extensionCategoryDataReading => 'Data Reading';

  @override
  String get extensionCategoryDataWriting => 'Data Writing';

  @override
  String get extensionCategoryFileSystem => 'File System';

  @override
  String get extensionCategoryNetwork => 'Network Access';

  @override
  String get extensionCategorySystemInfo => 'System Info';

  @override
  String get extensionCategoryNavigation => 'Navigation';

  @override
  String get extensionCategoryUIInteraction => 'UI Interaction';

  @override
  String get extensionCategoryGeneral => 'General';

  @override
  String get extensionManagementTitle => 'Extensions';

  @override
  String get extensionSectionInstalled => 'Installed';

  @override
  String get extensionSectionBuiltIn => 'Built-in';

  @override
  String get extensionSectionOnline => 'GITHUB_ESSENMELIA_EXTEND';

  @override
  String updateAvailable(String version) {
    return 'New version available: $version';
  }

  @override
  String get extensionRestrictedAccess => 'Restricted Access';

  @override
  String get extensionRestrictedAccessDesc =>
      'Requires manual approval for all data access.';

  @override
  String get extensionSandboxGroupDesc =>
      'Extensions in the same group share mock data. Leave empty for default isolation.';

  @override
  String get editSandboxGroup => 'Edit Sandbox Group';

  @override
  String get enterSandboxGroupName => 'Enter sandbox group name';

  @override
  String get sandboxGroupHint => 'e.g., my_shared_group';

  @override
  String get extensionInterceptedTitle => 'Access Intercepted';

  @override
  String extensionInterceptedDesc(String name, String action) {
    return 'Extension $name $action:';
  }

  @override
  String get extensionInterceptedActionTried => 'just tried to';

  @override
  String get extensionInterceptedActionWants => 'wants to';

  @override
  String get extensionDecisionDeny => 'Deny Access';

  @override
  String get extensionDecisionDenyDesc =>
      'Provides no data, which may cause errors or limited functionality.';

  @override
  String get extensionDecisionOnce => 'Allow Once';

  @override
  String get extensionDecisionOnceDesc =>
      'Provides real data only for this specific request.';

  @override
  String get extensionDecisionNext => 'Allow Next Time';

  @override
  String get extensionDecisionNextDesc =>
      'Intercepts now, but automatically allows the next time this access occurs.';

  @override
  String get extensionDecisionSessionCategory => 'Allow Category (Session)';

  @override
  String get extensionDecisionSessionCategoryDesc =>
      'Allows all access to this category until the app is closed.';

  @override
  String get extensionDecisionSessionAll => 'Allow All (Session)';

  @override
  String get extensionDecisionSessionAllDesc =>
      'Allows all permissions for this extension until the app is closed.';

  @override
  String get archive => 'Archive';

  @override
  String get sets => 'Sets';

  @override
  String get addToArchivePlaceholder => 'Add to archive...';

  @override
  String get extensionLogsTitle => 'Extension Logs';

  @override
  String get noApiLogs => 'No API call records';

  @override
  String get noParams => 'No parameters';

  @override
  String get restrictedAccess => 'Restricted Access';

  @override
  String get logDetails => 'Call Details';

  @override
  String get extensionNameLabel => 'Extension Name';

  @override
  String get extensionIdLabel => 'Extension ID';

  @override
  String get methodLabel => 'Method';

  @override
  String get timeLabel => 'Time';

  @override
  String get statusLabel => 'Status';

  @override
  String get successLabel => 'Success';

  @override
  String get failedLabel => 'Failed';

  @override
  String get accessModeLabel => 'Access Mode';

  @override
  String get restrictedAccessIntercepted => 'Restricted Access (Intercepted)';

  @override
  String get trustedModePassthrough => 'Trusted Mode (Passthrough)';

  @override
  String get errorMessageLabel => 'Error Message';

  @override
  String get paramsDetails => 'Parameter Details';

  @override
  String get saveCurrentStepsAsSet => 'Save current steps as Template Set';

  @override
  String get addAllToSteps => 'Add All to Steps';

  @override
  String addedStepsCount(int count) {
    return '$count steps added';
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
  String get noEventsWithTag => 'No events with this tag';

  @override
  String get allEvents => 'All Events';

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
  String get selectJsonExtension => 'Select .zip extension package';

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
  String extensionUninstalled(String name) {
    return 'Extension \"$name\" uninstalled';
  }

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
  String get addTags => 'Add Tags';

  @override
  String get removeTags => 'Remove Tags';

  @override
  String tagsUpdated(int count) {
    return 'Tags updated for $count items';
  }

  @override
  String get noTagsSelected => 'No tags selected';

  @override
  String get apply => 'Apply';

  @override
  String get help => 'Help';

  @override
  String get welcome => 'Welcome';

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
  String get builtInFont => 'Google Fonts (Roboto)';

  @override
  String get fontDownloadTitle => 'Download Font?';

  @override
  String get fontDownloadContent =>
      'This will use Google Fonts which requires an internet connection to download font assets. Continue?';

  @override
  String lastSync(String time) {
    return 'Last Sync: $time';
  }

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
  String get extensionAllSystemPermissions => 'All System Permissions';

  @override
  String get extensionConfirmChoice => 'Confirm Choice';

  @override
  String get extensionRuntimeSection => 'Runtime & Security';

  @override
  String get extensionEnable => 'Enable Extension';

  @override
  String get extensionRunning => 'Running';

  @override
  String get extensionStopped => 'Stopped';

  @override
  String get extensionSandboxIsolation => 'Sandbox Isolation';

  @override
  String get extensionIsolatedSandbox => 'Isolated Sandbox';

  @override
  String extensionSharedSandbox(String id) {
    return 'Shared Sandbox: $id';
  }

  @override
  String get extensionSandboxGroup => 'Sandbox Group';

  @override
  String get extensionSandboxDesc =>
      'Sandbox groups determine data isolation. Enter the same ID to share storage.';

  @override
  String get extensionSandboxId => 'Sandbox ID';

  @override
  String get extensionSandboxDefaultHint => 'Default to Extension ID';

  @override
  String get extensionSandboxTip =>
      'Tip: Active extensions usually share the same group';

  @override
  String get extensionRequestedPermissions => 'Requested Permissions';

  @override
  String get extensionNoPermissions => 'No permissions requested';

  @override
  String get extensionUpdate => 'Update Extension';

  @override
  String get extensionInstall => 'Install Extension';

  @override
  String get extensionInformation => 'Information';

  @override
  String get extensionVersionLabel => 'Version';

  @override
  String get extensionNotInstalled => 'N/A';

  @override
  String get extensionCodeSize => 'Code';

  @override
  String get extensionStorageSize => 'Storage';

  @override
  String get extensionFullTrust => 'Full Trust';

  @override
  String get extensionFullTrustDesc => 'Direct access to system APIs';

  @override
  String get extensionPermissionsStatement => 'Permissions';

  @override
  String get extensionNoChanges => 'No changes';

  @override
  String get extensionNoPermissionsRequired => 'No permissions required';

  @override
  String get update => 'Update';

  @override
  String get install => 'Install';

  @override
  String databaseError(String error) {
    return 'Database Error: $error';
  }

  @override
  String get filter => 'Filter';

  @override
  String get status => 'Status';

  @override
  String get extensionRequested => 'Requested';

  @override
  String get onlyShowReminders => 'Only Show Reminders';

  @override
  String get onlyShowRemindersSubtitle => 'Filter out tasks without reminders';

  @override
  String get viewAll => 'View All';

  @override
  String get extensionLogs => 'Extension Logs';

  @override
  String get welcomeToExtensions => 'Welcome to Extensions';

  @override
  String get dontShowAgain => 'Don\'t show again';

  @override
  String get longPressToManageExtension => 'Long press to manage extension';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get recurrenceDaily => ' (Daily)';

  @override
  String get recurrenceWeekly => ' (Weekly)';

  @override
  String get recurrenceMonthly => ' (Monthly)';

  @override
  String get exploreEssenmelia => 'Explore Essenmelia';

  @override
  String get helpAndDocs => 'Help & Docs';

  @override
  String get welcomeSubtitle1 => 'Your personal schedule & inspiration manager';

  @override
  String get welcomeContent1 =>
      'Efficiently organize every brilliant moment in your life. Whether it\'s trivial daily tasks or grand plans, they all find a home here.';

  @override
  String get privacyFirst => 'Privacy First';

  @override
  String get welcomeSubtitle2 => 'Secure, Transparent, Controllable';

  @override
  String get welcomeContent2 =>
      'All data is stored locally. Untrusted plugins can only access forged data generated by the system, ensuring your real information never leaks.';

  @override
  String get highlyCustomizable => 'Highly Customizable';

  @override
  String get welcomeSubtitle3 => 'Follow your heart, infinite possibilities';

  @override
  String get welcomeContent3 =>
      'With a powerful plugin system, you can easily extend app functionality. Use the declarative UI engine to customize your own exclusive management tool.';

  @override
  String get startExperience => 'Start Experience';

  @override
  String get nextStep => 'Next Step';

  @override
  String get archDesign => 'Architecture Design';

  @override
  String get archDesignDesc =>
      'System layering, privacy black box & permission model';

  @override
  String get apiGuide => 'API Usage Guide';

  @override
  String get apiGuideDesc =>
      'Core methods, notification schemes & external integration';

  @override
  String get extDevSpecs => 'Extension Development Specs';

  @override
  String get extDevSpecsDesc => 'Metadata, UI component library & logic engine';

  @override
  String get createRepoGuide => 'Extension Repository Guide';

  @override
  String get createRepoGuideDesc => 'Manifest, structure & GitHub discovery';

  @override
  String get selectDocToRead => 'Please select a document to read';

  @override
  String loadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get advancedSettingsAndReminders => 'Advanced Settings & Reminders';

  @override
  String get advancedSettingsSubtitle =>
      'Display mode, count suffix, scheduled reminders';

  @override
  String get advancedSettings => 'Advanced Settings';

  @override
  String get finishSettings => 'Finish Settings';

  @override
  String get displaySettings => 'Display Settings';

  @override
  String get stepMarkerMode => 'Step Marker Display Mode';

  @override
  String get markerNumber => 'Number (1, 2, 3)';

  @override
  String get markerFirstChar => 'First Char (A, B, C)';

  @override
  String get customCountSuffix => 'Custom Count Suffix';

  @override
  String get suffixHint => 'e.g., tasks, steps, items';

  @override
  String get suffixDefaultTip => 'Leave empty to use default suffix';

  @override
  String get scheduledReminders => 'Scheduled Reminders';

  @override
  String get noReminderSet => 'No reminder set';

  @override
  String get calendarReminderDesc =>
      'Will register to system calendar, no background running required';

  @override
  String get notificationReminderDesc =>
      'Will send notification at specified time to remind you';

  @override
  String get reminderScheme => 'Reminder Scheme';

  @override
  String get inAppNotification => 'In-app Notification';

  @override
  String get systemCalendar => 'System Calendar';

  @override
  String get repeatCycle => 'Repeat Cycle';

  @override
  String get noRepeat => 'No Repeat';

  @override
  String get reminderTimeError =>
      'Reminder time cannot be earlier than current time';

  @override
  String get smartAnalysis => 'Smart Analysis Selection';

  @override
  String get brilliantMoments => 'Brilliant Moments';

  @override
  String get aiCrop => 'AI Crop';

  @override
  String get ocrResults => 'OCR Results';

  @override
  String get ocrSelectionTip =>
      'Tap to select: 1st tap for title, subsequent taps append to description';

  @override
  String get resetOcrSelection => 'Reset Text Selection';

  @override
  String get appPreview => 'App Preview';

  @override
  String get confirmApply => 'Confirm Apply';

  @override
  String get analyzingContent => 'Analyzing content...';

  @override
  String get smartAnalysisTooltip => 'Smartly analyze content';

  @override
  String get featureNotSupportedOnDesktop =>
      'This feature is not supported on desktop yet';

  @override
  String get autoFilledByAi => 'Auto-filled by AI Assistant';

  @override
  String get unsupportedFileFormat => 'Unsupported file format';

  @override
  String get noImageInClipboard => 'No image or valid link found in clipboard';

  @override
  String failedToGetImageFromLink(String error) {
    return 'Failed to get image from link: $error';
  }

  @override
  String get pickFromGallery => 'Pick from Gallery';

  @override
  String get pasteFromClipboard => 'Paste from Clipboard';

  @override
  String get clearImage => 'Clear Image';

  @override
  String get addStoryImage => 'Add an image with a story';

  @override
  String get imageUploadTip => 'Drag & drop, paste, or select an image';

  @override
  String get exportOriginalImage => 'Export Original Image';

  @override
  String get exportImage => 'Export Image';

  @override
  String processingImageFailed(String error) {
    return 'Processing image failed: $error';
  }

  @override
  String reminderAt(String time) {
    return 'Reminder: $time';
  }

  @override
  String get quickEdit => 'Quick Edit (Long press to slide)';

  @override
  String get extensionConsole => 'Extension Console';

  @override
  String get logs => 'Logs';

  @override
  String get stateTree => 'State Tree';

  @override
  String get restartEngine => 'Restart Engine';

  @override
  String get noLogs => 'No logs';

  @override
  String get currentStateVariables => 'Current State Variables (State):';

  @override
  String editState(String key) {
    return 'Edit State: $key';
  }

  @override
  String get jsonFormatValue => 'JSON Format Value';

  @override
  String get jsonHint => 'e.g., \"text\" or 123 or JSON object';

  @override
  String invalidJson(String error) {
    return 'Invalid JSON: $error';
  }

  @override
  String get fullOriginalImage => 'Full Original Image';

  @override
  String get allSystemPermissions => 'All System Permissions';

  @override
  String get extensionError => 'Extension runtime error';

  @override
  String get extensionNoUI => 'This extension has no UI interface';

  @override
  String get extensionButton => 'Button';

  @override
  String get healthCheckNetworkName => 'Network Connection';

  @override
  String get healthCheckNetworkDesc => 'Test Internet Access (DNS)';

  @override
  String get healthCheckDbName => 'Database Integrity';

  @override
  String get healthCheckDbDesc => 'Verify local storage R/W';

  @override
  String get healthCheckExtensionName => 'Extension System';

  @override
  String get healthCheckExtensionDesc => 'Check Extension Manager Status';

  @override
  String get healthCheckPermissionsName => 'System Permissions';

  @override
  String get healthCheckPermissionsDesc => 'Check Calendar/Notification';

  @override
  String get healthCheckNetworkSuccessBaidu => 'Connected (Baidu DNS)';

  @override
  String get healthCheckNetworkSuccessBing => 'Connected (Bing DNS)';

  @override
  String healthCheckNetworkFailed(String error) {
    return 'DNS Resolution Failed: $error';
  }

  @override
  String get healthCheckDbSuccess => 'R/W OK';

  @override
  String get healthCheckDbVerifyFailed => 'R/W Verification Failed';

  @override
  String healthCheckDbHiveError(String error) {
    return 'Hive Error: $error';
  }

  @override
  String healthCheckException(String error) {
    return 'Exception: $error';
  }

  @override
  String healthCheckExtensionSuccess(int count) {
    return 'Service Running ($count extensions)';
  }

  @override
  String healthCheckExtensionError(String error) {
    return 'Provider Exception: $error';
  }

  @override
  String get healthCheckPermissionCalendarOk => 'Calendar Permission OK';

  @override
  String get healthCheckPermissionCalendarMissing =>
      'Missing Calendar Permission';

  @override
  String healthCheckPermissionError(String error) {
    return 'Check Failed: $error';
  }

  @override
  String get healthCheckApiSysInfoName => 'API: System Info';

  @override
  String get healthCheckApiSysInfoDesc => 'Test getSystemInfo';

  @override
  String healthCheckApiSysInfoSuccess(String platform) {
    return 'Platform: $platform';
  }

  @override
  String get healthCheckApiDbName => 'API: Database';

  @override
  String get healthCheckApiDbDesc => 'Test getDbSize';

  @override
  String healthCheckApiDbSuccess(String size) {
    return 'Size: $size';
  }

  @override
  String get healthCheckApiTagsName => 'API: Tags';

  @override
  String get healthCheckApiTagsDesc => 'Test getTags';

  @override
  String healthCheckApiTagsSuccess(int count) {
    return 'Tags count: $count';
  }

  @override
  String get healthCheckApiSettingsName => 'API: Settings';

  @override
  String get healthCheckApiSettingsDesc => 'Test getSetting/saveSetting';

  @override
  String get healthCheckApiSettingsSuccess => 'Read/Write OK';

  @override
  String get healthCheckApiSettingsMismatch => 'Read/Write mismatch';

  @override
  String get healthCheckApiNetworkName => 'API: Network';

  @override
  String get healthCheckApiNetworkDesc => 'Test httpGet (via Extension)';

  @override
  String get healthCheckApiNetworkSuccess => 'Status: 200 OK';

  @override
  String get healthCheckApiEventsName => 'API: Events';

  @override
  String get healthCheckApiEventsDesc => 'Test getEvents';

  @override
  String healthCheckApiEventsSuccess(int count) {
    return 'Events count: $count';
  }

  @override
  String get healthCheckStoreRepoName => 'Store: Repository';

  @override
  String get healthCheckStoreRepoDesc => 'Test Extension Store Connection';

  @override
  String healthCheckStoreRepoSuccess(int count) {
    return 'Extensions: $count';
  }

  @override
  String get healthCheckRunTooltip => 'Run System Diagnostic';

  @override
  String get healthCheckTitle => 'System Health Diagnostic';

  @override
  String get healthCheckRerunTooltip => 'Rerun';

  @override
  String get healthCheckEnvironment => 'Environment';

  @override
  String get healthCheckSandboxMode => 'Sandbox Simulation';

  @override
  String get healthCheckRealMode => 'Real Environment';

  @override
  String get disabledInBookMode => 'Unavailable in book mode';
}
