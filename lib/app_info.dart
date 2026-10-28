/// Must match `version:` in pubspec.yaml (a test checks this).
const appVersion = '1.1.1';
const appBuild = '8';
const appName = 'BetterNotes';
String get appVersionLabel => '$appVersion+$appBuild';
