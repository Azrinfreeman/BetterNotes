/// Must match `version:` in pubspec.yaml (a test checks this).
const appVersion = '1.1.0';
const appBuild = '7';
const appName = 'BetterNotes';
String get appVersionLabel => '$appVersion+$appBuild';
