import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About BetterNotes'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A colorful home for little ideas.'**
  String get aboutTagline;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Notes data'**
  String get aboutDataTitle;

  /// No description provided for @aboutDataBrowser.
  ///
  /// In en, this message translates to:
  /// **'Stored in this browser.'**
  String get aboutDataBrowser;

  /// No description provided for @aboutLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Log file'**
  String get aboutLogTitle;

  /// No description provided for @aboutLogNone.
  ///
  /// In en, this message translates to:
  /// **'No log file on this platform.'**
  String get aboutLogNone;

  /// No description provided for @aboutCopyDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Copy diagnostics'**
  String get aboutCopyDiagnostics;

  /// No description provided for @aboutDiagnosticsCopied.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics copied. They contain no note text.'**
  String get aboutDiagnosticsCopied;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'BetterNotes keeps notes and a small error log on this device. It collects no usage data and sends nothing without your sign-in and sync settings. Diagnostics hold versions, counts, and settings states only, never note text.'**
  String get aboutPrivacy;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · diagnostics and data location'**
  String settingsAboutSubtitle(String version);

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderTitle;

  /// No description provided for @reminderShownAt.
  ///
  /// In en, this message translates to:
  /// **'Shown {time}'**
  String reminderShownAt(String time);

  /// No description provided for @reminderSetFor.
  ///
  /// In en, this message translates to:
  /// **'Set for {time}'**
  String reminderSetFor(String time);

  /// No description provided for @reminderPickDateTime.
  ///
  /// In en, this message translates to:
  /// **'Pick date and time…'**
  String get reminderPickDateTime;

  /// No description provided for @reminderBestEffort.
  ///
  /// In en, this message translates to:
  /// **'Reminders are best effort. BetterNotes must be running, or the scheduled-task option in Settings turned on; a reminder missed while the PC was off is shown the next time the app starts.'**
  String get reminderBestEffort;

  /// No description provided for @reminderClear.
  ///
  /// In en, this message translates to:
  /// **'Clear reminder'**
  String get reminderClear;

  /// No description provided for @reminderClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get reminderClose;

  /// No description provided for @reminderCleared.
  ///
  /// In en, this message translates to:
  /// **'Reminder cleared.'**
  String get reminderCleared;

  /// No description provided for @reminderSetSnack.
  ///
  /// In en, this message translates to:
  /// **'Reminder set for {time}.'**
  String reminderSetSnack(String time);

  /// No description provided for @reminderChooseFuture.
  ///
  /// In en, this message translates to:
  /// **'Choose a time in the future.'**
  String get reminderChooseFuture;

  /// No description provided for @reminderSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get reminderSnooze;

  /// No description provided for @reminderDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reminderDone;

  /// No description provided for @reminderPresetTenMinutes.
  ///
  /// In en, this message translates to:
  /// **'In 10 minutes'**
  String get reminderPresetTenMinutes;

  /// No description provided for @reminderPresetOneHour.
  ///
  /// In en, this message translates to:
  /// **'In 1 hour'**
  String get reminderPresetOneHour;

  /// No description provided for @reminderPresetEvening.
  ///
  /// In en, this message translates to:
  /// **'This evening (6 PM)'**
  String get reminderPresetEvening;

  /// No description provided for @reminderPresetTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow morning (9 AM)'**
  String get reminderPresetTomorrow;

  /// No description provided for @reminderPresetMonday.
  ///
  /// In en, this message translates to:
  /// **'Next Monday (9 AM)'**
  String get reminderPresetMonday;

  /// No description provided for @reminderToday.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String reminderToday(String time);

  /// No description provided for @reminderTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {time}'**
  String reminderTomorrow(String time);

  /// No description provided for @reminderOn.
  ///
  /// In en, this message translates to:
  /// **'{date} {time}'**
  String reminderOn(String date, String time);

  /// No description provided for @reminderCardLabel.
  ///
  /// In en, this message translates to:
  /// **'Reminder {time}'**
  String reminderCardLabel(String time);

  /// No description provided for @reminderCardShown.
  ///
  /// In en, this message translates to:
  /// **'Reminder shown {time}'**
  String reminderCardShown(String time);
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
