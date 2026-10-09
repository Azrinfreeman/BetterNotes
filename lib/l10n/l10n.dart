import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Localized strings for [context]; falls back to English when the app has no
/// localizations above it (for example in a bare widget test).
extension AppL10n on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}

/// Strings for the current `Intl` locale, for code that has no [BuildContext]
/// (date labels). Unsupported languages fall back to English.
AppLocalizations currentL10n() {
  try {
    final language = Intl.getCurrentLocale().split(RegExp('[_-]')).first;
    return lookupAppLocalizations(Locale(language));
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}
