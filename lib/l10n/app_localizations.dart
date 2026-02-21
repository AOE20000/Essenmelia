import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Title for extension management screen
  ///
  /// In en, this message translates to:
  /// **'Extension Management'**
  String get extensionManagement;

  /// Placeholder for extension search bar
  ///
  /// In en, this message translates to:
  /// **'Search extensions'**
  String get searchExtensions;

  /// Section header for installed extensions
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installedExtensions;

  /// Section header for available extensions
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get availableExtensions;

  /// Label for permissions tab or section
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get extensionPermissions;

  /// Message shown when text is copied to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// Title for uninstall confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Uninstall Extension'**
  String get uninstallExtension;

  /// Message for uninstall confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to uninstall \"{name}\"?'**
  String uninstallConfirmation(String name);

  /// Error message when pasting from clipboard fails
  ///
  /// In en, this message translates to:
  /// **'Paste failed: {error}'**
  String pasteFailed(String error);

  /// Error message when exporting image fails
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Essenmelia'**
  String get appTitle;

  /// Placeholder text in the search bar
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get searchPlaceholder;

  /// Label for selection action
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// Label for cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Title for creating a new tag
  ///
  /// In en, this message translates to:
  /// **'New Tag'**
  String get newTag;

  /// Hint text for tag name input
  ///
  /// In en, this message translates to:
  /// **'e.g., Work, Personal'**
  String get tagNameHint;

  /// Label for add action
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Title for renaming a tag
  ///
  /// In en, this message translates to:
  /// **'Rename Tag'**
  String get renameTag;

  /// Label for save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Label for delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Label for confirm action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Label for edit action
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Label for create action
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Label for creating a new record
  ///
  /// In en, this message translates to:
  /// **'Create Record'**
  String get createRecord;

  /// Label for settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Title for tag management
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get manageTags;

  /// Title for database management
  ///
  /// In en, this message translates to:
  /// **'Database Manager'**
  String get databaseManager;

  /// Generic loading message
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Label for import/export feature
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get importExport;

  /// Title for appearance settings
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// Label for dark mode toggle
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Label for light theme mode
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// Label for dark theme mode
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// Label for system theme sync
  ///
  /// In en, this message translates to:
  /// **'Use System Theme'**
  String get useSystemTheme;

  /// Label for language selection
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// English language name
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Chinese language name
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// Label for system language sync
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// Label for card layout density
  ///
  /// In en, this message translates to:
  /// **'Card Density'**
  String get cardDensity;

  /// Label for compact layout
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compact;

  /// Label for comfortable layout
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortable;

  /// Label for collapsing images toggle
  ///
  /// In en, this message translates to:
  /// **'Collapse Images'**
  String get collapseImages;

  /// Label for currently active database
  ///
  /// In en, this message translates to:
  /// **'Active Database'**
  String get activeDatabase;

  /// Label for list of available databases
  ///
  /// In en, this message translates to:
  /// **'Available Databases'**
  String get availableDatabases;

  /// Button label to create a new database
  ///
  /// In en, this message translates to:
  /// **'Create New Database'**
  String get createNewDatabase;

  /// Hint text for database name input
  ///
  /// In en, this message translates to:
  /// **'Enter database name'**
  String get enterDatabaseName;

  /// Title for switching database dialog
  ///
  /// In en, this message translates to:
  /// **'Switch Database'**
  String get switchDbConfirmation;

  /// Confirmation message for switching database
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to switch to database \"{name}\"?'**
  String switchDbMessage(String name);

  /// Title for deleting database dialog
  ///
  /// In en, this message translates to:
  /// **'Delete Database'**
  String get deleteDbConfirmation;

  /// Confirmation message for deleting database
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete database \"{name}\"? This action cannot be undone.'**
  String deleteDbMessage(String name);

  /// Snackbar message after database creation
  ///
  /// In en, this message translates to:
  /// **'Database created'**
  String get dbCreated;

  /// Snackbar message after database deletion
  ///
  /// In en, this message translates to:
  /// **'Database deleted'**
  String get dbDeleted;

  /// Snackbar message after database switch
  ///
  /// In en, this message translates to:
  /// **'Switched to database: {name}'**
  String dbSwitched(String name);

  /// Label for showing all tags
  ///
  /// In en, this message translates to:
  /// **'All Tags'**
  String get allTags;

  /// Title for recommended tags section
  ///
  /// In en, this message translates to:
  /// **'Recommended Tags'**
  String get recommendedTags;

  /// Message shown when no tags exist
  ///
  /// In en, this message translates to:
  /// **'No tags available'**
  String get noTags;

  /// Label for tag name input
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get tagName;

  /// Label for tag color picker
  ///
  /// In en, this message translates to:
  /// **'Tag Color'**
  String get tagColor;

  /// Confirmation message for deleting a tag
  ///
  /// In en, this message translates to:
  /// **'Delete this tag? It will be removed from all events.'**
  String get deleteTagMessage;

  /// Label for data import
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// Label for data export
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// Snackbar message after successful export
  ///
  /// In en, this message translates to:
  /// **'Export successful'**
  String get exportSuccess;

  /// Snackbar message after successful import
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get importSuccess;

  /// Snackbar message after failed import
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importError;

  /// Label for newest first sorting
  ///
  /// In en, this message translates to:
  /// **'Newest First'**
  String get sortNewest;

  /// Short label for time sorting
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get sortTime;

  /// Label for oldest first sorting
  ///
  /// In en, this message translates to:
  /// **'Oldest First'**
  String get sortOldest;

  /// Label for alphabetical title sorting
  ///
  /// In en, this message translates to:
  /// **'Title (A-Z)'**
  String get sortTitleAZ;

  /// Short label for title sorting
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// Label for reverse alphabetical title sorting
  ///
  /// In en, this message translates to:
  /// **'Title (Z-A)'**
  String get sortTitleZA;

  /// Label for high progress sorting
  ///
  /// In en, this message translates to:
  /// **'Progress (High-Low)'**
  String get sortProgressHigh;

  /// Short label for progress sorting
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get sortProgress;

  /// Label for low progress sorting
  ///
  /// In en, this message translates to:
  /// **'Progress (Low-High)'**
  String get sortProgressLow;

  /// Label for most steps sorting
  ///
  /// In en, this message translates to:
  /// **'Steps (More-Less)'**
  String get sortStepCountHigh;

  /// Short label for steps sorting
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get sortSteps;

  /// Label for least steps sorting
  ///
  /// In en, this message translates to:
  /// **'Steps (Less-More)'**
  String get sortStepCountLow;

  /// Label for most tags sorting
  ///
  /// In en, this message translates to:
  /// **'Tags (More-Less)'**
  String get sortTagCountHigh;

  /// Short label for tags sorting
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get sortTags;

  /// Label for least tags sorting
  ///
  /// In en, this message translates to:
  /// **'Tags (Less-More)'**
  String get sortTagCountLow;

  /// Label for recently updated sorting
  ///
  /// In en, this message translates to:
  /// **'Recently Updated'**
  String get sortLastUpdated;

  /// Short label for updated sorting
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get sortUpdated;

  /// Label for least recently updated sorting
  ///
  /// In en, this message translates to:
  /// **'Least Recently Updated'**
  String get sortLastUpdatedOldest;

  /// Label for 'all' status filter
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusAll;

  /// Label for 'not started' status
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get statusNotStarted;

  /// Label for 'in progress' status
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// Label for 'completed' status
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// Label for selected items
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// Confirmation dialog title for deleting selected items
  ///
  /// In en, this message translates to:
  /// **'Delete Selected?'**
  String get deleteSelectedConfirmation;

  /// Confirmation message for deleting multiple selected items
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items?'**
  String deleteSelectedMessage(int count);

  /// Title for editing an event
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEvent;

  /// Title for creating a new event
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get newEvent;

  /// Label for title input
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// Label for description input
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Label for image URL input
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrl;

  /// Hint text for image URL input
  ///
  /// In en, this message translates to:
  /// **'http://... or data:image...'**
  String get imageUrlPlaceholder;

  /// Label for image picker button
  ///
  /// In en, this message translates to:
  /// **'Pick Image'**
  String get pickImage;

  /// Button label to save changes
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// Button label to create a new event
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get createEvent;

  /// Message shown when no tags are assigned
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get noTagsYet;

  /// Label showing number of selected tags
  ///
  /// In en, this message translates to:
  /// **'{count} tags selected'**
  String tagsSelected(int count);

  /// Label for clearing tag selection
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get clearAllTags;

  /// Confirmation dialog title for deleting a tag
  ///
  /// In en, this message translates to:
  /// **'Delete Tag?'**
  String get deleteTagConfirmation;

  /// Warning message for tag deletion
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{tag}\" from all events.'**
  String deleteTagWarning(String tag);

  /// Message shown when an event cannot be found
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get eventNotFound;

  /// Title for event details page
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get eventDetails;

  /// Label showing event creation date
  ///
  /// In en, this message translates to:
  /// **'Created on {date}'**
  String createdOn(String date);

  /// Label for steps section
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// Label for step management
  ///
  /// In en, this message translates to:
  /// **'Manage Steps'**
  String get manageSteps;

  /// Message shown when an event has no steps
  ///
  /// In en, this message translates to:
  /// **'No steps yet.'**
  String get noStepsYet;

  /// Label for adding a new step
  ///
  /// In en, this message translates to:
  /// **'Add Step'**
  String get addStep;

  /// Hint text for adding a new step
  ///
  /// In en, this message translates to:
  /// **'Add new step...'**
  String get addNewStepPlaceholder;

  /// Snackbar message when an item is added to steps
  ///
  /// In en, this message translates to:
  /// **'Added to steps'**
  String get addedToSteps;

  /// Hint text for new step input
  ///
  /// In en, this message translates to:
  /// **'New step...'**
  String get newStepPlaceholder;

  /// Title for editing steps
  ///
  /// In en, this message translates to:
  /// **'Edit Steps'**
  String get editSteps;

  /// Label for extensions section
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get extensions;

  /// Title for extension details page
  ///
  /// In en, this message translates to:
  /// **'Extension Details'**
  String get extensionDetails;

  /// Label for opening an extension
  ///
  /// In en, this message translates to:
  /// **'Open Extension'**
  String get extensionOpen;

  /// Subtitle for link-based extension installation
  ///
  /// In en, this message translates to:
  /// **'Supports URL or GitHub links'**
  String get extensionLinkSubtitle;

  /// Label for clipboard-based extension installation
  ///
  /// In en, this message translates to:
  /// **'Install Link from Clipboard'**
  String get installFromClipboard;

  /// Subtitle for clipboard-based extension installation
  ///
  /// In en, this message translates to:
  /// **'Supports ZIP / GitHub links'**
  String get installFromClipboardSubtitle;

  /// Generic error message for invalid input
  ///
  /// In en, this message translates to:
  /// **'Invalid input'**
  String get invalidInput;

  /// Error message for failed reset
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String resetFailedDetailed(String error);

  /// Statistics for a database
  ///
  /// In en, this message translates to:
  /// **'{events} events, {templates} templates'**
  String dbStats(int events, int templates);

  /// Message shown when no extensions are found in store
  ///
  /// In en, this message translates to:
  /// **'No extensions available in the store'**
  String get noAvailableExtensions;

  /// Error message when store fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load store'**
  String get failedToLoadStore;

  /// Label for pure metadata extension mode
  ///
  /// In en, this message translates to:
  /// **'Pure Mode (Metadata only)'**
  String get extensionPureMode;

  /// Label for extension storage usage
  ///
  /// In en, this message translates to:
  /// **'Storage: {size}'**
  String extensionStorageOccupied(String size);

  /// Title for extension developer sandbox
  ///
  /// In en, this message translates to:
  /// **'Developer Sandbox'**
  String get extensionDeveloperSandbox;

  /// Instruction for extension developer sandbox
  ///
  /// In en, this message translates to:
  /// **'This extension is running as a \'pure shell\'. You can test its permissions below.'**
  String get extensionSandboxInstruction;

  /// Button label to get events in sandbox
  ///
  /// In en, this message translates to:
  /// **'Get Events'**
  String get extensionGetEvents;

  /// Button label to send notification in sandbox
  ///
  /// In en, this message translates to:
  /// **'Send Notification'**
  String get extensionSendNotification;

  /// Success message for getting events in sandbox
  ///
  /// In en, this message translates to:
  /// **'Successfully fetched {count} events'**
  String extensionGetEventsSuccess(int count);

  /// Error message for getting events in sandbox
  ///
  /// In en, this message translates to:
  /// **'Fetch failed: {error}'**
  String extensionGetEventsFailed(String error);

  /// Test notification message from sandbox
  ///
  /// In en, this message translates to:
  /// **'Test notification from extension sandbox'**
  String get extensionSandboxNotification;

  /// Default label for extension buttons
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get extensionDefaultButtonLabel;

  /// Label for retry action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Label for using a custom extension store
  ///
  /// In en, this message translates to:
  /// **'Use custom store link'**
  String get useCustomStoreLink;

  /// Title for custom store dialog
  ///
  /// In en, this message translates to:
  /// **'Custom Store'**
  String get customStore;

  /// Label for load action
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get load;

  /// Label for extension author
  ///
  /// In en, this message translates to:
  /// **'Author: {author}'**
  String authorLabel(String author);

  /// Label for version and author
  ///
  /// In en, this message translates to:
  /// **'Version {version} • Author {author}'**
  String versionAuthorLabel(String version, String author);

  /// Section header for extension info
  ///
  /// In en, this message translates to:
  /// **'About this extension'**
  String get aboutExtension;

  /// Label for installing an extension
  ///
  /// In en, this message translates to:
  /// **'Install Extension'**
  String get installExtension;

  /// Snackbar message during installation
  ///
  /// In en, this message translates to:
  /// **'Downloading and installing {name}...'**
  String installingExtension(String name);

  /// Snackbar message after successful installation
  ///
  /// In en, this message translates to:
  /// **'{name} installed successfully'**
  String installSuccess(String name);

  /// Error message for failed installation
  ///
  /// In en, this message translates to:
  /// **'Installation failed, please check the link or network'**
  String get installFailed;

  /// Detailed error message for installation
  ///
  /// In en, this message translates to:
  /// **'Installation error: {error}'**
  String installError(String error);

  /// Error message when extension installation fails
  ///
  /// In en, this message translates to:
  /// **'Installation error'**
  String get extensionInstallError;

  /// Title for event reminder notifications
  ///
  /// In en, this message translates to:
  /// **'Event Reminder'**
  String get eventReminder;

  /// Description for the event reminder notification channel
  ///
  /// In en, this message translates to:
  /// **'Used for scheduled event reminders'**
  String get eventReminderChannelDesc;

  /// Title for system notifications
  ///
  /// In en, this message translates to:
  /// **'System Notification'**
  String get systemNotification;

  /// Description for the system notification channel
  ///
  /// In en, this message translates to:
  /// **'Instant notifications from the app or extensions'**
  String get systemNotificationChannelDesc;

  /// Category for extension notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get extensionCategoryNotifications;

  /// Label for uninstalling an extension
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get extensionUninstall;

  /// Title for extension uninstall confirmation
  ///
  /// In en, this message translates to:
  /// **'Confirm Uninstall'**
  String get extensionUninstallConfirm;

  /// Confirmation message for uninstalling an extension
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to uninstall \"{name}\"? This will delete all associated data and cannot be undone.'**
  String extensionUninstallMessage(String name);

  /// Label for exporting an extension
  ///
  /// In en, this message translates to:
  /// **'Export Extension'**
  String get extensionExport;

  /// Label for copying GitHub link
  ///
  /// In en, this message translates to:
  /// **'Copy GitHub Link'**
  String get extensionCopyGitHubLink;

  /// Subtitle for copying GitHub link
  ///
  /// In en, this message translates to:
  /// **'Easy to share with others'**
  String get extensionCopyGitHubLinkSubtitle;

  /// Label for ZIP export format
  ///
  /// In en, this message translates to:
  /// **'Export ZIP Source'**
  String get extensionExportZip;

  /// Subtitle for ZIP export format
  ///
  /// In en, this message translates to:
  /// **'Complete source code archive'**
  String get extensionExportZipSubtitle;

  /// Label for manual import
  ///
  /// In en, this message translates to:
  /// **'Manual Import'**
  String get manualImport;

  /// Title for manual import dialog
  ///
  /// In en, this message translates to:
  /// **'Import Extension'**
  String get manualImportTitle;

  /// Hint text for manual import URL
  ///
  /// In en, this message translates to:
  /// **'Enter GitHub URL or ZIP link'**
  String get manualImportUrlHint;

  /// Description for manual import
  ///
  /// In en, this message translates to:
  /// **'Supports GitHub repositories, Raw links, or direct ZIP URLs.'**
  String get manualImportDescription;

  /// Generic import button label
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// Permission label for reading events
  ///
  /// In en, this message translates to:
  /// **'Read Events'**
  String get extensionPermissionReadEvents;

  /// Permission description for reading events
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to view all your events and tasks.'**
  String get extensionPermissionReadEventsDesc;

  /// Permission label for adding events
  ///
  /// In en, this message translates to:
  /// **'Add Events'**
  String get extensionPermissionAddEvents;

  /// Permission description for adding events
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to create new tasks.'**
  String get extensionPermissionAddEventsDesc;

  /// Permission label for updating events
  ///
  /// In en, this message translates to:
  /// **'Update Events'**
  String get extensionPermissionUpdateEvents;

  /// Permission description for updating events
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to modify existing tasks.'**
  String get extensionPermissionUpdateEventsDesc;

  /// Permission label for deleting events
  ///
  /// In en, this message translates to:
  /// **'Delete Events'**
  String get extensionPermissionDeleteEvents;

  /// Permission description for deleting events
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to delete your tasks.'**
  String get extensionPermissionDeleteEventsDesc;

  /// Permission label for reading tags
  ///
  /// In en, this message translates to:
  /// **'Read Tags'**
  String get extensionPermissionReadTags;

  /// Permission description for reading tags
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to view your tag list.'**
  String get extensionPermissionReadTagsDesc;

  /// Permission label for managing tags
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get extensionPermissionManageTags;

  /// Permission description for managing tags
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to add or remove global tags.'**
  String get extensionPermissionManageTagsDesc;

  /// Permission label for database management
  ///
  /// In en, this message translates to:
  /// **'Manage Database'**
  String get extensionPermissionManageDb;

  /// Permission description for database management
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to perform database export, backup, or switching.'**
  String get extensionPermissionManageDbDesc;

  /// Permission label for file system access
  ///
  /// In en, this message translates to:
  /// **'File System'**
  String get extensionPermissionFileSystem;

  /// Permission description for file system access
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to save files to your device or read files.'**
  String get extensionPermissionFileSystemDesc;

  /// Permission label for notifications
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get extensionPermissionNotifications;

  /// Permission description for notifications
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to send you desktop or system notifications.'**
  String get extensionPermissionNotificationsDesc;

  /// Permission label for reading calendar
  ///
  /// In en, this message translates to:
  /// **'Read Calendar'**
  String get extensionPermissionReadCalendar;

  /// Permission description for reading calendar
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to read your system calendar events.'**
  String get extensionPermissionReadCalendarDesc;

  /// Permission label for writing calendar
  ///
  /// In en, this message translates to:
  /// **'Write Calendar'**
  String get extensionPermissionWriteCalendar;

  /// Permission description for writing calendar
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to add or modify events in your system calendar.'**
  String get extensionPermissionWriteCalendarDesc;

  /// Permission label for network access
  ///
  /// In en, this message translates to:
  /// **'Network Access'**
  String get extensionPermissionNetwork;

  /// Permission description for network access
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to access the network.'**
  String get extensionPermissionNetworkDesc;

  /// Permission label for system info
  ///
  /// In en, this message translates to:
  /// **'System Info'**
  String get extensionPermissionSystemInfo;

  /// Permission description for system info
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to access system status like themes, language, and snackbars.'**
  String get extensionPermissionSystemInfoDesc;

  /// Permission label for navigation
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get extensionPermissionNavigation;

  /// Permission description for navigation
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to navigate to specific pages or filter searches.'**
  String get extensionPermissionNavigationDesc;

  /// Permission label for UI interaction
  ///
  /// In en, this message translates to:
  /// **'UI Interaction'**
  String get extensionPermissionUIInteraction;

  /// Permission description for UI interaction
  ///
  /// In en, this message translates to:
  /// **'Allows the extension to show dialogs, snackbars, or custom UI elements.'**
  String get extensionPermissionUIInteractionDesc;

  /// Label for data reading category
  ///
  /// In en, this message translates to:
  /// **'Data Reading'**
  String get extensionCategoryDataReading;

  /// Label for data writing category
  ///
  /// In en, this message translates to:
  /// **'Data Writing'**
  String get extensionCategoryDataWriting;

  /// Label for file system category
  ///
  /// In en, this message translates to:
  /// **'File System'**
  String get extensionCategoryFileSystem;

  /// Label for network access category
  ///
  /// In en, this message translates to:
  /// **'Network Access'**
  String get extensionCategoryNetwork;

  /// Label for system info category
  ///
  /// In en, this message translates to:
  /// **'System Info'**
  String get extensionCategorySystemInfo;

  /// Label for navigation category
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get extensionCategoryNavigation;

  /// Label for UI interaction category
  ///
  /// In en, this message translates to:
  /// **'UI Interaction'**
  String get extensionCategoryUIInteraction;

  /// Label for general extension category
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get extensionCategoryGeneral;

  /// Title for extension management page
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get extensionManagementTitle;

  /// Header for installed extensions section
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get extensionSectionInstalled;

  /// Header for built-in extensions section
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get extensionSectionBuiltIn;

  /// Header for online extension store section
  ///
  /// In en, this message translates to:
  /// **'GITHUB_ESSENMELIA_EXTEND'**
  String get extensionSectionOnline;

  /// Label indicating an update is available for an extension
  ///
  /// In en, this message translates to:
  /// **'New version available: {version}'**
  String updateAvailable(String version);

  /// Label for restricted access mode
  ///
  /// In en, this message translates to:
  /// **'Restricted Access'**
  String get extensionRestrictedAccess;

  /// Description for restricted access mode
  ///
  /// In en, this message translates to:
  /// **'Requires manual approval for all data access.'**
  String get extensionRestrictedAccessDesc;

  /// Description for sandbox group configuration
  ///
  /// In en, this message translates to:
  /// **'Extensions in the same group share mock data. Leave empty for default isolation.'**
  String get extensionSandboxGroupDesc;

  /// Title for edit sandbox group dialog
  ///
  /// In en, this message translates to:
  /// **'Edit Sandbox Group'**
  String get editSandboxGroup;

  /// Hint for sandbox group name input
  ///
  /// In en, this message translates to:
  /// **'Enter sandbox group name'**
  String get enterSandboxGroupName;

  /// Example for sandbox group name
  ///
  /// In en, this message translates to:
  /// **'e.g., my_shared_group'**
  String get sandboxGroupHint;

  /// Title for access interception dialog
  ///
  /// In en, this message translates to:
  /// **'Access Intercepted'**
  String get extensionInterceptedTitle;

  /// Description for access interception
  ///
  /// In en, this message translates to:
  /// **'Extension {name} {action}:'**
  String extensionInterceptedDesc(String name, String action);

  /// Label for tried action in interception
  ///
  /// In en, this message translates to:
  /// **'just tried to'**
  String get extensionInterceptedActionTried;

  /// Label for wanted action in interception
  ///
  /// In en, this message translates to:
  /// **'wants to'**
  String get extensionInterceptedActionWants;

  /// Button label to deny access
  ///
  /// In en, this message translates to:
  /// **'Deny Access'**
  String get extensionDecisionDeny;

  /// Description for denying access
  ///
  /// In en, this message translates to:
  /// **'Provides no data, which may cause errors or limited functionality.'**
  String get extensionDecisionDenyDesc;

  /// Button label to allow access once
  ///
  /// In en, this message translates to:
  /// **'Allow Once'**
  String get extensionDecisionOnce;

  /// Description for allowing access once
  ///
  /// In en, this message translates to:
  /// **'Provides real data only for this specific request.'**
  String get extensionDecisionOnceDesc;

  /// Button label to allow access next time
  ///
  /// In en, this message translates to:
  /// **'Allow Next Time'**
  String get extensionDecisionNext;

  /// Description for allowing access next time
  ///
  /// In en, this message translates to:
  /// **'Intercepts now, but automatically allows the next time this access occurs.'**
  String get extensionDecisionNextDesc;

  /// Button label to allow category access for session
  ///
  /// In en, this message translates to:
  /// **'Allow Category (Session)'**
  String get extensionDecisionSessionCategory;

  /// Description for allowing category access for session
  ///
  /// In en, this message translates to:
  /// **'Allows all access to this category until the app is closed.'**
  String get extensionDecisionSessionCategoryDesc;

  /// Button label to allow all access for session
  ///
  /// In en, this message translates to:
  /// **'Allow All (Session)'**
  String get extensionDecisionSessionAll;

  /// Description for allowing all access for session
  ///
  /// In en, this message translates to:
  /// **'Allows all permissions for this extension until the app is closed.'**
  String get extensionDecisionSessionAllDesc;

  /// Label for archive section
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// Label for sets section
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// Hint text for adding to archive
  ///
  /// In en, this message translates to:
  /// **'Add to archive...'**
  String get addToArchivePlaceholder;

  /// Title for extension logs screen
  ///
  /// In en, this message translates to:
  /// **'Extension Logs'**
  String get extensionLogsTitle;

  /// Message shown when there are no API logs
  ///
  /// In en, this message translates to:
  /// **'No API call records'**
  String get noApiLogs;

  /// Label for no parameters in logs
  ///
  /// In en, this message translates to:
  /// **'No parameters'**
  String get noParams;

  /// Label for restricted access mode
  ///
  /// In en, this message translates to:
  /// **'Restricted Access'**
  String get restrictedAccess;

  /// Title for log details dialog
  ///
  /// In en, this message translates to:
  /// **'Call Details'**
  String get logDetails;

  /// Label for extension name in logs
  ///
  /// In en, this message translates to:
  /// **'Extension Name'**
  String get extensionNameLabel;

  /// Label for extension ID in logs
  ///
  /// In en, this message translates to:
  /// **'Extension ID'**
  String get extensionIdLabel;

  /// Label for API method in logs
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get methodLabel;

  /// Label for call time in logs
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeLabel;

  /// Label for call status in logs
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// Label for success status
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get successLabel;

  /// Label for failed status
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedLabel;

  /// Label for access mode in logs
  ///
  /// In en, this message translates to:
  /// **'Access Mode'**
  String get accessModeLabel;

  /// Description for intercepted restricted access
  ///
  /// In en, this message translates to:
  /// **'Restricted Access (Intercepted)'**
  String get restrictedAccessIntercepted;

  /// Description for trusted mode passthrough
  ///
  /// In en, this message translates to:
  /// **'Trusted Mode (Passthrough)'**
  String get trustedModePassthrough;

  /// Label for error message in logs
  ///
  /// In en, this message translates to:
  /// **'Error Message'**
  String get errorMessageLabel;

  /// Title for parameter details section
  ///
  /// In en, this message translates to:
  /// **'Parameter Details'**
  String get paramsDetails;

  /// Label for saving steps as a template set
  ///
  /// In en, this message translates to:
  /// **'Save current steps as Template Set'**
  String get saveCurrentStepsAsSet;

  /// Button label to add all items to steps
  ///
  /// In en, this message translates to:
  /// **'Add All to Steps'**
  String get addAllToSteps;

  /// Label showing number of steps added
  ///
  /// In en, this message translates to:
  /// **'{count} steps added'**
  String addedStepsCount(int count);

  /// Label showing total number of steps
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String stepsCount(int count);

  /// Hint text for database name input
  ///
  /// In en, this message translates to:
  /// **'e.g., project-x, archive-2023'**
  String get dbNameHint;

  /// Error message for invalid database name
  ///
  /// In en, this message translates to:
  /// **'Invalid name. Use letters, numbers, -, _'**
  String get invalidDbName;

  /// Label for the default database
  ///
  /// In en, this message translates to:
  /// **'Main Archive (Default)'**
  String get defaultDbName;

  /// Label for the currently active item
  ///
  /// In en, this message translates to:
  /// **'Currently Active'**
  String get currentlyActive;

  /// Label for inactive items
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// Button label to switch database
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchDb;

  /// Snackbar message after switching database
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String switchedToDb(String name);

  /// Title for delete database confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteDbTitle(String name);

  /// Warning message for deleting a database
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All data in this database will be lost.'**
  String get deleteDbWarning;

  /// Label for saving a template set
  ///
  /// In en, this message translates to:
  /// **'Save Template Set'**
  String get saveTemplateSet;

  /// Label for template name input
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get templateName;

  /// Snackbar message after saving a template set
  ///
  /// In en, this message translates to:
  /// **'Template Set Saved'**
  String get templateSetSaved;

  /// Message shown when no events match criteria
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFound;

  /// Label for sorting options
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// Title for welcome screen
  ///
  /// In en, this message translates to:
  /// **'Welcome to Essenmelia'**
  String get welcomeTitle;

  /// Message for welcome screen
  ///
  /// In en, this message translates to:
  /// **'Manage your events, track steps, and organize your life with tags. Tap the + button to get started.'**
  String get welcomeMessage;

  /// Label showing number of selected items
  ///
  /// In en, this message translates to:
  /// **'{count} items selected'**
  String selectedItemsCount(int count);

  /// Button label for batch archiving
  ///
  /// In en, this message translates to:
  /// **'Batch Archive'**
  String get batchArchive;

  /// Button label for batch adding
  ///
  /// In en, this message translates to:
  /// **'Batch Add'**
  String get batchAdd;

  /// Button label for saving items as a set
  ///
  /// In en, this message translates to:
  /// **'Save as Set'**
  String get saveAsSet;

  /// Snackbar message after batch archiving
  ///
  /// In en, this message translates to:
  /// **'Moved {count} items to archive'**
  String movedToArchive(int count);

  /// Message shown when no steps are in archive
  ///
  /// In en, this message translates to:
  /// **'No archived steps'**
  String get noArchiveSteps;

  /// Message shown when no step sets exist
  ///
  /// In en, this message translates to:
  /// **'No step sets'**
  String get noStepSets;

  /// Hint text for saving steps as a set
  ///
  /// In en, this message translates to:
  /// **'You can save current steps as a set for quick reuse later'**
  String get saveCurrentAsSetHint;

  /// Label for set name input
  ///
  /// In en, this message translates to:
  /// **'Set Name'**
  String get setName;

  /// Snackbar message after saving a set
  ///
  /// In en, this message translates to:
  /// **'Set saved'**
  String get setSaved;

  /// Label for tags section
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// Message shown when no events have the selected tag
  ///
  /// In en, this message translates to:
  /// **'No events with this tag'**
  String get noEventsWithTag;

  /// Label for showing all events
  ///
  /// In en, this message translates to:
  /// **'All Events'**
  String get allEvents;

  /// Hint text for tag search/creation
  ///
  /// In en, this message translates to:
  /// **'Type to search or create...'**
  String get tagsPlaceholder;

  /// Label for creating a new tag
  ///
  /// In en, this message translates to:
  /// **'Create \"{tag}\"'**
  String createTag(String tag);

  /// Error message when image picking fails
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String failedToPickImage(String error);

  /// Validation error when title is empty
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// Generic error message with details
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error(String error);

  /// Title for delete all data confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete All Data?'**
  String get deleteAllDataTitle;

  /// Warning message for deleting all data
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteAllDataMessage;

  /// Snackbar message after deleting all data
  ///
  /// In en, this message translates to:
  /// **'All data deleted'**
  String get deleteAllDataSuccess;

  /// Error message when import fails
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailedDetailed(String error);

  /// Error message when export fails
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailedDetailed(String error);

  /// Navigation label for events
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// Navigation label for extensions
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get navExtensions;

  /// Button label to add an extension
  ///
  /// In en, this message translates to:
  /// **'Add Extension'**
  String get addExtension;

  /// Label for importing extension from local file
  ///
  /// In en, this message translates to:
  /// **'Import from local file'**
  String get importFromLocalFile;

  /// Hint text for selecting extension package
  ///
  /// In en, this message translates to:
  /// **'Select .zip extension package'**
  String get selectJsonExtension;

  /// Hint text for extension URL input
  ///
  /// In en, this message translates to:
  /// **'Enter URL or GitHub link'**
  String get enterUrlOrGithubLink;

  /// Button label to install extension from link
  ///
  /// In en, this message translates to:
  /// **'Download and install from link'**
  String get downloadAndInstallFromLink;

  /// Title for confirm uninstall dialog
  ///
  /// In en, this message translates to:
  /// **'Confirm Uninstall'**
  String get confirmUninstall;

  /// Warning message for extension uninstallation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to uninstall extension \"{name}\"? All related settings will be cleared.'**
  String uninstallExtensionWarning(String name);

  /// Label for uninstall button
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstall;

  /// Snackbar message after extension uninstalled
  ///
  /// In en, this message translates to:
  /// **'Extension \"{name}\" uninstalled'**
  String extensionUninstalled(String name);

  /// Title for extension repository page
  ///
  /// In en, this message translates to:
  /// **'Extension Repository'**
  String get extensionRepository;

  /// Label for browsing extensions on GitHub
  ///
  /// In en, this message translates to:
  /// **'Browse and install from GitHub'**
  String get browseAndInstallFromGithub;

  /// Message shown when no extensions are installed
  ///
  /// In en, this message translates to:
  /// **'No extensions installed'**
  String get noExtensionsInstalled;

  /// Label for deactivated extensions
  ///
  /// In en, this message translates to:
  /// **'Deactivated'**
  String get deactivated;

  /// Error message when extension download fails
  ///
  /// In en, this message translates to:
  /// **'Download failed, please check the link'**
  String get downloadFailedCheckLink;

  /// Label for extension management and permissions
  ///
  /// In en, this message translates to:
  /// **'Manage & Permissions'**
  String get manageAndPermissions;

  /// Label for exporting extension package
  ///
  /// In en, this message translates to:
  /// **'Export Extension Package'**
  String get exportExtensionPackage;

  /// Label for expanding tags section
  ///
  /// In en, this message translates to:
  /// **'Expand Tags'**
  String get expandTags;

  /// Message shown when no event is selected
  ///
  /// In en, this message translates to:
  /// **'No event selected'**
  String get noEventSelected;

  /// Message shown when no events match filters
  ///
  /// In en, this message translates to:
  /// **'No matching events found'**
  String get noMatchingEvents;

  /// Message shown when there are no events in the database
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get noEventsYet;

  /// Instruction to create the first event
  ///
  /// In en, this message translates to:
  /// **'Click the + button to create your first event'**
  String get createFirstEvent;

  /// Suggestion when no matching events are found
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or search query'**
  String get tryAdjustingFilters;

  /// Label for batch editing tags
  ///
  /// In en, this message translates to:
  /// **'Batch Edit Tags'**
  String get batchEditTags;

  /// Title for batch tag editing dialog
  ///
  /// In en, this message translates to:
  /// **'Edit Tags for {count} items'**
  String batchEditTagsTitle(int count);

  /// Label for adding tags
  ///
  /// In en, this message translates to:
  /// **'Add Tags'**
  String get addTags;

  /// Label for removing tags
  ///
  /// In en, this message translates to:
  /// **'Remove Tags'**
  String get removeTags;

  /// Snackbar message after batch tag update
  ///
  /// In en, this message translates to:
  /// **'Tags updated for {count} items'**
  String tagsUpdated(int count);

  /// Message shown when no tags are selected in batch edit
  ///
  /// In en, this message translates to:
  /// **'No tags selected'**
  String get noTagsSelected;

  /// Button label to apply changes
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Label for help section
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// Label for welcome section
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Title for welcome and help page
  ///
  /// In en, this message translates to:
  /// **'Welcome & Help'**
  String get welcomeAndHelp;

  /// Title for help center
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpTitle;

  /// Description for help center
  ///
  /// In en, this message translates to:
  /// **'Learn how to use Essenmelia here. Manage your events, steps, and extensions.'**
  String get helpMessage;

  /// Button label to go back to welcome screen
  ///
  /// In en, this message translates to:
  /// **'Back to Welcome'**
  String get backToWelcome;

  /// Button label to switch to help view
  ///
  /// In en, this message translates to:
  /// **'View Help'**
  String get switchToHelp;

  /// Button label to get started
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// Label for font settings
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get font;

  /// Label for system font option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemFont;

  /// Label for google fonts option
  ///
  /// In en, this message translates to:
  /// **'Google Fonts (Roboto)'**
  String get builtInFont;

  /// Title for font download confirmation
  ///
  /// In en, this message translates to:
  /// **'Download Font?'**
  String get fontDownloadTitle;

  /// Content for font download confirmation
  ///
  /// In en, this message translates to:
  /// **'This will use Google Fonts which requires an internet connection to download font assets. Continue?'**
  String get fontDownloadContent;

  /// Label for last sync time
  ///
  /// In en, this message translates to:
  /// **'Last Sync: {time}'**
  String lastSync(String time);

  /// Label for data maintenance section
  ///
  /// In en, this message translates to:
  /// **'Data Maintenance'**
  String get dataMaintenance;

  /// Label for danger zone section
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// Label for formatting application (clearing all data)
  ///
  /// In en, this message translates to:
  /// **'Format Application'**
  String get formatApp;

  /// Warning message for formatting the application
  ///
  /// In en, this message translates to:
  /// **'This will physically delete all databases, clear all extension sandboxes, and reset all app settings. This action is IRREVERSIBLE!'**
  String get formatAppWarning;

  /// Instruction for confirmation word
  ///
  /// In en, this message translates to:
  /// **'TYPE \'DELETE\' TO CONFIRM'**
  String get formatAppConfirm;

  /// Hint text for confirmation word input
  ///
  /// In en, this message translates to:
  /// **'Type DELETE here'**
  String get formatAppPlaceholder;

  /// Label for current database actions section
  ///
  /// In en, this message translates to:
  /// **'Current Database Actions'**
  String get currentDbActions;

  /// Label for granting all system permissions to an extension
  ///
  /// In en, this message translates to:
  /// **'All System Permissions'**
  String get extensionAllSystemPermissions;

  /// Button label to confirm permission choice
  ///
  /// In en, this message translates to:
  /// **'Confirm Choice'**
  String get extensionConfirmChoice;

  /// Label for extension runtime and security section
  ///
  /// In en, this message translates to:
  /// **'Runtime & Security'**
  String get extensionRuntimeSection;

  /// Label for enabling an extension
  ///
  /// In en, this message translates to:
  /// **'Enable Extension'**
  String get extensionEnable;

  /// Status label for a running extension
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get extensionRunning;

  /// Status label for a stopped extension
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get extensionStopped;

  /// Label for extension sandbox isolation settings
  ///
  /// In en, this message translates to:
  /// **'Sandbox Isolation'**
  String get extensionSandboxIsolation;

  /// Label for isolated sandbox mode
  ///
  /// In en, this message translates to:
  /// **'Isolated Sandbox'**
  String get extensionIsolatedSandbox;

  /// Label for shared sandbox mode
  ///
  /// In en, this message translates to:
  /// **'Shared Sandbox: {id}'**
  String extensionSharedSandbox(String id);

  /// Label for extension sandbox group
  ///
  /// In en, this message translates to:
  /// **'Sandbox Group'**
  String get extensionSandboxGroup;

  /// Description for extension sandbox groups
  ///
  /// In en, this message translates to:
  /// **'Sandbox groups determine data isolation. Enter the same ID to share storage.'**
  String get extensionSandboxDesc;

  /// Label for sandbox ID input
  ///
  /// In en, this message translates to:
  /// **'Sandbox ID'**
  String get extensionSandboxId;

  /// Hint text for default sandbox ID
  ///
  /// In en, this message translates to:
  /// **'Default to Extension ID'**
  String get extensionSandboxDefaultHint;

  /// Tip for extension sandbox groups
  ///
  /// In en, this message translates to:
  /// **'Tip: Active extensions usually share the same group'**
  String get extensionSandboxTip;

  /// Label for requested permissions section
  ///
  /// In en, this message translates to:
  /// **'Requested Permissions'**
  String get extensionRequestedPermissions;

  /// Message shown when no permissions are requested
  ///
  /// In en, this message translates to:
  /// **'No permissions requested'**
  String get extensionNoPermissions;

  /// Button label to update an extension
  ///
  /// In en, this message translates to:
  /// **'Update Extension'**
  String get extensionUpdate;

  /// Button label to install an extension
  ///
  /// In en, this message translates to:
  /// **'Install Extension'**
  String get extensionInstall;

  /// Label for extension information section
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get extensionInformation;

  /// Label for extension version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get extensionVersion;

  /// Label for extension not installed status
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get extensionNotInstalled;

  /// Label for extension code size
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get extensionCodeSize;

  /// Label for extension storage size
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get extensionStorageSize;

  /// Label for full trust mode
  ///
  /// In en, this message translates to:
  /// **'Full Trust'**
  String get extensionFullTrust;

  /// Description for full trust mode
  ///
  /// In en, this message translates to:
  /// **'Direct access to system APIs'**
  String get extensionFullTrustDesc;

  /// Label for extension permissions statement
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get extensionPermissionsStatement;

  /// Message shown when no changes are detected
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get extensionNoChanges;

  /// Message shown when no permissions are required
  ///
  /// In en, this message translates to:
  /// **'No permissions required'**
  String get extensionNoPermissionsRequired;

  /// Generic update button label
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Generic install button label
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get install;

  /// Error message for database operations
  ///
  /// In en, this message translates to:
  /// **'Database Error: {error}'**
  String databaseError(String error);

  /// Generic filter label
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Generic status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// Label for requested extensions
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get extensionRequested;

  /// Label for showing only events with reminders
  ///
  /// In en, this message translates to:
  /// **'Only Show Reminders'**
  String get onlyShowReminders;

  /// Subtitle for showing only events with reminders
  ///
  /// In en, this message translates to:
  /// **'Filter out tasks without reminders'**
  String get onlyShowRemindersSubtitle;

  /// Label for viewing all items
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// Tooltip for extension logs button
  ///
  /// In en, this message translates to:
  /// **'Extension Logs'**
  String get extensionLogs;

  /// Title for extension system guide
  ///
  /// In en, this message translates to:
  /// **'Welcome to Extensions'**
  String get welcomeToExtensions;

  /// Tooltip for dismissing guide
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get dontShowAgain;

  /// Instruction for extension management
  ///
  /// In en, this message translates to:
  /// **'Long press to manage extension'**
  String get longPressToManageExtension;

  /// Recurrence option: Daily
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// Recurrence option: Weekly
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// Recurrence option: Monthly
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// Label for daily recurrence
  ///
  /// In en, this message translates to:
  /// **' (Daily)'**
  String get recurrenceDaily;

  /// Label for weekly recurrence
  ///
  /// In en, this message translates to:
  /// **' (Weekly)'**
  String get recurrenceWeekly;

  /// Label for monthly recurrence
  ///
  /// In en, this message translates to:
  /// **' (Monthly)'**
  String get recurrenceMonthly;

  /// Title for welcome screen exploration
  ///
  /// In en, this message translates to:
  /// **'Explore Essenmelia'**
  String get exploreEssenmelia;

  /// Title for help and documentation
  ///
  /// In en, this message translates to:
  /// **'Help & Docs'**
  String get helpAndDocs;

  /// Subtitle for the first welcome slide
  ///
  /// In en, this message translates to:
  /// **'Your personal schedule & inspiration manager'**
  String get welcomeSubtitle1;

  /// Content for the first welcome slide
  ///
  /// In en, this message translates to:
  /// **'Efficiently organize every brilliant moment in your life. Whether it\'s trivial daily tasks or grand plans, they all find a home here.'**
  String get welcomeContent1;

  /// Title for privacy slide
  ///
  /// In en, this message translates to:
  /// **'Privacy First'**
  String get privacyFirst;

  /// Subtitle for privacy slide
  ///
  /// In en, this message translates to:
  /// **'Secure, Transparent, Controllable'**
  String get welcomeSubtitle2;

  /// Content for privacy slide
  ///
  /// In en, this message translates to:
  /// **'All data is stored locally. Untrusted plugins can only access forged data generated by the system, ensuring your real information never leaks.'**
  String get welcomeContent2;

  /// Title for customization slide
  ///
  /// In en, this message translates to:
  /// **'Highly Customizable'**
  String get highlyCustomizable;

  /// Subtitle for customization slide
  ///
  /// In en, this message translates to:
  /// **'Follow your heart, infinite possibilities'**
  String get welcomeSubtitle3;

  /// Content for customization slide
  ///
  /// In en, this message translates to:
  /// **'With a powerful plugin system, you can easily extend app functionality. Use the declarative UI engine to customize your own exclusive management tool.'**
  String get welcomeContent3;

  /// Button label to end welcome tour
  ///
  /// In en, this message translates to:
  /// **'Start Experience'**
  String get startExperience;

  /// Button label for next step in tour
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get nextStep;

  /// Title for architecture design doc
  ///
  /// In en, this message translates to:
  /// **'Architecture Design'**
  String get archDesign;

  /// Description for architecture design doc
  ///
  /// In en, this message translates to:
  /// **'System layering, privacy black box & permission model'**
  String get archDesignDesc;

  /// Title for API guide doc
  ///
  /// In en, this message translates to:
  /// **'API Usage Guide'**
  String get apiGuide;

  /// Description for API guide doc
  ///
  /// In en, this message translates to:
  /// **'Core methods, notification schemes & external integration'**
  String get apiGuideDesc;

  /// Title for extension development doc
  ///
  /// In en, this message translates to:
  /// **'Extension Development Specs'**
  String get extDevSpecs;

  /// Description for extension development doc
  ///
  /// In en, this message translates to:
  /// **'Metadata, UI component library & logic engine'**
  String get extDevSpecsDesc;

  /// Title for extension repository creation guide doc
  ///
  /// In en, this message translates to:
  /// **'Extension Repository Guide'**
  String get createRepoGuide;

  /// Description for extension repository creation guide doc
  ///
  /// In en, this message translates to:
  /// **'Manifest, structure & GitHub discovery'**
  String get createRepoGuideDesc;

  /// Placeholder when no doc is selected
  ///
  /// In en, this message translates to:
  /// **'Please select a document to read'**
  String get selectDocToRead;

  /// Error message when content fails to load
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String loadFailed(String error);

  /// Title for advanced settings section
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings & Reminders'**
  String get advancedSettingsAndReminders;

  /// Subtitle for advanced settings section
  ///
  /// In en, this message translates to:
  /// **'Display mode, count suffix, scheduled reminders'**
  String get advancedSettingsSubtitle;

  /// Label for advanced settings
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get advancedSettings;

  /// Button label to finish settings
  ///
  /// In en, this message translates to:
  /// **'Finish Settings'**
  String get finishSettings;

  /// Title for display settings
  ///
  /// In en, this message translates to:
  /// **'Display Settings'**
  String get displaySettings;

  /// Label for step marker mode setting
  ///
  /// In en, this message translates to:
  /// **'Step Marker Display Mode'**
  String get stepMarkerMode;

  /// Option for numeric step markers
  ///
  /// In en, this message translates to:
  /// **'Number (1, 2, 3)'**
  String get markerNumber;

  /// Option for first character step markers
  ///
  /// In en, this message translates to:
  /// **'First Char (A, B, C)'**
  String get markerFirstChar;

  /// Label for custom count suffix setting
  ///
  /// In en, this message translates to:
  /// **'Custom Count Suffix'**
  String get customCountSuffix;

  /// Hint text for count suffix input
  ///
  /// In en, this message translates to:
  /// **'e.g., tasks, steps, items'**
  String get suffixHint;

  /// Tip for count suffix setting
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use default suffix'**
  String get suffixDefaultTip;

  /// Title for scheduled reminders section
  ///
  /// In en, this message translates to:
  /// **'Scheduled Reminders'**
  String get scheduledReminders;

  /// Label when no reminder is configured
  ///
  /// In en, this message translates to:
  /// **'No reminder set'**
  String get noReminderSet;

  /// Description for system calendar reminder
  ///
  /// In en, this message translates to:
  /// **'Will register to system calendar, no background running required'**
  String get calendarReminderDesc;

  /// Description for in-app notification reminder
  ///
  /// In en, this message translates to:
  /// **'Will send notification at specified time to remind you'**
  String get notificationReminderDesc;

  /// Label for reminder scheme setting
  ///
  /// In en, this message translates to:
  /// **'Reminder Scheme'**
  String get reminderScheme;

  /// Option for in-app notification
  ///
  /// In en, this message translates to:
  /// **'In-app Notification'**
  String get inAppNotification;

  /// Option for system calendar reminder
  ///
  /// In en, this message translates to:
  /// **'System Calendar'**
  String get systemCalendar;

  /// Label for repeat cycle setting
  ///
  /// In en, this message translates to:
  /// **'Repeat Cycle'**
  String get repeatCycle;

  /// Option for no repetition
  ///
  /// In en, this message translates to:
  /// **'No Repeat'**
  String get noRepeat;

  /// Error message for invalid reminder time
  ///
  /// In en, this message translates to:
  /// **'Reminder time cannot be earlier than current time'**
  String get reminderTimeError;

  /// Title for smart image analysis dialog
  ///
  /// In en, this message translates to:
  /// **'Smart Analysis Selection'**
  String get smartAnalysis;

  /// Section header for AI-cropped images
  ///
  /// In en, this message translates to:
  /// **'Brilliant Moments'**
  String get brilliantMoments;

  /// Label for AI cropping feature
  ///
  /// In en, this message translates to:
  /// **'AI Crop'**
  String get aiCrop;

  /// Section header for OCR text results
  ///
  /// In en, this message translates to:
  /// **'OCR Results'**
  String get ocrResults;

  /// Instruction for selecting OCR text
  ///
  /// In en, this message translates to:
  /// **'Tap to select: 1st tap for title, subsequent taps append to description'**
  String get ocrSelectionTip;

  /// Button label to reset OCR selection
  ///
  /// In en, this message translates to:
  /// **'Reset Text Selection'**
  String get resetOcrSelection;

  /// Section header for application preview
  ///
  /// In en, this message translates to:
  /// **'App Preview'**
  String get appPreview;

  /// Button label to confirm and apply AI results
  ///
  /// In en, this message translates to:
  /// **'Confirm Apply'**
  String get confirmApply;

  /// Loading message during image analysis
  ///
  /// In en, this message translates to:
  /// **'Analyzing content...'**
  String get analyzingContent;

  /// Tooltip for smart analysis button
  ///
  /// In en, this message translates to:
  /// **'Smartly analyze content'**
  String get smartAnalysisTooltip;

  /// Message indicating AI auto-fill
  ///
  /// In en, this message translates to:
  /// **'Auto-filled by AI Assistant'**
  String get autoFilledByAi;

  /// Error message for invalid file types
  ///
  /// In en, this message translates to:
  /// **'Unsupported file format'**
  String get unsupportedFileFormat;

  /// Error message for empty or invalid clipboard
  ///
  /// In en, this message translates to:
  /// **'No image or valid link found in clipboard'**
  String get noImageInClipboard;

  /// Error message when link download fails
  ///
  /// In en, this message translates to:
  /// **'Failed to get image from link: {error}'**
  String failedToGetImageFromLink(String error);

  /// Option to pick image from gallery
  ///
  /// In en, this message translates to:
  /// **'Pick from Gallery'**
  String get pickFromGallery;

  /// Option to paste image from clipboard
  ///
  /// In en, this message translates to:
  /// **'Paste from Clipboard'**
  String get pasteFromClipboard;

  /// Option to remove the selected image
  ///
  /// In en, this message translates to:
  /// **'Clear Image'**
  String get clearImage;

  /// Placeholder for image selection area
  ///
  /// In en, this message translates to:
  /// **'Add an image with a story'**
  String get addStoryImage;

  /// Instruction for uploading an image
  ///
  /// In en, this message translates to:
  /// **'Drag & drop, paste, or select an image'**
  String get imageUploadTip;

  /// Tooltip for exporting original image
  ///
  /// In en, this message translates to:
  /// **'Export Original Image'**
  String get exportOriginalImage;

  /// Label for image export action
  ///
  /// In en, this message translates to:
  /// **'Export Image'**
  String get exportImage;

  /// Error message when image analysis fails
  ///
  /// In en, this message translates to:
  /// **'Processing image failed: {error}'**
  String processingImageFailed(String error);

  /// Label showing reminder time
  ///
  /// In en, this message translates to:
  /// **'Reminder: {time}'**
  String reminderAt(String time);

  /// Label for quick edit feature
  ///
  /// In en, this message translates to:
  /// **'Quick Edit (Long press to slide)'**
  String get quickEdit;

  /// Title for the extension debug console
  ///
  /// In en, this message translates to:
  /// **'Extension Console'**
  String get extensionConsole;

  /// Label for logs tab
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// Label for state tree tab
  ///
  /// In en, this message translates to:
  /// **'State Tree'**
  String get stateTree;

  /// Tooltip for restarting the JS engine
  ///
  /// In en, this message translates to:
  /// **'Restart Engine'**
  String get restartEngine;

  /// Message shown when there are no logs
  ///
  /// In en, this message translates to:
  /// **'No logs'**
  String get noLogs;

  /// Header for state variables list
  ///
  /// In en, this message translates to:
  /// **'Current State Variables (State):'**
  String get currentStateVariables;

  /// Title for state editing dialog
  ///
  /// In en, this message translates to:
  /// **'Edit State: {key}'**
  String editState(String key);

  /// Label for JSON input field
  ///
  /// In en, this message translates to:
  /// **'JSON Format Value'**
  String get jsonFormatValue;

  /// Hint for JSON input field
  ///
  /// In en, this message translates to:
  /// **'e.g., \"text\" or 123 or JSON object'**
  String get jsonHint;

  /// Error message for invalid JSON input
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON: {error}'**
  String invalidJson(String error);

  /// Label for the full original image in picker
  ///
  /// In en, this message translates to:
  /// **'Full Original Image'**
  String get fullOriginalImage;

  /// Title for the dialog showing all system permissions
  ///
  /// In en, this message translates to:
  /// **'All System Permissions'**
  String get allSystemPermissions;

  /// Error message when an extension fails to run
  ///
  /// In en, this message translates to:
  /// **'Extension runtime error'**
  String get extensionError;

  /// Message shown when an extension lacks a view definition
  ///
  /// In en, this message translates to:
  /// **'This extension has no UI interface'**
  String get extensionNoUI;

  /// Default label for a button in dynamic UI
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get extensionButton;

  /// Name for network connection test
  ///
  /// In en, this message translates to:
  /// **'Network Connection'**
  String get healthCheckNetworkName;

  /// Description for network connection test
  ///
  /// In en, this message translates to:
  /// **'Test Internet Access (DNS)'**
  String get healthCheckNetworkDesc;

  /// Name for database integrity test
  ///
  /// In en, this message translates to:
  /// **'Database Integrity'**
  String get healthCheckDbName;

  /// Description for database integrity test
  ///
  /// In en, this message translates to:
  /// **'Verify local storage R/W'**
  String get healthCheckDbDesc;

  /// Name for extension system test
  ///
  /// In en, this message translates to:
  /// **'Extension System'**
  String get healthCheckExtensionName;

  /// Description for extension system test
  ///
  /// In en, this message translates to:
  /// **'Check Extension Manager Status'**
  String get healthCheckExtensionDesc;

  /// Name for system permissions test
  ///
  /// In en, this message translates to:
  /// **'System Permissions'**
  String get healthCheckPermissionsName;

  /// Description for system permissions test
  ///
  /// In en, this message translates to:
  /// **'Check Calendar/Notification'**
  String get healthCheckPermissionsDesc;

  /// Success message for Baidu DNS
  ///
  /// In en, this message translates to:
  /// **'Connected (Baidu DNS)'**
  String get healthCheckNetworkSuccessBaidu;

  /// Success message for Bing DNS
  ///
  /// In en, this message translates to:
  /// **'Connected (Bing DNS)'**
  String get healthCheckNetworkSuccessBing;

  /// Error message for DNS failure
  ///
  /// In en, this message translates to:
  /// **'DNS Resolution Failed: {error}'**
  String healthCheckNetworkFailed(String error);

  /// Success message for database R/W
  ///
  /// In en, this message translates to:
  /// **'R/W OK'**
  String get healthCheckDbSuccess;

  /// Error message for database verification failure
  ///
  /// In en, this message translates to:
  /// **'R/W Verification Failed'**
  String get healthCheckDbVerifyFailed;

  /// Error message for Hive error
  ///
  /// In en, this message translates to:
  /// **'Hive Error: {error}'**
  String healthCheckDbHiveError(String error);

  /// Generic exception message
  ///
  /// In en, this message translates to:
  /// **'Exception: {error}'**
  String healthCheckException(String error);

  /// Success message for extension system
  ///
  /// In en, this message translates to:
  /// **'Service Running ({count} extensions)'**
  String healthCheckExtensionSuccess(int count);

  /// Error message for extension provider
  ///
  /// In en, this message translates to:
  /// **'Provider Exception: {error}'**
  String healthCheckExtensionError(String error);

  /// Success message for calendar permission
  ///
  /// In en, this message translates to:
  /// **'Calendar Permission OK'**
  String get healthCheckPermissionCalendarOk;

  /// Error message for missing calendar permission
  ///
  /// In en, this message translates to:
  /// **'Missing Calendar Permission'**
  String get healthCheckPermissionCalendarMissing;

  /// Error message for permission check failure
  ///
  /// In en, this message translates to:
  /// **'Check Failed: {error}'**
  String healthCheckPermissionError(String error);

  /// Name for System Info API test
  ///
  /// In en, this message translates to:
  /// **'API: System Info'**
  String get healthCheckApiSysInfoName;

  /// Description for System Info API test
  ///
  /// In en, this message translates to:
  /// **'Test getSystemInfo'**
  String get healthCheckApiSysInfoDesc;

  /// Success message for System Info API
  ///
  /// In en, this message translates to:
  /// **'Platform: {platform}'**
  String healthCheckApiSysInfoSuccess(String platform);

  /// Name for Database API test
  ///
  /// In en, this message translates to:
  /// **'API: Database'**
  String get healthCheckApiDbName;

  /// Description for Database API test
  ///
  /// In en, this message translates to:
  /// **'Test getDbSize'**
  String get healthCheckApiDbDesc;

  /// Success message for Database API
  ///
  /// In en, this message translates to:
  /// **'Size: {size}'**
  String healthCheckApiDbSuccess(String size);

  /// Name for Tags API test
  ///
  /// In en, this message translates to:
  /// **'API: Tags'**
  String get healthCheckApiTagsName;

  /// Description for Tags API test
  ///
  /// In en, this message translates to:
  /// **'Test getTags'**
  String get healthCheckApiTagsDesc;

  /// Success message for Tags API
  ///
  /// In en, this message translates to:
  /// **'Tags count: {count}'**
  String healthCheckApiTagsSuccess(int count);

  /// Name for Settings API test
  ///
  /// In en, this message translates to:
  /// **'API: Settings'**
  String get healthCheckApiSettingsName;

  /// Description for Settings API test
  ///
  /// In en, this message translates to:
  /// **'Test getSetting/saveSetting'**
  String get healthCheckApiSettingsDesc;

  /// Success message for Settings API
  ///
  /// In en, this message translates to:
  /// **'Read/Write OK'**
  String get healthCheckApiSettingsSuccess;

  /// Error message for Settings API mismatch
  ///
  /// In en, this message translates to:
  /// **'Read/Write mismatch'**
  String get healthCheckApiSettingsMismatch;

  /// Name for Network API test
  ///
  /// In en, this message translates to:
  /// **'API: Network'**
  String get healthCheckApiNetworkName;

  /// Description for Network API test
  ///
  /// In en, this message translates to:
  /// **'Test httpGet (via Extension)'**
  String get healthCheckApiNetworkDesc;

  /// Success message for Network API
  ///
  /// In en, this message translates to:
  /// **'Status: 200 OK'**
  String get healthCheckApiNetworkSuccess;

  /// Name for Events API test
  ///
  /// In en, this message translates to:
  /// **'API: Events'**
  String get healthCheckApiEventsName;

  /// Description for Events API test
  ///
  /// In en, this message translates to:
  /// **'Test getEvents'**
  String get healthCheckApiEventsDesc;

  /// Success message for Events API
  ///
  /// In en, this message translates to:
  /// **'Events count: {count}'**
  String healthCheckApiEventsSuccess(int count);

  /// Name for Store Repository test
  ///
  /// In en, this message translates to:
  /// **'Store: Repository'**
  String get healthCheckStoreRepoName;

  /// Description for Store Repository test
  ///
  /// In en, this message translates to:
  /// **'Test Extension Store Connection'**
  String get healthCheckStoreRepoDesc;

  /// Success message for Store Repository
  ///
  /// In en, this message translates to:
  /// **'Extensions: {count}'**
  String healthCheckStoreRepoSuccess(int count);

  /// Tooltip for running system diagnostic
  ///
  /// In en, this message translates to:
  /// **'Run System Diagnostic'**
  String get healthCheckRunTooltip;

  /// Title for system health diagnostic view
  ///
  /// In en, this message translates to:
  /// **'System Health Diagnostic'**
  String get healthCheckTitle;

  /// Tooltip for rerunning tests
  ///
  /// In en, this message translates to:
  /// **'Rerun'**
  String get healthCheckRerunTooltip;

  /// Label for test environment selection
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get healthCheckEnvironment;

  /// Label for sandbox mode
  ///
  /// In en, this message translates to:
  /// **'Sandbox Simulation'**
  String get healthCheckSandboxMode;

  /// Label for real environment
  ///
  /// In en, this message translates to:
  /// **'Real Environment'**
  String get healthCheckRealMode;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
