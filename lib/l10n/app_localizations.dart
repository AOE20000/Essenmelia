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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Essenmelia'**
  String get appTitle;

  /// No description provided for @searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search events...'**
  String get searchPlaceholder;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @newTag.
  ///
  /// In en, this message translates to:
  /// **'New Tag'**
  String get newTag;

  /// No description provided for @tagNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Work, Personal'**
  String get tagNameHint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @renameTag.
  ///
  /// In en, this message translates to:
  /// **'Rename Tag'**
  String get renameTag;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @manageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get manageTags;

  /// No description provided for @databaseManager.
  ///
  /// In en, this message translates to:
  /// **'Database Manager'**
  String get databaseManager;

  /// No description provided for @importExport.
  ///
  /// In en, this message translates to:
  /// **'Import / Export'**
  String get importExport;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @useSystemTheme.
  ///
  /// In en, this message translates to:
  /// **'Use System Theme'**
  String get useSystemTheme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @systemLanguage.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemLanguage;

  /// No description provided for @cardDensity.
  ///
  /// In en, this message translates to:
  /// **'Card Density'**
  String get cardDensity;

  /// No description provided for @compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compact;

  /// No description provided for @comfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortable;

  /// No description provided for @collapseImages.
  ///
  /// In en, this message translates to:
  /// **'Collapse Images'**
  String get collapseImages;

  /// No description provided for @activeDatabase.
  ///
  /// In en, this message translates to:
  /// **'Active Database'**
  String get activeDatabase;

  /// No description provided for @availableDatabases.
  ///
  /// In en, this message translates to:
  /// **'Available Databases'**
  String get availableDatabases;

  /// No description provided for @createNewDatabase.
  ///
  /// In en, this message translates to:
  /// **'Create New Database'**
  String get createNewDatabase;

  /// No description provided for @enterDatabaseName.
  ///
  /// In en, this message translates to:
  /// **'Enter database name'**
  String get enterDatabaseName;

  /// No description provided for @switchDbConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Switch Database'**
  String get switchDbConfirmation;

  /// No description provided for @switchDbMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to switch to database \"{name}\"?'**
  String switchDbMessage(String name);

  /// No description provided for @deleteDbConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete Database'**
  String get deleteDbConfirmation;

  /// No description provided for @deleteDbMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete database \"{name}\"? This action cannot be undone.'**
  String deleteDbMessage(String name);

  /// No description provided for @dbCreated.
  ///
  /// In en, this message translates to:
  /// **'Database created'**
  String get dbCreated;

  /// No description provided for @dbDeleted.
  ///
  /// In en, this message translates to:
  /// **'Database deleted'**
  String get dbDeleted;

  /// No description provided for @dbSwitched.
  ///
  /// In en, this message translates to:
  /// **'Switched to database: {name}'**
  String dbSwitched(String name);

  /// No description provided for @allTags.
  ///
  /// In en, this message translates to:
  /// **'All Tags'**
  String get allTags;

  /// No description provided for @noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags available'**
  String get noTags;

  /// No description provided for @createTag.
  ///
  /// In en, this message translates to:
  /// **'Create \"{tag}\"'**
  String createTag(String tag);

  /// No description provided for @tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get tagName;

  /// No description provided for @tagColor.
  ///
  /// In en, this message translates to:
  /// **'Tag Color'**
  String get tagColor;

  /// No description provided for @deleteTagMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete this tag? It will be removed from all events.'**
  String get deleteTagMessage;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export successful'**
  String get exportSuccess;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get importSuccess;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importError;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest First'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest First'**
  String get sortOldest;

  /// No description provided for @sortTitleAZ.
  ///
  /// In en, this message translates to:
  /// **'Title (A-Z)'**
  String get sortTitleAZ;

  /// No description provided for @sortTitleZA.
  ///
  /// In en, this message translates to:
  /// **'Title (Z-A)'**
  String get sortTitleZA;

  /// No description provided for @sortProgressHigh.
  ///
  /// In en, this message translates to:
  /// **'Progress (High-Low)'**
  String get sortProgressHigh;

  /// No description provided for @sortProgressLow.
  ///
  /// In en, this message translates to:
  /// **'Progress (Low-High)'**
  String get sortProgressLow;

  /// No description provided for @statusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusAll;

  /// No description provided for @statusNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not Started'**
  String get statusNotStarted;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selected;

  /// No description provided for @deleteSelectedConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected?'**
  String get deleteSelectedConfirmation;

  /// No description provided for @deleteSelectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete {count} items?'**
  String deleteSelectedMessage(int count);

  /// No description provided for @editEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get editEvent;

  /// No description provided for @newEvent.
  ///
  /// In en, this message translates to:
  /// **'New Event'**
  String get newEvent;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @imageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get imageUrl;

  /// No description provided for @imageUrlPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'http://... or data:image...'**
  String get imageUrlPlaceholder;

  /// No description provided for @pickImage.
  ///
  /// In en, this message translates to:
  /// **'Pick Image'**
  String get pickImage;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @createEvent.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get createEvent;

  /// No description provided for @noTagsYet.
  ///
  /// In en, this message translates to:
  /// **'No tags yet'**
  String get noTagsYet;

  /// No description provided for @tagsSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} tags selected'**
  String tagsSelected(int count);

  /// No description provided for @clearAllTags.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get clearAllTags;

  /// No description provided for @deleteTagConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete Tag?'**
  String get deleteTagConfirmation;

  /// No description provided for @deleteTagWarning.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{tag}\" from all events.'**
  String deleteTagWarning(String tag);

  /// No description provided for @eventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get eventNotFound;

  /// No description provided for @createdOn.
  ///
  /// In en, this message translates to:
  /// **'Created on {date}'**
  String createdOn(String date);

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get steps;

  /// No description provided for @manageSteps.
  ///
  /// In en, this message translates to:
  /// **'Manage Steps'**
  String get manageSteps;

  /// No description provided for @noStepsYet.
  ///
  /// In en, this message translates to:
  /// **'No steps yet.'**
  String get noStepsYet;

  /// No description provided for @addStep.
  ///
  /// In en, this message translates to:
  /// **'Add Step'**
  String get addStep;

  /// No description provided for @newStepPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'New step...'**
  String get newStepPlaceholder;

  /// No description provided for @editSteps.
  ///
  /// In en, this message translates to:
  /// **'Edit Steps'**
  String get editSteps;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'Sets'**
  String get sets;

  /// No description provided for @addNewStepPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add new step...'**
  String get addNewStepPlaceholder;

  /// No description provided for @addToArchivePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add to archive...'**
  String get addToArchivePlaceholder;

  /// No description provided for @addedToSteps.
  ///
  /// In en, this message translates to:
  /// **'Added to steps'**
  String get addedToSteps;

  /// No description provided for @saveCurrentStepsAsSet.
  ///
  /// In en, this message translates to:
  /// **'Save current steps as Template Set'**
  String get saveCurrentStepsAsSet;

  /// No description provided for @addAllToSteps.
  ///
  /// In en, this message translates to:
  /// **'Add All to Steps'**
  String get addAllToSteps;

  /// No description provided for @addedStepsCount.
  ///
  /// In en, this message translates to:
  /// **'Added {count} steps'**
  String addedStepsCount(int count);

  /// No description provided for @stepsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} steps'**
  String stepsCount(int count);

  /// No description provided for @dbNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., project-x, archive-2023'**
  String get dbNameHint;

  /// No description provided for @invalidDbName.
  ///
  /// In en, this message translates to:
  /// **'Invalid name. Use letters, numbers, -, _'**
  String get invalidDbName;

  /// No description provided for @defaultDbName.
  ///
  /// In en, this message translates to:
  /// **'Main Archive (Default)'**
  String get defaultDbName;

  /// No description provided for @currentlyActive.
  ///
  /// In en, this message translates to:
  /// **'Currently Active'**
  String get currentlyActive;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @switchDb.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchDb;

  /// No description provided for @switchedToDb.
  ///
  /// In en, this message translates to:
  /// **'Switched to {name}'**
  String switchedToDb(String name);

  /// No description provided for @deleteDbTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteDbTitle(String name);

  /// No description provided for @deleteDbWarning.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone. All data in this database will be lost.'**
  String get deleteDbWarning;

  /// No description provided for @saveTemplateSet.
  ///
  /// In en, this message translates to:
  /// **'Save Template Set'**
  String get saveTemplateSet;

  /// No description provided for @templateName.
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get templateName;

  /// No description provided for @templateSetSaved.
  ///
  /// In en, this message translates to:
  /// **'Template Set Saved'**
  String get templateSetSaved;

  /// No description provided for @noEventsFound.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFound;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Essenmelia'**
  String get welcomeTitle;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Manage your events, track steps, and organize your life with tags. Tap the + button to get started.'**
  String get welcomeMessage;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @tagsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type to search or create...'**
  String get tagsPlaceholder;

  /// No description provided for @failedToPickImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to pick image: {error}'**
  String failedToPickImage(String error);

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String error(String error);

  /// No description provided for @deleteAllDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete All Data?'**
  String get deleteAllDataTitle;

  /// No description provided for @deleteAllDataMessage.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteAllDataMessage;

  /// No description provided for @deleteAllDataSuccess.
  ///
  /// In en, this message translates to:
  /// **'All data deleted'**
  String get deleteAllDataSuccess;

  /// No description provided for @importFailedDetailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailedDetailed(String error);

  /// No description provided for @exportFailedDetailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailedDetailed(String error);

  /// No description provided for @navEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// No description provided for @navExtensions.
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get navExtensions;
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
