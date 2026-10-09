/// Must match `version:` in pubspec.yaml (a test checks this).
const appVersion = '1.0.2';
const appBuild = '3';
const appName = 'BetterNotes';
String get appVersionLabel => '$appVersion+$appBuild';
