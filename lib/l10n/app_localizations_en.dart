// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutTitle => 'About BetterNotes';

  @override
  String get aboutTagline => 'A colorful home for little ideas.';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutDataTitle => 'Notes data';

  @override
  String get aboutDataBrowser => 'Stored in this browser.';

  @override
  String get aboutLogTitle => 'Log file';

  @override
  String get aboutLogNone => 'No log file on this platform.';

  @override
  String get aboutCopyDiagnostics => 'Copy diagnostics';

  @override
  String get aboutDiagnosticsCopied =>
      'Diagnostics copied. They contain no note text.';

  @override
  String get aboutPrivacy =>
      'BetterNotes keeps notes and a small error log on this device. It collects no usage data and sends nothing without your sign-in and sync settings. Diagnostics hold versions, counts, and settings states only, never note text.';

  @override
  String settingsAboutSubtitle(String version) {
    return 'Version $version · diagnostics and data location';
  }

  @override
  String get reminderTitle => 'Reminder';

  @override
  String reminderShownAt(String time) {
    return 'Shown $time';
  }

  @override
  String reminderSetFor(String time) {
    return 'Set for $time';
  }

  @override
  String get reminderPickDateTime => 'Pick date and time…';

  @override
  String get reminderBestEffort =>
      'Reminders are best effort. BetterNotes must be running, or the scheduled-task option in Settings turned on; a reminder missed while the PC was off is shown the next time the app starts.';

  @override
  String get reminderClear => 'Clear reminder';

  @override
  String get reminderClose => 'Close';

  @override
  String get reminderCleared => 'Reminder cleared.';

  @override
  String reminderSetSnack(String time) {
    return 'Reminder set for $time.';
  }

  @override
  String get reminderChooseFuture => 'Choose a time in the future.';

  @override
  String get reminderSnooze => 'Snooze';

  @override
  String get reminderDone => 'Done';

  @override
  String get reminderPresetTenMinutes => 'In 10 minutes';

  @override
  String get reminderPresetOneHour => 'In 1 hour';

  @override
  String get reminderPresetEvening => 'This evening (6 PM)';

  @override
  String get reminderPresetTomorrow => 'Tomorrow morning (9 AM)';

  @override
  String get reminderPresetMonday => 'Next Monday (9 AM)';

  @override
  String reminderToday(String time) {
    return 'Today $time';
  }

  @override
  String reminderTomorrow(String time) {
    return 'Tomorrow $time';
  }

  @override
  String reminderOn(String date, String time) {
    return '$date $time';
  }

  @override
  String reminderCardLabel(String time) {
    return 'Reminder $time';
  }

  @override
  String reminderCardShown(String time) {
    return 'Reminder shown $time';
  }

  @override
  String windowChromeCouldNotChangeWindowButtons(String error) {
    return 'Could not change window buttons: $error';
  }

  @override
  String get windowChromeBetternotes => 'BetterNotes';

  @override
  String get windowChromeMinimize => 'Minimize';

  @override
  String get windowChromeCloseWindow => 'Close window';

  @override
  String get bulkSetColor => 'Set color';

  @override
  String get bulkCancel => 'Cancel';

  @override
  String get bulkAddTags => 'Add tags';

  @override
  String get bulkAdd => 'Add';

  @override
  String get bulkTags => 'Tags';

  @override
  String get bulkWorkIdeas => 'work, ideas';

  @override
  String get drawingDrawOnNote => 'Draw on note';

  @override
  String get drawingClear => 'Clear';

  @override
  String get findBarFindInThisNoteCtrl => 'Find in this note (Ctrl+H)';

  @override
  String get findBarPreviousMatch => 'Previous match';

  @override
  String get findBarNextMatch => 'Next match';

  @override
  String get findBarCloseFind => 'Close find';

  @override
  String get noteShowAllNotes => 'Show all notes';

  @override
  String get noteCreateANote => 'Create a note';

  @override
  String get notePermanentlyDeleteThisNote => 'Permanently delete this note?';

  @override
  String get noteThisCannotBeUndoneA =>
      'This cannot be undone. A previously exported backup will keep its copy.';

  @override
  String get noteDeletePermanently => 'Delete permanently';

  @override
  String get noteRestore => 'Restore';

  @override
  String get noteNoteRestoredFromArchive => 'Note restored from Archive';

  @override
  String noteCouldNotRestore(String error) {
    return 'Could not restore: $error';
  }

  @override
  String get noteRestoreFromArchive => 'Restore from Archive';

  @override
  String noteCouldNotUpdateNote(String error) {
    return 'Could not update note: $error';
  }

  @override
  String get noteDeleteThisNote => 'Delete this note?';

  @override
  String get noteMoveThisNoteToTrash =>
      'Move this note to Trash? You can restore it later.';

  @override
  String get noteDelete => 'Delete';

  @override
  String noteCouldNotMoveToTrash(String error) {
    return 'Could not move to Trash: $error';
  }

  @override
  String get noteDuplicateNote => 'Duplicate note';

  @override
  String get noteArchiveNote => 'Archive note';

  @override
  String get noteDeleteNote => 'Delete note';

  @override
  String get noteImageUnavailable => 'Image unavailable';

  @override
  String get noteRetryLoadingOrRestoreA =>
      'Retry loading or restore a copy from a complete backup.';

  @override
  String get noteRetryImage => 'Retry image';

  @override
  String noteUpdatedNote(
    String displayTitle,
    String updatedAt,
    String noteColorNames,
  ) {
    return '$displayTitle. Updated $updatedAt. $noteColorNames note.';
  }

  @override
  String get noteFavorite => 'Favorite';

  @override
  String noteUpdatedNote2(
    String displayTitle,
    String preview,
    String updatedAt,
    String noteColorNames,
  ) {
    return '$displayTitle. $preview. Updated $updatedAt. $noteColorNames note.';
  }

  @override
  String get noteNoteOptions => 'Note options';

  @override
  String get noteLoadingImage => 'Loading image';

  @override
  String get noteAttachedNoteImage => 'Attached note image';

  @override
  String get noteDesktopHeaderNewNote => 'New note';

  @override
  String get noteDesktopHeaderChangeColor => 'Change color';

  @override
  String get noteDesktopHeaderMoreActions => 'More actions';

  @override
  String get noteDesktopHeaderCloseNote => 'Close note';

  @override
  String get noteDetailsTitleAndTags => 'Title and tags';

  @override
  String get noteDetailsSave => 'Save';

  @override
  String get noteDetailsTitleOptional => 'Title (optional)';

  @override
  String get noteDetailsUsesTheFirstTextLine =>
      'Uses the first text line when blank';

  @override
  String get noteDetailsWorkIdeasPersonal => 'work, ideas, personal';

  @override
  String get noteImageEmbedRemoveImage => 'Remove image';

  @override
  String get noteVersionHistory => 'Version history';

  @override
  String get noteExportAsMarkdown => 'Export as Markdown';

  @override
  String get noteExportAsPdfToPrint => 'Export as PDF (to print)';

  @override
  String get noteFindInNoteCtrlH => 'Find in note (Ctrl+H)';

  @override
  String get noteKeyboardShortcutsF => 'Keyboard shortcuts (F1)';

  @override
  String get noteMovedToTrash => 'Moved to Trash';

  @override
  String get noteNoteColor => 'Note color';

  @override
  String get noteShareText => 'Share text';

  @override
  String get noteSaveFailedKeepEditingOr =>
      'Save failed. Keep editing or retry.';

  @override
  String get noteRetry => 'Retry';

  @override
  String get noteCut => 'Cut';

  @override
  String get noteCopy => 'Copy';

  @override
  String get notePaste => 'Paste';

  @override
  String get noteSelectAll => 'Select all';

  @override
  String get noteHighlightColor => 'Highlight color';

  @override
  String get noteUndo => 'Undo';

  @override
  String get noteTextStyleOptions => 'Text style options';

  @override
  String get noteAddImage => 'Add image';

  @override
  String get notePasteImageFromClipboard => 'Paste image from clipboard';

  @override
  String get noteTakePhoto => 'Take photo';

  @override
  String get noteDraw => 'Draw';

  @override
  String get notesHomeSaveThisSearch => 'Save this search';

  @override
  String notesHomeCouldNotSaveSearch(String error) {
    return 'Could not save search: $error';
  }

  @override
  String get notesHomeSaveSearch => 'Save search';

  @override
  String notesHomeCouldNotSaveFilters(String error) {
    return 'Could not save filters: $error';
  }

  @override
  String get notesHomeMatchAllSelectedTags => 'Match all selected tags';

  @override
  String get notesHomeManageTags => 'Manage tags';

  @override
  String get notesHomeClearTags => 'Clear tags';

  @override
  String get notesHomeApply => 'Apply';

  @override
  String notesHomeNoteS(String done, String count) {
    return '$done: $count note(s).';
  }

  @override
  String notesHomeCouldNotUpdateNotes(String error) {
    return 'Could not update notes: $error';
  }

  @override
  String notesHomeMoveNoteSToTrash(String ids) {
    return 'Move $ids note(s) to Trash?';
  }

  @override
  String get notesHomeYouCanRestoreThemFrom =>
      'You can restore them from Trash later.';

  @override
  String get notesHomeMoveToTrash => 'Move to Trash';

  @override
  String notesHomeSelected(String _selected) {
    return '$_selected selected';
  }

  @override
  String get notesHomeSelectAllShown => 'Select all shown';

  @override
  String get notesHomeRemoveFavorite => 'Remove favorite';

  @override
  String notesHomeCouldNotCreateNote(String error) {
    return 'Could not create note: $error';
  }

  @override
  String notesHomeCouldNotOpenNote(String error) {
    return 'Could not open note: $error';
  }

  @override
  String get notesHomeRecentlyEdited => 'Recently edited';

  @override
  String get notesHomeNewestCreated => 'Newest created';

  @override
  String get notesHomeTitleAZ => 'Title A–Z';

  @override
  String get notesHomeResetFilters => 'Reset filters';

  @override
  String get notesHomeSettings => 'Settings';

  @override
  String get notesHomeSearchAllActiveNotesIncluding =>
      'Search all active notes, including Archive';

  @override
  String get notesHomeName => 'Name';

  @override
  String get notesHomeKeepsTheSearchTextView =>
      'Keeps the search text, view, sort, and tags. Same name replaces.';

  @override
  String get notesHomeClearSelection => 'Clear selection';

  @override
  String get notesHomeFavoriteSelected => 'Favorite selected';

  @override
  String get notesHomeArchiveSelected => 'Archive selected';

  @override
  String get notesHomeMoveSelectedToTrash => 'Move selected to Trash';

  @override
  String get notesHomeMoreSelectionActions => 'More selection actions';

  @override
  String get notesHomeSelected2 => 'Selected';

  @override
  String get notesHomeNewNoteFromTemplate => 'New note from template';

  @override
  String get notesHomeSearchTitlesAndTextIn =>
      'Search titles and text in this view';

  @override
  String get notesHomeClearSearch => 'Clear search';

  @override
  String reminderCouldNotSetTheReminder(String error) {
    return 'Could not set the reminder: $error';
  }

  @override
  String reminderCouldNotUpdateTheReminder(String error) {
    return 'Could not update the reminder: $error';
  }

  @override
  String get settingsAutomaticBackups => 'Automatic backups';

  @override
  String get settingsTurnOff => 'Turn off';

  @override
  String get settingsKeepTheNewestBackups => 'Keep the newest backups';

  @override
  String get settingsBackUpNow => 'Back up now';

  @override
  String settingsFileOperationFailed(String error) {
    return 'File operation failed: $error';
  }

  @override
  String get settingsImportBackupAsCopies => 'Import backup as copies?';

  @override
  String settingsNotesInTrashImagesExisting(
    String notes,
    String trashCount,
    String assets,
  ) {
    return '$notes notes ($trashCount in Trash), $assets images.\n\nExisting notes are kept. Importing the same backup again creates more copies.';
  }

  @override
  String get settingsRestoreAppearanceAndEditorPreferences =>
      'Restore appearance and editor preferences';

  @override
  String get settingsImportCopies => 'Import copies';

  @override
  String settingsCouldNotReadWindowsStartup(String error) {
    return 'Could not read Windows startup setting: $error';
  }

  @override
  String settingsCouldNotChangeWindowsStartup(String error) {
    return 'Could not change Windows startup: $error';
  }

  @override
  String settingsSignInFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String get settingsContinueWithGoogle => 'Continue with Google';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSyncNeedsAttention => 'Sync needs attention';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsSystem => 'System';

  @override
  String get settingsLight => 'Light';

  @override
  String get settingsDark => 'Dark';

  @override
  String get settingsConfirmBeforeDeleting => 'Confirm before deleting';

  @override
  String get settingsEmptyTrashAutomatically => 'Empty Trash automatically';

  @override
  String get settingsPermanentlyDeletesLocalNotesAfter =>
      'Permanently deletes local notes after this long in Trash. Signed-in account notes keep their sync records and are not removed.';

  @override
  String get settingsNever => 'Never';

  @override
  String get settingsAfterDays => 'After 7 days';

  @override
  String get settingsAfterDays2 => 'After 30 days';

  @override
  String get settingsAfterDays3 => 'After 90 days';

  @override
  String get settingsImagePlacement => 'Image placement';

  @override
  String get settingsAppliesToNewImagesExisting =>
      'Applies to new images. Existing images stay in place.';

  @override
  String get settingsAboveTextCurrent => 'Above text (current)';

  @override
  String get settingsWithinNote => 'Within note';

  @override
  String settingsCouldNotSaveImagePlacement(String error) {
    return 'Could not save image placement: $error';
  }

  @override
  String get settingsAlwaysShowNoteHeader => 'Always show note header';

  @override
  String get settingsKeepNoteActionsVisibleWithout =>
      'Keep note actions visible without hovering.';

  @override
  String settingsCouldNotSaveHeaderPreference(String error) {
    return 'Could not save header preference: $error';
  }

  @override
  String get settingsRemindMeWhenBetternotesIs =>
      'Remind me when BetterNotes is closed';

  @override
  String settingsCouldNotUpdateTheScheduled(String error) {
    return 'Could not update the scheduled task: $error';
  }

  @override
  String get settingsKeepRunningInTheSystem =>
      'Keep running in the system tray';

  @override
  String get settingsClosingTheNotesWindowHides =>
      'Closing the notes window hides it; use the tray icon to open notes, start a note, or Quit.';

  @override
  String settingsCouldNotChangeTrayMode(String error) {
    return 'Could not change tray mode: $error';
  }

  @override
  String get settingsQuickNoteShortcut => 'Quick note shortcut';

  @override
  String get settingsFastNoteOpening => 'Fast note opening';

  @override
  String get settingsKeepOneIdleNoteWindow =>
      'Keep one idle note window ready. Uses some memory; turn off to open notes a little slower.';

  @override
  String settingsCouldNotSaveThisPreference(String error) {
    return 'Could not save this preference: $error';
  }

  @override
  String get settingsWindowButtons => 'Window buttons';

  @override
  String get settingsAppliesToAllBetternotesWindows =>
      'Applies to all BetterNotes windows.';

  @override
  String settingsCouldNotSaveWindowButtons(String error) {
    return 'Could not save window buttons: $error';
  }

  @override
  String get settingsWindows => 'Windows';

  @override
  String get settingsStartWithWindows => 'Start with Windows';

  @override
  String get settingsOpenBetternotesWhenYouSign =>
      'Open BetterNotes when you sign in to Windows.';

  @override
  String get settingsBackupAndRestore => 'Backup and restore';

  @override
  String get settingsCompleteBackupsIncludeTrashFormatting =>
      'Complete backups include Trash, formatting, images, and drawings. Exported files are readable and unencrypted.';

  @override
  String get settingsExportCompleteBackup => 'Export complete backup';

  @override
  String get settingsImportBackup => 'Import backup';

  @override
  String get settingsReviewAndAddCopiesWithout =>
      'Review and add copies without replacing existing notes.';

  @override
  String get settingsImportIsNotAvailableOn =>
      'Import is not available on this platform.';

  @override
  String get settingsExportActiveNotesAsText => 'Export active notes as text';

  @override
  String get settingsTextOnlyUseAComplete =>
      'Text only; use a complete backup for restoration.';

  @override
  String get settingsKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get settingsEditingSearchAndWindowControls =>
      'Editing, search, and window controls.';

  @override
  String get shortcutsHelpLibraryAndNoteWindows => 'Library and note windows';

  @override
  String get shortcutsHelpCtrlNNewNoteCtrl =>
      'Ctrl+N — New note\nCtrl+F — Search library\nF1 — Shortcut help';

  @override
  String get shortcutsHelpInANote => 'In a note';

  @override
  String get shortcutsHelpCtrlWSaveAndClose =>
      'Ctrl+W — Save and close\nCtrl+D — Move to Trash\nCtrl+H — Find in this note\nEnter / Shift+Enter — Next / previous match\nEscape — Close find\nCtrl+Shift+V — Paste as plain text\nPaste a web address over selected text — Make a link';

  @override
  String get shortcutsHelpWhileEditingText => 'While editing text';

  @override
  String get shortcutsHelpCtrlBIUT =>
      'Ctrl+B / I / U / T — Bold / italic / underline / strikethrough\nCtrl+Shift+L — Bulleted list\nCtrl+Z — Undo\nCtrl+Y — Redo\nCtrl+C / X / V / A — Copy / cut / paste / select all';

  @override
  String get shortcutsHelpSelectTextThenOpenText =>
      'Select text, then open Text style options beside Add image for font size, text color, highlighting, headings, numbered lists, quotes, inline code, and clear formatting. With no selection, styles apply to what you type next.';

  @override
  String get shortcutsHelpUseTabAndShiftTab =>
      'Use Tab and Shift+Tab to move between controls, and Enter or Space to activate them. Checklists, title, tags, favorites, and Archive are available from the toolbar or note menus. Closing keeps the note; deleting moves it to Trash.';

  @override
  String get startupErrorBetternotesCouldnTOpenYour =>
      'BetterNotes couldn\'t open your notes';

  @override
  String get startupErrorNothingWasChangedOrDeleted =>
      'Nothing was changed or deleted. Try again first; if the problem continues, start with an empty library and restore from a backup.';

  @override
  String get startupErrorTryAgain => 'Try again';

  @override
  String get startupErrorCopyDetails => 'Copy details';

  @override
  String get startupErrorStartEmptyKeepACopy => 'Start empty (keep a copy)';

  @override
  String get startupErrorStartWithAnEmptyLibrary =>
      'Start with an empty library?';

  @override
  String get startupErrorTheUnreadableLibraryFileIs =>
      'The unreadable library file is renamed, not deleted, so it can still be recovered. Notes in your account sync back if you sign in; otherwise restore a backup from Settings.';

  @override
  String get startupErrorStartEmpty => 'Start empty';

  @override
  String get tagManagerNoTagsYetAddTags =>
      'No tags yet. Add tags from a note’s menu.';

  @override
  String tagManagerCouldNotChangeTag(String error) {
    return 'Could not change tag: $error';
  }

  @override
  String tagManagerRename(String tag) {
    return 'Rename “$tag”';
  }

  @override
  String get tagManagerRename2 => 'Rename';

  @override
  String tagManagerDeleteTag(String tag) {
    return 'Delete tag “$tag”?';
  }

  @override
  String get tagManagerTheTagIsRemovedFrom =>
      'The tag is removed from every note. Notes stay.';

  @override
  String get tagManagerDeleteTag2 => 'Delete tag';

  @override
  String tagManagerRenameOrMerge(String tag) {
    return 'Rename or merge $tag';
  }

  @override
  String tagManagerDeleteTag3(String tag) {
    return 'Delete tag $tag';
  }

  @override
  String get tagManagerUsingAnExistingTagName =>
      'Using an existing tag name merges the two.';

  @override
  String get textColorResetColor => 'Reset color';

  @override
  String get textColorHexColor => 'Hex color';

  @override
  String get textStylePanelSelectTextToStyleIt =>
      'Select text to style it, or choose a style before typing.';

  @override
  String get textStylePanelTextColor => 'Text color';

  @override
  String versionHistoryCouldNotLoadVersions(String error) {
    return 'Could not load versions: $error';
  }

  @override
  String versionHistoryNoEarlierVersionsYetBetternotes(
    String maxRevisionsPerNote,
  ) {
    return 'No earlier versions yet. BetterNotes saves one while you edit, at most every 5 minutes, and keeps the latest $maxRevisionsPerNote.';
  }

  @override
  String versionHistoryWords(String createdAt, String words) {
    return '$createdAt · $words words';
  }

  @override
  String get versionHistoryRestoreAsACopy => 'Restore as a copy';

  @override
  String bulkExportedNoteSAsMarkdown(String fresh) {
    return 'Exported $fresh note(s) as Markdown.';
  }

  @override
  String get noteImageUnavailableOpenTheNote =>
      'Image unavailable. Open the note to retry or restore from a backup.';

  @override
  String get noteNoMatchingNotes => 'No matching notes';

  @override
  String get noteAFreshSpaceForYour => 'A fresh space for your ideas';

  @override
  String get noteTryAnotherWordOrClear =>
      'Try another word or clear the search.';

  @override
  String get noteChooseAnotherViewOrReset =>
      'Choose another view or reset filters to see your notes.';

  @override
  String get noteKeepAThoughtCloseStart =>
      'Keep a thought close. Start with a note.';

  @override
  String get noteNotePermanentlyDeleted => 'Note permanently deleted';

  @override
  String get noteNoteRestoredToNotes => 'Note restored to Notes';

  @override
  String get noteInTrash => 'In Trash';

  @override
  String noteDeleted(String deletedAt) {
    return 'Deleted $deletedAt';
  }

  @override
  String get noteAccountTrashRetainsSyncRecords =>
      'Account Trash retains sync records';

  @override
  String get noteTodayAm => 'Today 9:00 AM';

  @override
  String get noteDesktopHeaderTurnOffAlwaysOnTop => 'Turn off always on top';

  @override
  String get noteDesktopHeaderAlwaysOnTop => 'Always on top';

  @override
  String get noteWriteANote => 'Write a note...';

  @override
  String get noteSetReminder => 'Set reminder…';

  @override
  String get noteEditReminder => 'Edit reminder…';

  @override
  String get noteSaveFailed => 'Save failed';

  @override
  String get noteSaving => 'Saving…';

  @override
  String get noteSavedLocally => 'Saved locally';

  @override
  String get noteSavingLocally => 'Saving locally';

  @override
  String noteCouldNotReadAlwaysOn(String error) {
    return 'Could not read always on top: $error';
  }

  @override
  String noteCouldNotChangeAlwaysOn(String error) {
    return 'Could not change always on top: $error';
  }

  @override
  String noteCouldNotSaveDetails(String error) {
    return 'Could not save details: $error';
  }

  @override
  String noteExported(String name) {
    return 'Exported \"$name\".';
  }

  @override
  String noteCouldNotExport(String error) {
    return 'Could not export: $error';
  }

  @override
  String noteDuplicatedAs(String displayTitle) {
    return 'Duplicated as \"$displayTitle\".';
  }

  @override
  String noteCouldNotDuplicateNote(String error) {
    return 'Could not duplicate note: $error';
  }

  @override
  String get noteSaveFailedRetryBeforeReturning =>
      'Save failed. Retry before returning to your notes.';

  @override
  String get noteSaveFailedRetrySavingBefore =>
      'Save failed. Retry saving before closing, or keep editing.';

  @override
  String noteCouldNotAddImage(String error) {
    return 'Could not add image: $error';
  }

  @override
  String get noteNoImageOnTheClipboard => 'No image on the clipboard.';

  @override
  String noteCouldNotPasteImage(String error) {
    return 'Could not paste image: $error';
  }

  @override
  String noteCouldNotCompleteThatAction(String error) {
    return 'Could not complete that action: $error';
  }

  @override
  String noteCouldNotChangeTextColor(String error) {
    return 'Could not change text color: $error';
  }

  @override
  String notesHomeDeleteSavedSearch(String name) {
    return 'Delete saved search $name';
  }

  @override
  String get notesHomeSyncNotes => 'Sync notes';

  @override
  String get notesHomeLocalNotes => 'Local notes';

  @override
  String get notesHomeAllActive => 'All active';

  @override
  String get notesHomeCardView => 'Card view';

  @override
  String get notesHomeCompactListView => 'Compact list view';

  @override
  String get notesHomeFilterByTags => 'Filter by tags';

  @override
  String notesHomeTags(String tags) {
    return 'Tags: $tags';
  }

  @override
  String get notesHomeTrashIsEmpty => 'Trash is empty';

  @override
  String get notesHomeNoMatchingNotesInTrash => 'No matching notes in Trash';

  @override
  String get notesHomeNoNotesMatchThisView =>
      'No notes match this view and filters';

  @override
  String get settingsBackingUpNow => 'Backing up now...';

  @override
  String get settingsNoAutomaticBackupHasRun =>
      'No automatic backup has run yet.';

  @override
  String settingsLastBackup(String substring) {
    return 'Last backup: $substring';
  }

  @override
  String get settingsOffChooseAFolderTo =>
      'Off. Choose a folder to save a complete backup about once a day.';

  @override
  String get settingsChooseFolder => 'Choose folder';

  @override
  String get settingsBackupExportedKeepThisReadable =>
      'Backup exported. Keep this readable file in a safe place.';

  @override
  String get settingsTextExportedUseAComplete =>
      'Text exported. Use a complete backup to restore images and formatting.';

  @override
  String get settingsYourNotesCanSyncAcross =>
      'Your notes can sync across devices.';

  @override
  String get settingsSignInWithGoogleTo =>
      'Sign in with Google to sync your notes.';

  @override
  String get settingsGoogleSyncNeedsASupabase =>
      'Google sync needs a Supabase project connection.';

  @override
  String get settingsAddsAWindowsScheduledTask =>
      'Adds a Windows scheduled task (BetterNotes Reminders, this user only) that opens BetterNotes when a reminder is due or at sign-in. Best effort: a reminder missed while the PC was off is shown the next time the app starts. Turn off to remove the task.';

  @override
  String get settingsAGlobalShortcutThatOpens =>
      'A global shortcut that opens a new note from any app while BetterNotes is running.';

  @override
  String get settingsAnotherAppAlreadyUsesThat =>
      'Another app already uses that shortcut. Choose a different one.';

  @override
  String settingsCouldNotSetTheShortcut(String error) {
    return 'Could not set the shortcut: $error';
  }

  @override
  String get settingsCheckingWindowsStartupSetting =>
      'Checking Windows startup setting';

  @override
  String get settingsCouldNotReadWindowsStartup2 =>
      'Could not read Windows startup setting';

  @override
  String get textColorEnterSixHexDigitsSuch =>
      'Enter six hex digits, such as #795082.';

  @override
  String get versionHistoryThatVersionIsNoLonger =>
      'That version is no longer available.';

  @override
  String versionHistoryRestoredAsANewNote(String displayTitle) {
    return 'Restored as a new note: $displayTitle';
  }

  @override
  String get viewNotes => 'Notes';

  @override
  String get viewFavorites => 'Favorites';

  @override
  String get viewReminders => 'Reminders';

  @override
  String get viewArchive => 'Archive';

  @override
  String get viewTrash => 'Trash';

  @override
  String get bulkDoneMovedToTrash => 'Moved to Trash';

  @override
  String get bulkDoneRemovedFavorite => 'Removed favorite';

  @override
  String get bulkDoneColorChanged => 'Color changed';

  @override
  String get bulkDoneTagsAdded => 'Tags added';

  @override
  String get bulkDoneExported => 'Exported';

  @override
  String get bulkDoneFavorited => 'Favorited';

  @override
  String get bulkDoneArchived => 'Archived';

  @override
  String get imageQualityTitle => 'Picture storage';

  @override
  String get imageQualityHelp =>
      'Pictures are compressed once, when you add them, to save space on this device, in backups, and online. The original is not kept.';

  @override
  String get imageQualityBalanced => 'Balanced (recommended)';

  @override
  String get imageQualitySmallest => 'Smallest files';

  @override
  String get imageQualityOriginal => 'Original (only shrink huge pictures)';

  @override
  String get shrinkTitle => 'Shrink saved pictures';

  @override
  String get shrinkSubtitle =>
      'Re-compress the pictures already in your notes with the setting above. They are replaced by smaller copies and this cannot be undone.';

  @override
  String get shrinkSignedIn =>
      'Not available while signed in: pictures that were already uploaded would not be updated. Do this before connecting an account.';

  @override
  String shrinkWorking(String done, String total) {
    return 'Checking pictures… $done of $total';
  }

  @override
  String get shrinkNothing =>
      'Your pictures are already as small as they can reasonably be.';

  @override
  String shrinkFound(
    String count,
    String total,
    String before,
    String after,
    String saved,
  ) {
    return '$count of $total pictures can shrink from $before to $after, saving $saved. Export a backup first if you want to keep the originals.';
  }

  @override
  String get shrinkApply => 'Shrink pictures';

  @override
  String get shrinkCancel => 'Cancel';

  @override
  String shrinkDone(String saved) {
    return 'Pictures shrunk. Saved $saved.';
  }

  @override
  String shrinkFailed(String error) {
    return 'Could not shrink pictures: $error';
  }

  @override
  String get stickyTitle => 'Import from Windows Sticky Notes';

  @override
  String get stickySubtitle =>
      'Copy your existing Sticky Notes into BetterNotes once. Sticky Notes itself is not changed.';

  @override
  String stickyFound(String count, String pictures, String already) {
    return 'Found $count notes with $pictures pictures in Windows Sticky Notes ($already already imported). Import them as new notes tagged \"sticky notes\"? Sticky Notes is not changed.';
  }

  @override
  String get stickyNoneNew => 'There are no new Sticky Notes to import.';

  @override
  String get stickyImport => 'Import';

  @override
  String get stickyCancel => 'Cancel';

  @override
  String stickyWorking(String done, String total) {
    return 'Importing… $done of $total';
  }

  @override
  String stickyDone(String count, String pictures) {
    return 'Imported $count notes and $pictures pictures.';
  }

  @override
  String stickyDoneSkipped(String count, String pictures, String skipped) {
    return 'Imported $count notes and $pictures pictures. $skipped items could not be imported or were empty.';
  }

  @override
  String stickyFailed(String error) {
    return 'Could not import Sticky Notes: $error';
  }

  @override
  String get sortUpdatedOldest => 'Least recently edited';

  @override
  String get sortCreatedOldest => 'Oldest created';

  @override
  String get sortTitleDesc => 'Title Z–A';

  @override
  String get sortReminder => 'Reminder date';

  @override
  String get sortColor => 'Color';

  @override
  String get sortLength => 'Longest first';

  @override
  String get sortFavoritesFirst => 'Favorites first';

  @override
  String cardCreated(String time) {
    return 'Created $time';
  }
}
