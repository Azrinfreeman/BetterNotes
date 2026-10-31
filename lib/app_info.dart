/// Must match `version:` in pubspec.yaml (a test checks this).
const appVersion = '1.1.3';
const appBuild = '10';
const appName = 'BetterNotes';
String get appVersionLabel => '$appVersion+$appBuild';
