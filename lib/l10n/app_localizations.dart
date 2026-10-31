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

  /// No description provided for @windowChromeCouldNotChangeWindowButtons.
  ///
  /// In en, this message translates to:
  /// **'Could not change window buttons: {error}'**
  String windowChromeCouldNotChangeWindowButtons(String error);

  /// No description provided for @windowChromeBetternotes.
  ///
  /// In en, this message translates to:
  /// **'BetterNotes'**
  String get windowChromeBetternotes;

  /// No description provided for @windowChromeMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get windowChromeMinimize;

  /// No description provided for @windowChromeCloseWindow.
  ///
  /// In en, this message translates to:
  /// **'Close window'**
  String get windowChromeCloseWindow;

  /// No description provided for @bulkSetColor.
  ///
  /// In en, this message translates to:
  /// **'Set color'**
  String get bulkSetColor;

  /// No description provided for @bulkCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bulkCancel;

  /// No description provided for @bulkAddTags.
  ///
  /// In en, this message translates to:
  /// **'Add tags'**
  String get bulkAddTags;

  /// No description provided for @bulkAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get bulkAdd;

  /// No description provided for @bulkTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get bulkTags;

  /// No description provided for @bulkWorkIdeas.
  ///
  /// In en, this message translates to:
  /// **'work, ideas'**
  String get bulkWorkIdeas;

  /// No description provided for @drawingDrawOnNote.
  ///
  /// In en, this message translates to:
  /// **'Draw on note'**
  String get drawingDrawOnNote;

  /// No description provided for @drawingClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get drawingClear;

  /// No description provided for @findBarFindInThisNoteCtrl.
  ///
  /// In en, this message translates to:
  /// **'Find in this note (Ctrl+H)'**
  String get findBarFindInThisNoteCtrl;

  /// No description provided for @findBarPreviousMatch.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get findBarPreviousMatch;

  /// No description provided for @findBarNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get findBarNextMatch;

  /// No description provided for @findBarCloseFind.
  ///
  /// In en, this message translates to:
  /// **'Close find'**
  String get findBarCloseFind;

  /// No description provided for @noteShowAllNotes.
  ///
  /// In en, this message translates to:
  /// **'Show all notes'**
  String get noteShowAllNotes;

  /// No description provided for @noteCreateANote.
  ///
  /// In en, this message translates to:
  /// **'Create a note'**
  String get noteCreateANote;

  /// No description provided for @notePermanentlyDeleteThisNote.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete this note?'**
  String get notePermanentlyDeleteThisNote;

  /// No description provided for @noteThisCannotBeUndoneA.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. A previously exported backup will keep its copy.'**
  String get noteThisCannotBeUndoneA;

  /// No description provided for @noteDeletePermanently.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get noteDeletePermanently;

  /// No description provided for @noteRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get noteRestore;

  /// No description provided for @noteNoteRestoredFromArchive.
  ///
  /// In en, this message translates to:
  /// **'Note restored from Archive'**
  String get noteNoteRestoredFromArchive;

  /// No description provided for @noteCouldNotRestore.
  ///
  /// In en, this message translates to:
  /// **'Could not restore: {error}'**
  String noteCouldNotRestore(String error);

  /// No description provided for @noteRestoreFromArchive.
  ///
  /// In en, this message translates to:
  /// **'Restore from Archive'**
  String get noteRestoreFromArchive;

  /// No description provided for @noteCouldNotUpdateNote.
  ///
  /// In en, this message translates to:
  /// **'Could not update note: {error}'**
  String noteCouldNotUpdateNote(String error);

  /// No description provided for @noteDeleteThisNote.
  ///
  /// In en, this message translates to:
  /// **'Delete this note?'**
  String get noteDeleteThisNote;

  /// No description provided for @noteMoveThisNoteToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move this note to Trash? You can restore it later.'**
  String get noteMoveThisNoteToTrash;

  /// No description provided for @noteDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get noteDelete;

  /// No description provided for @noteCouldNotMoveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Could not move to Trash: {error}'**
  String noteCouldNotMoveToTrash(String error);

  /// No description provided for @noteDuplicateNote.
  ///
  /// In en, this message translates to:
  /// **'Duplicate note'**
  String get noteDuplicateNote;

  /// No description provided for @noteArchiveNote.
  ///
  /// In en, this message translates to:
  /// **'Archive note'**
  String get noteArchiveNote;

  /// No description provided for @noteDeleteNote.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get noteDeleteNote;

  /// No description provided for @noteImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get noteImageUnavailable;

  /// No description provided for @noteRetryLoadingOrRestoreA.
  ///
  /// In en, this message translates to:
  /// **'Retry loading or restore a copy from a complete backup.'**
  String get noteRetryLoadingOrRestoreA;

  /// No description provided for @noteRetryImage.
  ///
  /// In en, this message translates to:
  /// **'Retry image'**
  String get noteRetryImage;

  /// No description provided for @noteUpdatedNote.
  ///
  /// In en, this message translates to:
  /// **'{displayTitle}. Updated {updatedAt}. {noteColorNames} note.'**
  String noteUpdatedNote(
    String displayTitle,
    String updatedAt,
    String noteColorNames,
  );

  /// No description provided for @noteFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get noteFavorite;

  /// No description provided for @noteUpdatedNote2.
  ///
  /// In en, this message translates to:
  /// **'{displayTitle}. {preview}. Updated {updatedAt}. {noteColorNames} note.'**
  String noteUpdatedNote2(
    String displayTitle,
    String preview,
    String updatedAt,
    String noteColorNames,
  );

  /// No description provided for @noteNoteOptions.
  ///
  /// In en, this message translates to:
  /// **'Note options'**
  String get noteNoteOptions;

  /// No description provided for @noteLoadingImage.
  ///
  /// In en, this message translates to:
  /// **'Loading image'**
  String get noteLoadingImage;

  /// No description provided for @noteAttachedNoteImage.
  ///
  /// In en, this message translates to:
  /// **'Attached note image'**
  String get noteAttachedNoteImage;

  /// No description provided for @noteDesktopHeaderNewNote.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get noteDesktopHeaderNewNote;

  /// No description provided for @noteDesktopHeaderChangeColor.
  ///
  /// In en, this message translates to:
  /// **'Change color'**
  String get noteDesktopHeaderChangeColor;

  /// No description provided for @noteDesktopHeaderMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get noteDesktopHeaderMoreActions;

  /// No description provided for @noteDesktopHeaderCloseNote.
  ///
  /// In en, this message translates to:
  /// **'Close note'**
  String get noteDesktopHeaderCloseNote;

  /// No description provided for @noteDetailsTitleAndTags.
  ///
  /// In en, this message translates to:
  /// **'Title and tags'**
  String get noteDetailsTitleAndTags;

  /// No description provided for @noteDetailsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get noteDetailsSave;

  /// No description provided for @noteDetailsTitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get noteDetailsTitleOptional;

  /// No description provided for @noteDetailsUsesTheFirstTextLine.
  ///
  /// In en, this message translates to:
  /// **'Uses the first text line when blank'**
  String get noteDetailsUsesTheFirstTextLine;

  /// No description provided for @noteDetailsWorkIdeasPersonal.
  ///
  /// In en, this message translates to:
  /// **'work, ideas, personal'**
  String get noteDetailsWorkIdeasPersonal;

  /// No description provided for @noteImageEmbedRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get noteImageEmbedRemoveImage;

  /// No description provided for @noteVersionHistory.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get noteVersionHistory;

  /// No description provided for @noteExportAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get noteExportAsMarkdown;

  /// No description provided for @noteExportAsPdfToPrint.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF (to print)'**
  String get noteExportAsPdfToPrint;

  /// No description provided for @noteFindInNoteCtrlH.
  ///
  /// In en, this message translates to:
  /// **'Find in note (Ctrl+H)'**
  String get noteFindInNoteCtrlH;

  /// No description provided for @noteKeyboardShortcutsF.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts (F1)'**
  String get noteKeyboardShortcutsF;

  /// No description provided for @noteMovedToTrash.
  ///
  /// In en, this message translates to:
  /// **'Moved to Trash'**
  String get noteMovedToTrash;

  /// No description provided for @noteNoteColor.
  ///
  /// In en, this message translates to:
  /// **'Note color'**
  String get noteNoteColor;

  /// No description provided for @noteShareText.
  ///
  /// In en, this message translates to:
  /// **'Share text'**
  String get noteShareText;

  /// No description provided for @noteSaveFailedKeepEditingOr.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Keep editing or retry.'**
  String get noteSaveFailedKeepEditingOr;

  /// No description provided for @noteRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get noteRetry;

  /// No description provided for @noteCut.
  ///
  /// In en, this message translates to:
  /// **'Cut'**
  String get noteCut;

  /// No description provided for @noteCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get noteCopy;

  /// No description provided for @notePaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get notePaste;

  /// No description provided for @notePastePlain.
  ///
  /// In en, this message translates to:
  /// **'Paste as plain text'**
  String get notePastePlain;

  /// No description provided for @noteSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get noteSelectAll;

  /// No description provided for @noteHighlightColor.
  ///
  /// In en, this message translates to:
  /// **'Highlight color'**
  String get noteHighlightColor;

  /// No description provided for @noteUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get noteUndo;

  /// No description provided for @noteTextStyleOptions.
  ///
  /// In en, this message translates to:
  /// **'Text style options'**
  String get noteTextStyleOptions;

  /// No description provided for @noteAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get noteAddImage;

  /// No description provided for @notePasteImageFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste image from clipboard'**
  String get notePasteImageFromClipboard;

  /// No description provided for @noteTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get noteTakePhoto;

  /// No description provided for @noteDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get noteDraw;

  /// No description provided for @notesHomeSaveThisSearch.
  ///
  /// In en, this message translates to:
  /// **'Save this search'**
  String get notesHomeSaveThisSearch;

  /// No description provided for @notesHomeCouldNotSaveSearch.
  ///
  /// In en, this message translates to:
  /// **'Could not save search: {error}'**
  String notesHomeCouldNotSaveSearch(String error);

  /// No description provided for @notesHomeSaveSearch.
  ///
  /// In en, this message translates to:
  /// **'Save search'**
  String get notesHomeSaveSearch;

  /// No description provided for @notesHomeCouldNotSaveFilters.
  ///
  /// In en, this message translates to:
  /// **'Could not save filters: {error}'**
  String notesHomeCouldNotSaveFilters(String error);

  /// No description provided for @notesHomeMatchAllSelectedTags.
  ///
  /// In en, this message translates to:
  /// **'Match all selected tags'**
  String get notesHomeMatchAllSelectedTags;

  /// No description provided for @notesHomeManageTags.
  ///
  /// In en, this message translates to:
  /// **'Manage tags'**
  String get notesHomeManageTags;

  /// No description provided for @notesHomeClearTags.
  ///
  /// In en, this message translates to:
  /// **'Clear tags'**
  String get notesHomeClearTags;

  /// No description provided for @notesHomeApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get notesHomeApply;

  /// No description provided for @notesHomeNoteS.
  ///
  /// In en, this message translates to:
  /// **'{done}: {count} note(s).'**
  String notesHomeNoteS(String done, String count);

  /// No description provided for @notesHomeCouldNotUpdateNotes.
  ///
  /// In en, this message translates to:
  /// **'Could not update notes: {error}'**
  String notesHomeCouldNotUpdateNotes(String error);

  /// No description provided for @notesHomeMoveNoteSToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move {ids} note(s) to Trash?'**
  String notesHomeMoveNoteSToTrash(String ids);

  /// No description provided for @notesHomeYouCanRestoreThemFrom.
  ///
  /// In en, this message translates to:
  /// **'You can restore them from Trash later.'**
  String get notesHomeYouCanRestoreThemFrom;

  /// No description provided for @notesHomeMoveToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move to Trash'**
  String get notesHomeMoveToTrash;

  /// No description provided for @notesHomeSelected.
  ///
  /// In en, this message translates to:
  /// **'{_selected} selected'**
  String notesHomeSelected(String _selected);

  /// No description provided for @notesHomeSelectAllShown.
  ///
  /// In en, this message translates to:
  /// **'Select all shown'**
  String get notesHomeSelectAllShown;

  /// No description provided for @notesHomeRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get notesHomeRemoveFavorite;

  /// No description provided for @notesHomeCouldNotCreateNote.
  ///
  /// In en, this message translates to:
  /// **'Could not create note: {error}'**
  String notesHomeCouldNotCreateNote(String error);

  /// No description provided for @notesHomeCouldNotOpenNote.
  ///
  /// In en, this message translates to:
  /// **'Could not open note: {error}'**
  String notesHomeCouldNotOpenNote(String error);

  /// No description provided for @notesHomeRecentlyEdited.
  ///
  /// In en, this message translates to:
  /// **'Recently edited'**
  String get notesHomeRecentlyEdited;

  /// No description provided for @notesHomeNewestCreated.
  ///
  /// In en, this message translates to:
  /// **'Newest created'**
  String get notesHomeNewestCreated;

  /// No description provided for @notesHomeTitleAZ.
  ///
  /// In en, this message translates to:
  /// **'Title A–Z'**
  String get notesHomeTitleAZ;

  /// No description provided for @notesHomeResetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get notesHomeResetFilters;

  /// No description provided for @notesHomeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get notesHomeSettings;

  /// No description provided for @notesHomeSearchAllActiveNotesIncluding.
  ///
  /// In en, this message translates to:
  /// **'Search all active notes, including Archive'**
  String get notesHomeSearchAllActiveNotesIncluding;

  /// No description provided for @notesHomeName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get notesHomeName;

  /// No description provided for @notesHomeKeepsTheSearchTextView.
  ///
  /// In en, this message translates to:
  /// **'Keeps the search text, view, sort, and tags. Same name replaces.'**
  String get notesHomeKeepsTheSearchTextView;

  /// No description provided for @notesHomeClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get notesHomeClearSelection;

  /// No description provided for @notesHomeFavoriteSelected.
  ///
  /// In en, this message translates to:
  /// **'Favorite selected'**
  String get notesHomeFavoriteSelected;

  /// No description provided for @notesHomeArchiveSelected.
  ///
  /// In en, this message translates to:
  /// **'Archive selected'**
  String get notesHomeArchiveSelected;

  /// No description provided for @notesHomeMoveSelectedToTrash.
  ///
  /// In en, this message translates to:
  /// **'Move selected to Trash'**
  String get notesHomeMoveSelectedToTrash;

  /// No description provided for @notesHomeMoreSelectionActions.
  ///
  /// In en, this message translates to:
  /// **'More selection actions'**
  String get notesHomeMoreSelectionActions;

  /// No description provided for @notesHomeSelected2.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get notesHomeSelected2;

  /// No description provided for @notesHomeNewNoteFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'New note from template'**
  String get notesHomeNewNoteFromTemplate;

  /// No description provided for @notesHomeSearchTitlesAndTextIn.
  ///
  /// In en, this message translates to:
  /// **'Search titles and text in this view'**
  String get notesHomeSearchTitlesAndTextIn;

  /// No description provided for @notesHomeClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get notesHomeClearSearch;

  /// No description provided for @reminderCouldNotSetTheReminder.
  ///
  /// In en, this message translates to:
  /// **'Could not set the reminder: {error}'**
  String reminderCouldNotSetTheReminder(String error);

  /// No description provided for @reminderCouldNotUpdateTheReminder.
  ///
  /// In en, this message translates to:
  /// **'Could not update the reminder: {error}'**
  String reminderCouldNotUpdateTheReminder(String error);

  /// No description provided for @settingsAutomaticBackups.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups'**
  String get settingsAutomaticBackups;

  /// No description provided for @settingsTurnOff.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get settingsTurnOff;

  /// No description provided for @settingsKeepTheNewestBackups.
  ///
  /// In en, this message translates to:
  /// **'Keep the newest backups'**
  String get settingsKeepTheNewestBackups;

  /// No description provided for @settingsBackUpNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get settingsBackUpNow;

  /// No description provided for @settingsFileOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'File operation failed: {error}'**
  String settingsFileOperationFailed(String error);

  /// No description provided for @settingsImportBackupAsCopies.
  ///
  /// In en, this message translates to:
  /// **'Import backup as copies?'**
  String get settingsImportBackupAsCopies;

  /// No description provided for @settingsNotesInTrashImagesExisting.
  ///
  /// In en, this message translates to:
  /// **'{notes} notes ({trashCount} in Trash), {assets} images.\n\nExisting notes are kept. Importing the same backup again creates more copies.'**
  String settingsNotesInTrashImagesExisting(
    String notes,
    String trashCount,
    String assets,
  );

  /// No description provided for @settingsRestoreAppearanceAndEditorPreferences.
  ///
  /// In en, this message translates to:
  /// **'Restore appearance and editor preferences'**
  String get settingsRestoreAppearanceAndEditorPreferences;

  /// No description provided for @settingsImportCopies.
  ///
  /// In en, this message translates to:
  /// **'Import copies'**
  String get settingsImportCopies;

  /// No description provided for @settingsCouldNotReadWindowsStartup.
  ///
  /// In en, this message translates to:
  /// **'Could not read Windows startup setting: {error}'**
  String settingsCouldNotReadWindowsStartup(String error);

  /// No description provided for @settingsCouldNotChangeWindowsStartup.
  ///
  /// In en, this message translates to:
  /// **'Could not change Windows startup: {error}'**
  String settingsCouldNotChangeWindowsStartup(String error);

  /// No description provided for @settingsSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {error}'**
  String settingsSignInFailed(String error);

  /// No description provided for @settingsContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get settingsContinueWithGoogle;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSyncNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Sync needs attention'**
  String get settingsSyncNeedsAttention;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystem;

  /// No description provided for @settingsLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsLight;

  /// No description provided for @settingsDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsDark;

  /// No description provided for @settingsConfirmBeforeDeleting.
  ///
  /// In en, this message translates to:
  /// **'Confirm before deleting'**
  String get settingsConfirmBeforeDeleting;

  /// No description provided for @settingsEmptyTrashAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Empty Trash automatically'**
  String get settingsEmptyTrashAutomatically;

  /// No description provided for @settingsPermanentlyDeletesLocalNotesAfter.
  ///
  /// In en, this message translates to:
  /// **'Permanently deletes local notes after this long in Trash. Signed-in account notes keep their sync records and are not removed.'**
  String get settingsPermanentlyDeletesLocalNotesAfter;

  /// No description provided for @settingsNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get settingsNever;

  /// No description provided for @settingsAfterDays.
  ///
  /// In en, this message translates to:
  /// **'After 7 days'**
  String get settingsAfterDays;

  /// No description provided for @settingsAfterDays2.
  ///
  /// In en, this message translates to:
  /// **'After 30 days'**
  String get settingsAfterDays2;

  /// No description provided for @settingsAfterDays3.
  ///
  /// In en, this message translates to:
  /// **'After 90 days'**
  String get settingsAfterDays3;

  /// No description provided for @settingsImagePlacement.
  ///
  /// In en, this message translates to:
  /// **'Image placement'**
  String get settingsImagePlacement;

  /// No description provided for @settingsAppliesToNewImagesExisting.
  ///
  /// In en, this message translates to:
  /// **'Applies to new images. Existing images stay in place.'**
  String get settingsAppliesToNewImagesExisting;

  /// No description provided for @settingsAboveTextCurrent.
  ///
  /// In en, this message translates to:
  /// **'Above text (current)'**
  String get settingsAboveTextCurrent;

  /// No description provided for @settingsWithinNote.
  ///
  /// In en, this message translates to:
  /// **'Within note'**
  String get settingsWithinNote;

  /// No description provided for @settingsCouldNotSaveImagePlacement.
  ///
  /// In en, this message translates to:
  /// **'Could not save image placement: {error}'**
  String settingsCouldNotSaveImagePlacement(String error);

  /// No description provided for @settingsAlwaysShowNoteHeader.
  ///
  /// In en, this message translates to:
  /// **'Always show note header'**
  String get settingsAlwaysShowNoteHeader;

  /// No description provided for @settingsKeepNoteActionsVisibleWithout.
  ///
  /// In en, this message translates to:
  /// **'Keep note actions visible without hovering.'**
  String get settingsKeepNoteActionsVisibleWithout;

  /// No description provided for @settingsCouldNotSaveHeaderPreference.
  ///
  /// In en, this message translates to:
  /// **'Could not save header preference: {error}'**
  String settingsCouldNotSaveHeaderPreference(String error);

  /// No description provided for @settingsRemindMeWhenBetternotesIs.
  ///
  /// In en, this message translates to:
  /// **'Remind me when BetterNotes is closed'**
  String get settingsRemindMeWhenBetternotesIs;

  /// No description provided for @settingsCouldNotUpdateTheScheduled.
  ///
  /// In en, this message translates to:
  /// **'Could not update the scheduled task: {error}'**
  String settingsCouldNotUpdateTheScheduled(String error);

  /// No description provided for @settingsKeepRunningInTheSystem.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the system tray'**
  String get settingsKeepRunningInTheSystem;

  /// No description provided for @settingsClosingTheNotesWindowHides.
  ///
  /// In en, this message translates to:
  /// **'Closing the notes window hides it; use the tray icon to open notes, start a note, or Quit.'**
  String get settingsClosingTheNotesWindowHides;

  /// No description provided for @settingsCouldNotChangeTrayMode.
  ///
  /// In en, this message translates to:
  /// **'Could not change tray mode: {error}'**
  String settingsCouldNotChangeTrayMode(String error);

  /// No description provided for @settingsQuickNoteShortcut.
  ///
  /// In en, this message translates to:
  /// **'Quick note shortcut'**
  String get settingsQuickNoteShortcut;

  /// No description provided for @settingsFastNoteOpening.
  ///
  /// In en, this message translates to:
  /// **'Fast note opening'**
  String get settingsFastNoteOpening;

  /// No description provided for @settingsKeepOneIdleNoteWindow.
  ///
  /// In en, this message translates to:
  /// **'Keep one idle note window ready. Uses some memory; turn off to open notes a little slower.'**
  String get settingsKeepOneIdleNoteWindow;

  /// No description provided for @settingsCouldNotSaveThisPreference.
  ///
  /// In en, this message translates to:
  /// **'Could not save this preference: {error}'**
  String settingsCouldNotSaveThisPreference(String error);

  /// No description provided for @settingsWindowButtons.
  ///
  /// In en, this message translates to:
  /// **'Window buttons'**
  String get settingsWindowButtons;

  /// No description provided for @settingsAppliesToAllBetternotesWindows.
  ///
  /// In en, this message translates to:
  /// **'Applies to all BetterNotes windows.'**
  String get settingsAppliesToAllBetternotesWindows;

  /// No description provided for @settingsCouldNotSaveWindowButtons.
  ///
  /// In en, this message translates to:
  /// **'Could not save window buttons: {error}'**
  String settingsCouldNotSaveWindowButtons(String error);

  /// No description provided for @settingsWindows.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get settingsWindows;

  /// No description provided for @settingsStartWithWindows.
  ///
  /// In en, this message translates to:
  /// **'Start with Windows'**
  String get settingsStartWithWindows;

  /// No description provided for @settingsOpenBetternotesWhenYouSign.
  ///
  /// In en, this message translates to:
  /// **'Open BetterNotes when you sign in to Windows.'**
  String get settingsOpenBetternotesWhenYouSign;

  /// No description provided for @settingsBackupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get settingsBackupAndRestore;

  /// No description provided for @settingsCompleteBackupsIncludeTrashFormatting.
  ///
  /// In en, this message translates to:
  /// **'Complete backups include Trash, formatting, images, and drawings. Exported files are readable and unencrypted.'**
  String get settingsCompleteBackupsIncludeTrashFormatting;

  /// No description provided for @settingsExportCompleteBackup.
  ///
  /// In en, this message translates to:
  /// **'Export complete backup'**
  String get settingsExportCompleteBackup;

  /// No description provided for @settingsImportBackup.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get settingsImportBackup;

  /// No description provided for @settingsReviewAndAddCopiesWithout.
  ///
  /// In en, this message translates to:
  /// **'Review and add copies without replacing existing notes.'**
  String get settingsReviewAndAddCopiesWithout;

  /// No description provided for @settingsImportIsNotAvailableOn.
  ///
  /// In en, this message translates to:
  /// **'Import is not available on this platform.'**
  String get settingsImportIsNotAvailableOn;

  /// No description provided for @settingsExportActiveNotesAsText.
  ///
  /// In en, this message translates to:
  /// **'Export active notes as text'**
  String get settingsExportActiveNotesAsText;

  /// No description provided for @settingsTextOnlyUseAComplete.
  ///
  /// In en, this message translates to:
  /// **'Text only; use a complete backup for restoration.'**
  String get settingsTextOnlyUseAComplete;

  /// No description provided for @settingsKeyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get settingsKeyboardShortcuts;

  /// No description provided for @settingsEditingSearchAndWindowControls.
  ///
  /// In en, this message translates to:
  /// **'Editing, search, and window controls.'**
  String get settingsEditingSearchAndWindowControls;

  /// No description provided for @shortcutsHelpLibraryAndNoteWindows.
  ///
  /// In en, this message translates to:
  /// **'Library and note windows'**
  String get shortcutsHelpLibraryAndNoteWindows;

  /// No description provided for @shortcutsHelpCtrlNNewNoteCtrl.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+N — New note\nCtrl+F — Search library\nF1 — Shortcut help'**
  String get shortcutsHelpCtrlNNewNoteCtrl;

  /// No description provided for @shortcutsHelpInANote.
  ///
  /// In en, this message translates to:
  /// **'In a note'**
  String get shortcutsHelpInANote;

  /// No description provided for @shortcutsHelpCtrlWSaveAndClose.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+W — Save and close\nCtrl+D — Move to Trash\nCtrl+H — Find in this note\nEnter / Shift+Enter — Next / previous match\nEscape — Close find\nCtrl+Shift+V — Paste as plain text\nPaste a web address over selected text — Make a link'**
  String get shortcutsHelpCtrlWSaveAndClose;

  /// No description provided for @shortcutsHelpWhileEditingText.
  ///
  /// In en, this message translates to:
  /// **'While editing text'**
  String get shortcutsHelpWhileEditingText;

  /// No description provided for @shortcutsHelpCtrlBIUT.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+B / I / U / T — Bold / italic / underline / strikethrough\nCtrl+Shift+L — Bulleted list\nCtrl+Z — Undo\nCtrl+Y — Redo\nCtrl+C / X / V / A — Copy / cut / paste / select all'**
  String get shortcutsHelpCtrlBIUT;

  /// No description provided for @shortcutsHelpSelectTextThenOpenText.
  ///
  /// In en, this message translates to:
  /// **'Select text, then open Text style options beside Add image for font size, text color, highlighting, headings, numbered lists, quotes, inline code, and clear formatting. With no selection, styles apply to what you type next.'**
  String get shortcutsHelpSelectTextThenOpenText;

  /// No description provided for @shortcutsHelpUseTabAndShiftTab.
  ///
  /// In en, this message translates to:
  /// **'Use Tab and Shift+Tab to move between controls, and Enter or Space to activate them. Checklists, title, tags, favorites, and Archive are available from the toolbar or note menus. Closing keeps the note; deleting moves it to Trash.'**
  String get shortcutsHelpUseTabAndShiftTab;

  /// No description provided for @startupErrorBetternotesCouldnTOpenYour.
  ///
  /// In en, this message translates to:
  /// **'BetterNotes couldn\'t open your notes'**
  String get startupErrorBetternotesCouldnTOpenYour;

  /// No description provided for @startupErrorNothingWasChangedOrDeleted.
  ///
  /// In en, this message translates to:
  /// **'Nothing was changed or deleted. Try again first; if the problem continues, start with an empty library and restore from a backup.'**
  String get startupErrorNothingWasChangedOrDeleted;

  /// No description provided for @startupErrorTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get startupErrorTryAgain;

  /// No description provided for @startupErrorCopyDetails.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get startupErrorCopyDetails;

  /// No description provided for @startupErrorStartEmptyKeepACopy.
  ///
  /// In en, this message translates to:
  /// **'Start empty (keep a copy)'**
  String get startupErrorStartEmptyKeepACopy;

  /// No description provided for @startupErrorStartWithAnEmptyLibrary.
  ///
  /// In en, this message translates to:
  /// **'Start with an empty library?'**
  String get startupErrorStartWithAnEmptyLibrary;

  /// No description provided for @startupErrorTheUnreadableLibraryFileIs.
  ///
  /// In en, this message translates to:
  /// **'The unreadable library file is renamed, not deleted, so it can still be recovered. Notes in your account sync back if you sign in; otherwise restore a backup from Settings.'**
  String get startupErrorTheUnreadableLibraryFileIs;

  /// No description provided for @startupErrorStartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Start empty'**
  String get startupErrorStartEmpty;

  /// No description provided for @tagManagerNoTagsYetAddTags.
  ///
  /// In en, this message translates to:
  /// **'No tags yet. Add tags from a note’s menu.'**
  String get tagManagerNoTagsYetAddTags;

  /// No description provided for @tagManagerCouldNotChangeTag.
  ///
  /// In en, this message translates to:
  /// **'Could not change tag: {error}'**
  String tagManagerCouldNotChangeTag(String error);

  /// No description provided for @tagManagerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename “{tag}”'**
  String tagManagerRename(String tag);

  /// No description provided for @tagManagerRename2.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get tagManagerRename2;

  /// No description provided for @tagManagerDeleteTag.
  ///
  /// In en, this message translates to:
  /// **'Delete tag “{tag}”?'**
  String tagManagerDeleteTag(String tag);

  /// No description provided for @tagManagerTheTagIsRemovedFrom.
  ///
  /// In en, this message translates to:
  /// **'The tag is removed from every note. Notes stay.'**
  String get tagManagerTheTagIsRemovedFrom;

  /// No description provided for @tagManagerDeleteTag2.
  ///
  /// In en, this message translates to:
  /// **'Delete tag'**
  String get tagManagerDeleteTag2;

  /// No description provided for @tagManagerRenameOrMerge.
  ///
  /// In en, this message translates to:
  /// **'Rename or merge {tag}'**
  String tagManagerRenameOrMerge(String tag);

  /// No description provided for @tagManagerDeleteTag3.
  ///
  /// In en, this message translates to:
  /// **'Delete tag {tag}'**
  String tagManagerDeleteTag3(String tag);

  /// No description provided for @tagManagerUsingAnExistingTagName.
  ///
  /// In en, this message translates to:
  /// **'Using an existing tag name merges the two.'**
  String get tagManagerUsingAnExistingTagName;

  /// No description provided for @textColorResetColor.
  ///
  /// In en, this message translates to:
  /// **'Reset color'**
  String get textColorResetColor;

  /// No description provided for @textColorHexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get textColorHexColor;

  /// No description provided for @textStylePanelSelectTextToStyleIt.
  ///
  /// In en, this message translates to:
  /// **'Select text to style it, or choose a style before typing.'**
  String get textStylePanelSelectTextToStyleIt;

  /// No description provided for @textStylePanelTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get textStylePanelTextColor;

  /// No description provided for @versionHistoryCouldNotLoadVersions.
  ///
  /// In en, this message translates to:
  /// **'Could not load versions: {error}'**
  String versionHistoryCouldNotLoadVersions(String error);

  /// No description provided for @versionHistoryNoEarlierVersionsYetBetternotes.
  ///
  /// In en, this message translates to:
  /// **'No earlier versions yet. BetterNotes saves one while you edit, at most every 5 minutes, and keeps the latest {maxRevisionsPerNote}.'**
  String versionHistoryNoEarlierVersionsYetBetternotes(
    String maxRevisionsPerNote,
  );

  /// No description provided for @versionHistoryWords.
  ///
  /// In en, this message translates to:
  /// **'{createdAt} · {words} words'**
  String versionHistoryWords(String createdAt, String words);

  /// No description provided for @versionHistoryRestoreAsACopy.
  ///
  /// In en, this message translates to:
  /// **'Restore as a copy'**
  String get versionHistoryRestoreAsACopy;

  /// No description provided for @bulkExportedNoteSAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Exported {fresh} note(s) as Markdown.'**
  String bulkExportedNoteSAsMarkdown(String fresh);

  /// No description provided for @noteImageUnavailableOpenTheNote.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable. Open the note to retry or restore from a backup.'**
  String get noteImageUnavailableOpenTheNote;

  /// No description provided for @noteNoMatchingNotes.
  ///
  /// In en, this message translates to:
  /// **'No matching notes'**
  String get noteNoMatchingNotes;

  /// No description provided for @noteAFreshSpaceForYour.
  ///
  /// In en, this message translates to:
  /// **'A fresh space for your ideas'**
  String get noteAFreshSpaceForYour;

  /// No description provided for @noteTryAnotherWordOrClear.
  ///
  /// In en, this message translates to:
  /// **'Try another word or clear the search.'**
  String get noteTryAnotherWordOrClear;

  /// No description provided for @noteChooseAnotherViewOrReset.
  ///
  /// In en, this message translates to:
  /// **'Choose another view or reset filters to see your notes.'**
  String get noteChooseAnotherViewOrReset;

  /// No description provided for @noteKeepAThoughtCloseStart.
  ///
  /// In en, this message translates to:
  /// **'Keep a thought close. Start with a note.'**
  String get noteKeepAThoughtCloseStart;

  /// No description provided for @noteNotePermanentlyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note permanently deleted'**
  String get noteNotePermanentlyDeleted;

  /// No description provided for @noteNoteRestoredToNotes.
  ///
  /// In en, this message translates to:
  /// **'Note restored to Notes'**
  String get noteNoteRestoredToNotes;

  /// No description provided for @noteInTrash.
  ///
  /// In en, this message translates to:
  /// **'In Trash'**
  String get noteInTrash;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted {deletedAt}'**
  String noteDeleted(String deletedAt);

  /// No description provided for @noteAccountTrashRetainsSyncRecords.
  ///
  /// In en, this message translates to:
  /// **'Account Trash retains sync records'**
  String get noteAccountTrashRetainsSyncRecords;

  /// No description provided for @noteTodayAm.
  ///
  /// In en, this message translates to:
  /// **'Today 9:00 AM'**
  String get noteTodayAm;

  /// No description provided for @noteDesktopHeaderTurnOffAlwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Turn off always on top'**
  String get noteDesktopHeaderTurnOffAlwaysOnTop;

  /// No description provided for @noteDesktopHeaderAlwaysOnTop.
  ///
  /// In en, this message translates to:
  /// **'Always on top'**
  String get noteDesktopHeaderAlwaysOnTop;

  /// No description provided for @noteWriteANote.
  ///
  /// In en, this message translates to:
  /// **'Write a note...'**
  String get noteWriteANote;

  /// No description provided for @noteSetReminder.
  ///
  /// In en, this message translates to:
  /// **'Set reminder…'**
  String get noteSetReminder;

  /// No description provided for @noteEditReminder.
  ///
  /// In en, this message translates to:
  /// **'Edit reminder…'**
  String get noteEditReminder;

  /// No description provided for @noteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get noteSaveFailed;

  /// No description provided for @noteSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get noteSaving;

  /// No description provided for @noteSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved locally'**
  String get noteSavedLocally;

  /// No description provided for @noteSavingLocally.
  ///
  /// In en, this message translates to:
  /// **'Saving locally'**
  String get noteSavingLocally;

  /// No description provided for @noteCouldNotReadAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Could not read always on top: {error}'**
  String noteCouldNotReadAlwaysOn(String error);

  /// No description provided for @noteCouldNotChangeAlwaysOn.
  ///
  /// In en, this message translates to:
  /// **'Could not change always on top: {error}'**
  String noteCouldNotChangeAlwaysOn(String error);

  /// No description provided for @noteCouldNotSaveDetails.
  ///
  /// In en, this message translates to:
  /// **'Could not save details: {error}'**
  String noteCouldNotSaveDetails(String error);

  /// No description provided for @noteExported.
  ///
  /// In en, this message translates to:
  /// **'Exported \"{name}\".'**
  String noteExported(String name);

  /// No description provided for @noteCouldNotExport.
  ///
  /// In en, this message translates to:
  /// **'Could not export: {error}'**
  String noteCouldNotExport(String error);

  /// No description provided for @noteDuplicatedAs.
  ///
  /// In en, this message translates to:
  /// **'Duplicated as \"{displayTitle}\".'**
  String noteDuplicatedAs(String displayTitle);

  /// No description provided for @noteCouldNotDuplicateNote.
  ///
  /// In en, this message translates to:
  /// **'Could not duplicate note: {error}'**
  String noteCouldNotDuplicateNote(String error);

  /// No description provided for @noteSaveFailedRetryBeforeReturning.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Retry before returning to your notes.'**
  String get noteSaveFailedRetryBeforeReturning;

  /// No description provided for @noteSaveFailedRetrySavingBefore.
  ///
  /// In en, this message translates to:
  /// **'Save failed. Retry saving before closing, or keep editing.'**
  String get noteSaveFailedRetrySavingBefore;

  /// No description provided for @noteCouldNotAddImage.
  ///
  /// In en, this message translates to:
  /// **'Could not add image: {error}'**
  String noteCouldNotAddImage(String error);

  /// No description provided for @noteNoImageOnTheClipboard.
  ///
  /// In en, this message translates to:
  /// **'No image on the clipboard.'**
  String get noteNoImageOnTheClipboard;

  /// No description provided for @noteCouldNotPasteImage.
  ///
  /// In en, this message translates to:
  /// **'Could not paste image: {error}'**
  String noteCouldNotPasteImage(String error);

  /// No description provided for @noteCouldNotCompleteThatAction.
  ///
  /// In en, this message translates to:
  /// **'Could not complete that action: {error}'**
  String noteCouldNotCompleteThatAction(String error);

  /// No description provided for @noteCouldNotChangeTextColor.
  ///
  /// In en, this message translates to:
  /// **'Could not change text color: {error}'**
  String noteCouldNotChangeTextColor(String error);

  /// No description provided for @notesHomeDeleteSavedSearch.
  ///
  /// In en, this message translates to:
  /// **'Delete saved search {name}'**
  String notesHomeDeleteSavedSearch(String name);

  /// No description provided for @notesHomeSyncNotes.
  ///
  /// In en, this message translates to:
  /// **'Sync notes'**
  String get notesHomeSyncNotes;

  /// No description provided for @notesHomeLocalNotes.
  ///
  /// In en, this message translates to:
  /// **'Local notes'**
  String get notesHomeLocalNotes;

  /// No description provided for @notesHomeAllActive.
  ///
  /// In en, this message translates to:
  /// **'All active'**
  String get notesHomeAllActive;

  /// No description provided for @notesHomeCardView.
  ///
  /// In en, this message translates to:
  /// **'Card view'**
  String get notesHomeCardView;

  /// No description provided for @notesHomeCompactListView.
  ///
  /// In en, this message translates to:
  /// **'Compact list view'**
  String get notesHomeCompactListView;

  /// No description provided for @notesHomeFilterByTags.
  ///
  /// In en, this message translates to:
  /// **'Filter by tags'**
  String get notesHomeFilterByTags;

  /// No description provided for @notesHomeTags.
  ///
  /// In en, this message translates to:
  /// **'Tags: {tags}'**
  String notesHomeTags(String tags);

  /// No description provided for @notesHomeTrashIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Trash is empty'**
  String get notesHomeTrashIsEmpty;

  /// No description provided for @notesHomeNoMatchingNotesInTrash.
  ///
  /// In en, this message translates to:
  /// **'No matching notes in Trash'**
  String get notesHomeNoMatchingNotesInTrash;

  /// No description provided for @notesHomeNoNotesMatchThisView.
  ///
  /// In en, this message translates to:
  /// **'No notes match this view and filters'**
  String get notesHomeNoNotesMatchThisView;

  /// No description provided for @settingsBackingUpNow.
  ///
  /// In en, this message translates to:
  /// **'Backing up now...'**
  String get settingsBackingUpNow;

  /// No description provided for @settingsNoAutomaticBackupHasRun.
  ///
  /// In en, this message translates to:
  /// **'No automatic backup has run yet.'**
  String get settingsNoAutomaticBackupHasRun;

  /// No description provided for @settingsLastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {substring}'**
  String settingsLastBackup(String substring);

  /// No description provided for @settingsOffChooseAFolderTo.
  ///
  /// In en, this message translates to:
  /// **'Off. Choose a folder to save a complete backup about once a day.'**
  String get settingsOffChooseAFolderTo;

  /// No description provided for @settingsChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose folder'**
  String get settingsChooseFolder;

  /// No description provided for @settingsBackupExportedKeepThisReadable.
  ///
  /// In en, this message translates to:
  /// **'Backup exported. Keep this readable file in a safe place.'**
  String get settingsBackupExportedKeepThisReadable;

  /// No description provided for @settingsTextExportedUseAComplete.
  ///
  /// In en, this message translates to:
  /// **'Text exported. Use a complete backup to restore images and formatting.'**
  String get settingsTextExportedUseAComplete;

  /// No description provided for @settingsYourNotesCanSyncAcross.
  ///
  /// In en, this message translates to:
  /// **'Your notes can sync across devices.'**
  String get settingsYourNotesCanSyncAcross;

  /// No description provided for @settingsSignInWithGoogleTo.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google to sync your notes.'**
  String get settingsSignInWithGoogleTo;

  /// No description provided for @settingsGoogleSyncNeedsASupabase.
  ///
  /// In en, this message translates to:
  /// **'Google sync needs a Supabase project connection.'**
  String get settingsGoogleSyncNeedsASupabase;

  /// No description provided for @settingsAddsAWindowsScheduledTask.
  ///
  /// In en, this message translates to:
  /// **'Adds a Windows scheduled task (BetterNotes Reminders, this user only) that opens BetterNotes when a reminder is due or at sign-in. Best effort: a reminder missed while the PC was off is shown the next time the app starts. Turn off to remove the task.'**
  String get settingsAddsAWindowsScheduledTask;

  /// No description provided for @settingsAGlobalShortcutThatOpens.
  ///
  /// In en, this message translates to:
  /// **'A global shortcut that opens a new note from any app while BetterNotes is running.'**
  String get settingsAGlobalShortcutThatOpens;

  /// No description provided for @settingsAnotherAppAlreadyUsesThat.
  ///
  /// In en, this message translates to:
  /// **'Another app already uses that shortcut. Choose a different one.'**
  String get settingsAnotherAppAlreadyUsesThat;

  /// No description provided for @settingsCouldNotSetTheShortcut.
  ///
  /// In en, this message translates to:
  /// **'Could not set the shortcut: {error}'**
  String settingsCouldNotSetTheShortcut(String error);

  /// No description provided for @settingsCheckingWindowsStartupSetting.
  ///
  /// In en, this message translates to:
  /// **'Checking Windows startup setting'**
  String get settingsCheckingWindowsStartupSetting;

  /// No description provided for @settingsCouldNotReadWindowsStartup2.
  ///
  /// In en, this message translates to:
  /// **'Could not read Windows startup setting'**
  String get settingsCouldNotReadWindowsStartup2;

  /// No description provided for @textColorEnterSixHexDigitsSuch.
  ///
  /// In en, this message translates to:
  /// **'Enter six hex digits, such as #795082.'**
  String get textColorEnterSixHexDigitsSuch;

  /// No description provided for @versionHistoryThatVersionIsNoLonger.
  ///
  /// In en, this message translates to:
  /// **'That version is no longer available.'**
  String get versionHistoryThatVersionIsNoLonger;

  /// No description provided for @versionHistoryRestoredAsANewNote.
  ///
  /// In en, this message translates to:
  /// **'Restored as a new note: {displayTitle}'**
  String versionHistoryRestoredAsANewNote(String displayTitle);

  /// No description provided for @viewNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get viewNotes;

  /// No description provided for @viewFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get viewFavorites;

  /// No description provided for @viewReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get viewReminders;

  /// No description provided for @viewArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get viewArchive;

  /// No description provided for @viewTrash.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get viewTrash;

  /// No description provided for @bulkDoneMovedToTrash.
  ///
  /// In en, this message translates to:
  /// **'Moved to Trash'**
  String get bulkDoneMovedToTrash;

  /// No description provided for @bulkDoneRemovedFavorite.
  ///
  /// In en, this message translates to:
  /// **'Removed favorite'**
  String get bulkDoneRemovedFavorite;

  /// No description provided for @bulkDoneColorChanged.
  ///
  /// In en, this message translates to:
  /// **'Color changed'**
  String get bulkDoneColorChanged;

  /// No description provided for @bulkDoneTagsAdded.
  ///
  /// In en, this message translates to:
  /// **'Tags added'**
  String get bulkDoneTagsAdded;

  /// No description provided for @bulkDoneExported.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get bulkDoneExported;

  /// No description provided for @bulkDoneFavorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get bulkDoneFavorited;

  /// No description provided for @bulkDoneArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get bulkDoneArchived;

  /// No description provided for @imageQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Picture storage'**
  String get imageQualityTitle;

  /// No description provided for @imageQualityHelp.
  ///
  /// In en, this message translates to:
  /// **'Pictures are compressed once, when you add them, to save space on this device, in backups, and online. The original is not kept.'**
  String get imageQualityHelp;

  /// No description provided for @imageQualityBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced (recommended)'**
  String get imageQualityBalanced;

  /// No description provided for @imageQualitySmallest.
  ///
  /// In en, this message translates to:
  /// **'Smallest files'**
  String get imageQualitySmallest;

  /// No description provided for @imageQualityOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original (only shrink huge pictures)'**
  String get imageQualityOriginal;

  /// No description provided for @shrinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Shrink saved pictures'**
  String get shrinkTitle;

  /// No description provided for @shrinkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-compress the pictures already in your notes with the setting above. They are replaced by smaller copies and this cannot be undone.'**
  String get shrinkSubtitle;

  /// No description provided for @shrinkSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not available while signed in: pictures that were already uploaded would not be updated. Do this before connecting an account.'**
  String get shrinkSignedIn;

  /// No description provided for @shrinkWorking.
  ///
  /// In en, this message translates to:
  /// **'Checking pictures… {done} of {total}'**
  String shrinkWorking(String done, String total);

  /// No description provided for @shrinkNothing.
  ///
  /// In en, this message translates to:
  /// **'Your pictures are already as small as they can reasonably be.'**
  String get shrinkNothing;

  /// No description provided for @shrinkFound.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} pictures can shrink from {before} to {after}, saving {saved}. Export a backup first if you want to keep the originals.'**
  String shrinkFound(
    String count,
    String total,
    String before,
    String after,
    String saved,
  );

  /// No description provided for @shrinkApply.
  ///
  /// In en, this message translates to:
  /// **'Shrink pictures'**
  String get shrinkApply;

  /// No description provided for @shrinkCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shrinkCancel;

  /// No description provided for @shrinkDone.
  ///
  /// In en, this message translates to:
  /// **'Pictures shrunk. Saved {saved}.'**
  String shrinkDone(String saved);

  /// No description provided for @shrinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not shrink pictures: {error}'**
  String shrinkFailed(String error);

  /// No description provided for @stickyTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Windows Sticky Notes'**
  String get stickyTitle;

  /// No description provided for @stickySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Copy your existing Sticky Notes into BetterNotes once. Sticky Notes itself is not changed.'**
  String get stickySubtitle;

  /// No description provided for @stickyFound.
  ///
  /// In en, this message translates to:
  /// **'Found {count} notes with {pictures} pictures in Windows Sticky Notes ({already} already imported). Import them as new notes tagged \"sticky notes\"? Sticky Notes is not changed.'**
  String stickyFound(String count, String pictures, String already);

  /// No description provided for @stickyNoneNew.
  ///
  /// In en, this message translates to:
  /// **'There are no new Sticky Notes to import.'**
  String get stickyNoneNew;

  /// No description provided for @stickyImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get stickyImport;

  /// No description provided for @stickyCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get stickyCancel;

  /// No description provided for @stickyWorking.
  ///
  /// In en, this message translates to:
  /// **'Importing… {done} of {total}'**
  String stickyWorking(String done, String total);

  /// No description provided for @stickyDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} notes and {pictures} pictures.'**
  String stickyDone(String count, String pictures);

  /// No description provided for @stickyDoneSkipped.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} notes and {pictures} pictures. {skipped} items could not be imported or were empty.'**
  String stickyDoneSkipped(String count, String pictures, String skipped);

  /// No description provided for @stickyFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import Sticky Notes: {error}'**
  String stickyFailed(String error);

  /// No description provided for @sortUpdatedOldest.
  ///
  /// In en, this message translates to:
  /// **'Least recently edited'**
  String get sortUpdatedOldest;

  /// No description provided for @sortCreatedOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest created'**
  String get sortCreatedOldest;

  /// No description provided for @sortTitleDesc.
  ///
  /// In en, this message translates to:
  /// **'Title Z–A'**
  String get sortTitleDesc;

  /// No description provided for @sortReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder date'**
  String get sortReminder;

  /// No description provided for @sortColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get sortColor;

  /// No description provided for @sortLength.
  ///
  /// In en, this message translates to:
  /// **'Longest first'**
  String get sortLength;

  /// No description provided for @sortFavoritesFirst.
  ///
  /// In en, this message translates to:
  /// **'Favorites first'**
  String get sortFavoritesFirst;

  /// No description provided for @libraryNavigation.
  ///
  /// In en, this message translates to:
  /// **'Browse notes'**
  String get libraryNavigation;

  /// No description provided for @libraryFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get libraryFilters;

  /// No description provided for @settingsReduceTransparency.
  ///
  /// In en, this message translates to:
  /// **'Reduce transparency'**
  String get settingsReduceTransparency;

  /// No description provided for @settingsAccountSection.
  ///
  /// In en, this message translates to:
  /// **'Account & sync'**
  String get settingsAccountSection;

  /// No description provided for @settingsEditingSection.
  ///
  /// In en, this message translates to:
  /// **'Editing'**
  String get settingsEditingSection;

  /// No description provided for @settingsStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage & pictures'**
  String get settingsStorageSection;

  /// No description provided for @settingsWindowsSection.
  ///
  /// In en, this message translates to:
  /// **'Windows'**
  String get settingsWindowsSection;

  /// No description provided for @settingsBackupSection.
  ///
  /// In en, this message translates to:
  /// **'Backups & export'**
  String get settingsBackupSection;

  /// No description provided for @settingsHelpSection.
  ///
  /// In en, this message translates to:
  /// **'Help & about'**
  String get settingsHelpSection;

  /// No description provided for @cardCreated.
  ///
  /// In en, this message translates to:
  /// **'Created {time}'**
  String cardCreated(String time);

  /// No description provided for @cleanupAction.
  ///
  /// In en, this message translates to:
  /// **'Clean up text…'**
  String get cleanupAction;

  /// No description provided for @cleanupSelection.
  ///
  /// In en, this message translates to:
  /// **'Clean up selection'**
  String get cleanupSelection;

  /// No description provided for @cleanupNote.
  ///
  /// In en, this message translates to:
  /// **'Clean up note'**
  String get cleanupNote;

  /// No description provided for @cleanupTrailing.
  ///
  /// In en, this message translates to:
  /// **'Remove trailing spaces'**
  String get cleanupTrailing;

  /// No description provided for @cleanupBlank.
  ///
  /// In en, this message translates to:
  /// **'Reduce excess blank lines'**
  String get cleanupBlank;

  /// No description provided for @cleanupRepeated.
  ///
  /// In en, this message translates to:
  /// **'Reduce repeated spaces between words'**
  String get cleanupRepeated;

  /// No description provided for @cleanupApply.
  ///
  /// In en, this message translates to:
  /// **'Apply cleanup'**
  String get cleanupApply;

  /// No description provided for @cleanupCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cleanupCancel;

  /// No description provided for @cleanupNone.
  ///
  /// In en, this message translates to:
  /// **'No cleanup needed'**
  String get cleanupNone;

  /// No description provided for @cleanupStale.
  ///
  /// In en, this message translates to:
  /// **'The note changed. Close this preview and try again.'**
  String get cleanupStale;

  /// No description provided for @cleanupCounts.
  ///
  /// In en, this message translates to:
  /// **'{spaces} spaces and {lines} blank lines removed'**
  String cleanupCounts(int spaces, int lines);
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
