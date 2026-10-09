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
}
